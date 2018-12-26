SUBDIRS := $(shell arch)/*
PAREN := \)
.EXPORT_ALL_VARIABLES:

all: $(SUBDIRS)
$(SUBDIRS): target/stepmania
	echo "BUILDING srcdir [$@]"
	rm -rf target/$@
	mkdir -p target/$@
	rsync --update --recursive $@/* target/$@
	mkdir -p target/$@/debian/opt/$(@F)
	rsync --update --recursive /usr/local/$(@F)/* target/$@/debian/opt/$(@F)/.
	$(MAKE) $(@F) FULLPATH=$@ SMPATH=$(@F)
.PHONY: all $(SUBDIRS)

ifdef SMPATH
STEPMANIA_VERSION_NUM:=$(shell /usr/local/$(SMPATH)/stepmania --version 2>/dev/null | head -n 1 | awk  '{gsub("StepMania","", $$1); print $$1}')
STEPMANIA_HASH:=$(shell /usr/local/$(SMPATH)/stepmania --version 2>/dev/null | head -n 2 | tail -n 1 | awk '{gsub("$(PAREN)","",$$NF); print $$NF}')
STEPMANIA_DATE:=$(shell cd target/stepmania && git show -s --format=%cd --date=short $(STEPMANIA_HASH))

PACKAGER_NAME:=$(shell id -nu)
PACKAGER_EMAIL:=$(shell git config --global user.email)
PACKAGER_EMAIL ?= nobody@example.com
PACKAGE_DATE:=$(shell date +"%a, %d %b %Y %H:%M:%S %z")

ifeq ($(RELEASE),true)
STEPMANIA_VERSION=$(STEPMANIA_VERSION_NUM)
STEPMANIA_DISTRIBUTION=stable
else
STEPMANIA_VERSION=$(STEPMANIA_VERSION_NUM)-$(STEPMANIA_DATE)
STEPMANIA_DISTRIBUTION=UNRELEASED
endif
endif

stepmania-%: \
	target/$(FULLPATH)/debian/DEBIAN/control \
	target/$(FULLPATH)/usr/share/doc/stepmania/changelog.Debian.gz \
	target/$(FULLPATH)/debian/opt/$(SMPATH)/GtkModule.so \
	target/$(FULLPATH)/debian/opt/$(SMPATH)/stepmania
	echo "BUILDING detected target [$@]; fullpath = [$(FULLPATH)]; prereqs = [$^]"
	cd target/$(FULLPATH) && fakeroot dpkg-deb --build debian
	mv target/$(FULLPATH)/debian.deb target/stepmania-$(STEPMANIA_VERSION)-$(shell arch).deb
	lintian target/stepmania-$(STEPMANIA_VERSION)-$(shell arch).deb

# debian control files gets envvars substituted
.PHONY: target/$(FULLPATH)/debian/DEBIAN/*
target/$(FULLPATH)/debian/DEBIAN/*:
	echo "sm version: $(STEPMANIA_VERSION) / hash: $(STEPMANIA_HASH) / date: $(STEPMANIA_DATE)"
	cat $(FULLPATH)/debian/DEBIAN/$(@F) | envsubst > $@

# changelog gets a copy compressed
target/$(FULLPATH)/usr/share/doc/stepmania/changelog.Debian.gz:
	gzip --keep --no-name --to-stdout -9 $(FULLPATH)/debian/changelog > $@

# binaries in need of stripping
.PHONY: target/$(FULLPATH)/debian/opt/$(SMPATH)/stepmania
target/$(FULLPATH)/debian/opt/$(SMPATH)/stepmania:
	echo "Stripping [$@]"
	strip --strip-unneeded -o $@ /usr/local/$(SMPATH)/$(@F)

# GtkModule needs stripping and non-execute
.PHONY: target/$(FULLPATH)/debian/opt/$(SMPATH)/GtkModule.so
target/$(FULLPATH)/debian/opt/$(SMPATH)/GtkModule.so:
	echo "Stripping [$@]"
	strip --strip-unneeded -o $@ /usr/local/$(SMPATH)/$(@F)
	chmod a-x $@

# clone the stepmania repository so we can get commit information
target/stepmania:
	git clone https://github.com/stepmania/stepmania.git target/stepmania

clean:
	rm -rf target
