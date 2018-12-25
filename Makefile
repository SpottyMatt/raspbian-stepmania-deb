SUBDIRS := $(shell arch)/*
PAREN := \)

all: $(SUBDIRS)
$(SUBDIRS): target/stepmania
	echo "BUILDING srcdir [$@]"
	rm -rf target/$@
	mkdir -p target/$@
	cp -rfv $@/* target/$@
	mkdir -p target/$@/debian/opt/$(@F)
	cp -rfv /usr/local/$(@F)/* target/$@/debian/opt/$(@F)/.
	$(MAKE) $(@F) FULLPATH=$@ SMPATH=$(@F)
.PHONY: all $(SUBDIRS)

stepmania-%: STEPMANIA_VERSION_NUM=$(shell /usr/local/$(SMPATH)/stepmania --version 2>/dev/null | head -n 1 | awk  '{gsub("StepMania","", $$1); print $$1}')
stepmania-%: STEPMANIA_HASH=$(shell /usr/local/$(SMPATH)/stepmania --version 2>/dev/null | head -n 2 | tail -n 1 | awk '{gsub("$(PAREN)","",$$NF); print $$NF}')
stepmania-%: STEPMANIA_DATE=$(shell cd target/stepmania && git show -s --format=%cd --date=short $(STEPMANIA_HASH))
ifeq ($(RELEASE),true)
stepmania-%: STEPMANIA_VERSION=$(STEPMANIA_VERSION_NUM)
else
stepmania-%: STEPMANIA_VERSION=$(STEPMANIA_VERSION_NUM)-$(STEPMANIA_DATE)
endif
stepmania-%: target/$(FULLPATH)/debian/DEBIAN/control
	echo "BUILDING detected target [$@]; fullpath = [$(FULLPATH)]; prereqs = [$^]"
	cd target/$(FULLPATH) && pwd && dpkg-deb --build debian
	mv target/$(FULLPATH)/debian.deb target/stepmania-$(STEPMANIA_VERSION)-$(shell arch).deb
	lintian target/stepmania-$(STEPMANIA_VERSION)-$(shell arch).deb

target/$(FULLPATH)/debian/DEBIAN/control:
	echo "BUILDING ctrlfile [$@]"
	echo "sm version: $(STEPMANIA_VERSION) / hash: $(STEPMANIA_HASH) / date: $(STEPMANIA_DATE)"
	cat $(FULLPATH)/debian/DEBIAN/control | STEPMANIA_VERSION=$(STEPMANIA_VERSION) envsubst > target/$(FULLPATH)/debian/DEBIAN/control

.PHONY: target/$(FULLPATH)/debian/DEBIAN/control

target/stepmania:
	git clone https://github.com/stepmania/stepmania.git target/stepmania

clean:
	rm -rf target
