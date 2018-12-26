'SUBDIRS := $(shell arch)/*
PAREN := \)
.EXPORT_ALL_VARIABLES:

all: $(SUBDIRS)
$(SUBDIRS): target/stepmania
	echo "BUILDING srcdir [$@]"
	rm -rf target/$@
	mkdir -p target/$@
	rsync --update --recursive $@/* target/$@
	mkdir -p target/$@/debian/usr/games/$(@F)
	rsync --update --recursive /usr/local/$(@F)/* target/$@/debian/usr/games/$(@F)/.
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
	target/$(FULLPATH)/debian/usr/share/doc/stepmania/changelog.Debian.gz \
	target/$(FULLPATH)/debian/usr/games/$(SMPATH)/GtkModule.so \
	target/$(FULLPATH)/debian/usr/games/$(SMPATH)/stepmania \
	target/$(FULLPATH)/debian/usr/bin/stepmania
	cd target/$(FULLPATH) && fakeroot dpkg-deb --build debian
	mv target/$(FULLPATH)/debian.deb target/stepmania-$(STEPMANIA_VERSION)-$(shell arch).deb
	lintian target/stepmania-$(STEPMANIA_VERSION)-$(shell arch).deb

# stepmania symlink on the PATH
target/$(FULLPATH)/debian/usr/bin/stepmania:
	mkdir -p $(@D)
	ln -s ../games/$(SMPATH)/stepmania $@

# debian control file gets envvars substituted FRESH EVERY TIME
.PHONY: target/$(FULLPATH)/debian/DEBIAN/*
target/$(FULLPATH)/debian/DEBIAN/*:
	cat $(FULLPATH)/debian/DEBIAN/$(@F) | envsubst > $@

# changelog gets a copy compressed
target/$(FULLPATH)/debian/usr/share/doc/stepmania/changelog.Debian.gz: $(FULLPATH)/debian/usr/share/doc/stepmania/changelog.Debian
	cat $(<) | envsubst > $(basename $@)
	gzip --no-name -9 $(basename $@)

# stepmania needs stripping
.PHONY: target/$(FULLPATH)/debian/usr/games/$(SMPATH)/stepmania
target/$(FULLPATH)/debian/usr/games/$(SMPATH)/stepmania:
	strip --strip-unneeded $@

# GtkModule needs stripping and non-execute
.PHONY: target/$(FULLPATH)/debian/usr/games/$(SMPATH)/GtkModule.so
target/$(FULLPATH)/debian/usr/games/$(SMPATH)/GtkModule.so:
	strip --strip-unneeded $@
	chmod a-x $@

# clone the stepmania repository so we can get commit information
target/stepmania:
	git clone https://github.com/stepmania/stepmania.git target/stepmania

clean:
	rm -rf target
