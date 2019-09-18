DISTRO := $(shell dpkg --status tzdata|grep Provides|cut -f2 -d'-')
ARCH := $(shell dpkg --print-architecture)
RPI_MODEL := $(shell ./rpi-hw-info/rpi-hw-info.py 2>/dev/null | awk -F ':' '{print $$1}' | tr '[:upper:]' '[:lower:]' )

ifeq ($(RPI_MODEL),3B+)
# RPI 3B and 3B+ are the same hardware architecture and targets
# So we don't need to generate separate packages for them.
# Prefer the base model "3B" for labelling when we're on a 3B+
RPI_MODEL=3B
endif

PACKAGE_NAME = stepmania-$(RPI_MODEL)

SUBDIRS := $(ARCH)/*

PAREN := \)

.EXPORT_ALL_VARIABLES:

ifeq ($(wildcard ./rpi-hw-info/rpi-hw-info.py),)
all: submodules
	$(MAKE) all

submodules:
	git submodule init rpi-hw-info
	git submodule update rpi-hw-info
	@ if ! [ -e ./rpi-hw-info/rpi-hw-info.py ]; then echo "Couldn't retrieve the RPi HW Info Detector's git submodule. Figure out why or run 'make RPI_MODEL=<your_model>'"; exit 1; fi

%: submodules
	$(MAKE) $@

else

all: $(SUBDIRS)
$(SUBDIRS): target/stepmania packages
	rm -rf target/$@
	mkdir -p target/$@
	rsync -v --update --recursive $@/* target/$@
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
	target/$(FULLPATH)/usr/share/doc/$(PACKAGE_NAME)/changelog.Debian.gz \
	target/$(FULLPATH)/usr/share/doc/$(PACKAGE_NAME)/copyright \
	target/$(FULLPATH)/usr/share/lintian/overrides/$(PACKAGE_NAME) \
	target/$(FULLPATH)/usr/games/$(SMPATH)/GtkModule.so \
	target/$(FULLPATH)/usr/games/$(SMPATH)/stepmania \
	target/$(FULLPATH)/usr/share/man/man6/stepmania.6.gz \
	target/$(FULLPATH)/usr/bin/stepmania
	cd target && fakeroot dpkg-deb --build $(FULLPATH)
	mv target/$(FULLPATH).deb target/stepmania-$(RPI_MODEL)_$(STEPMANIA_VERSION)_$(DISTRO).deb
	lintian target/stepmania-$(RPI_MODEL)_$(STEPMANIA_VERSION)_$(DISTRO).deb

# stepmania symlink on the PATH
target/$(FULLPATH)/usr/bin/stepmania:
	mkdir -p $(@D)
	ln -s ../games/$(SMPATH)/stepmania $@

# debian control files get envvars substituted FRESH EVERY TIME
.PHONY: target/$(FULLPATH)/DEBIAN/*
target/$(FULLPATH)/DEBIAN/*:
	cat $(FULLPATH)/DEBIAN/$(@F) | envsubst > $@

# lintian overrides file must be substituted and renamed
target/$(FULLPATH)/usr/share/lintian/overrides/$(PACKAGE_NAME): $(FULLPATH)/usr/share/lintian/overrides/stepmania
	cat $(<) | envsubst > $(basename $@)

# changelog must be substituted and compressed
target/$(FULLPATH)/usr/share/doc/$(PACKAGE_NAME)/changelog.Debian.gz: $(FULLPATH)/usr/share/doc/stepmania/changelog.Debian
	mkdir -p $(shell dirname $@)
	cat $(<) | envsubst > $(basename $@)
	gzip --no-name -9 $(basename $@)

# copyright gets renamed
target/$(FULLPATH)/usr/share/doc/$(PACKAGE_NAME)/copyright: $(FULLPATH)/usr/share/doc/stepmania/copyright
	cp $(<) $@

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

.PHONY: validate
validate:
	echo "validate: $(RPI_MODEL)"
	@if [ "x" = "x$(RPI_MODEL)" ]; then \
		echo "ERROR: Unrecognized Raspberry Pi model. Run 'make RPI_MODEL=<model>' if you know which RPi you compiled for."; \
		./rpi-hw-info.py; \
		exit 1; \
	fi

.PHONY: clean
clean:
	rm -rf target

endif
