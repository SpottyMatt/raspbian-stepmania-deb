DISTRO := $(shell dpkg --status tzdata|grep Provides|cut -f2 -d'-')
RPI_MODEL := $(shell ./rpi-hw-info.py | awk -F ':' '{print $$1}')
SUBDIRS := $(RPI_MODEL)/*
PAREN := \)
.EXPORT_ALL_VARIABLES:

all: $(SUBDIRS)
$(SUBDIRS): target/stepmania packages
	rm -rf target/$@
	mkdir -p target/$@
	rsync --update --recursive $@/* target/$@
	mkdir -p target/$@/usr/games/$(@F)
	rsync --update --recursive /usr/local/$(@F)/* target/$@/usr/games/$(@F)/.
	$(MAKE) $(@F) FULLPATH=$@ SMPATH=$(@F)
.PHONY: all $(SUBDIRS)

ifdef SMPATH
STEPMANIA_VERSION_NUM:=$(shell /usr/local/$(SMPATH)/stepmania --version 2>/dev/null | head -n 1 | awk  '{gsub("StepMania","", $$1); print $$1}')
STEPMANIA_HASH:=$(shell /usr/local/$(SMPATH)/stepmania --version 2>/dev/null | head -n 2 | tail -n 1 | awk '{gsub("$(PAREN)","",$$NF); print $$NF}')
STEPMANIA_DATE:=$(shell cd target/stepmania && git show -s --format=%cd --date=short $(STEPMANIA_HASH) | tr -d '-')
STEPMANIA_DEPS:=$(shell ./find-bin-dep-pkg.py --display debian-control /usr/local/$(SMPATH)/stepmania)

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
	target/$(FULLPATH)/DEBIAN/control \
	target/$(FULLPATH)/usr/share/doc/stepmania/changelog.Debian.gz \
	target/$(FULLPATH)/usr/games/$(SMPATH)/GtkModule.so \
	target/$(FULLPATH)/usr/games/$(SMPATH)/stepmania \
	target/$(FULLPATH)/usr/share/man/man6/stepmania.6.gz \
	target/$(FULLPATH)/usr/bin/stepmania
	cd target && fakeroot dpkg-deb --build $(FULLPATH)
	mv target/$(FULLPATH).deb target/stepmania_$(STEPMANIA_VERSION)_$(RPI_MODEL)_$(DISTRO).deb
	lintian target/stepmania_$(STEPMANIA_VERSION)_$(RPI_MODEL)_$(DISTRO).deb

# stepmania symlink on the PATH
target/$(FULLPATH)/usr/bin/stepmania:
	mkdir -p $(@D)
	ln -s ../games/$(SMPATH)/stepmania $@

# debian control files get envvars substituted FRESH EVERY TIME
.PHONY: target/$(FULLPATH)/DEBIAN/*
target/$(FULLPATH)/DEBIAN/*:
	cat $(FULLPATH)/DEBIAN/$(@F) | envsubst > $@

# changelog must be substituted and compressed
target/$(FULLPATH)/usr/share/doc/stepmania/changelog.Debian.gz: $(FULLPATH)/usr/share/doc/stepmania/changelog.Debian
	cat $(<) | envsubst > $(basename $@)
	gzip --no-name -9 $(basename $@)

# manpages must be compressed
target/$(FULLPATH)/usr/share/man/man6/stepmania.6.gz: $(FULLPATH)/usr/share/man/man6/stepmania.6
	gzip --no-name -9 $(basename $@)

# stepmania needs stripping
.PHONY: target/$(FULLPATH)/usr/games/$(SMPATH)/stepmania
target/$(FULLPATH)/usr/games/$(SMPATH)/stepmania:
	strip --strip-unneeded $@

# GtkModule needs stripping and non-execute
.PHONY: target/$(FULLPATH)/usr/games/$(SMPATH)/GtkModule.so
target/$(FULLPATH)/usr/games/$(SMPATH)/GtkModule.so:
	strip --strip-unneeded $@
	chmod a-x $@

# clone the stepmania repository so we can get commit information
target/stepmania:
	git clone https://github.com/stepmania/stepmania.git target/stepmania

# Install deb package linter
.PHONY: packages
packages:
	sudo apt-get install -y \
		binutils \
		lintian

.PHONY: clean
clean:
	rm -rf target
