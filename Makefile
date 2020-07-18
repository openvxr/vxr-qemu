# vim:noexpandtab:tabstop=4:softtabstop=4:shiftwidth=4
# @author <a href="mailto:openvxr@cisco.com">Open VXR</a>
#

RELEASE_DIR=$(PWD)/ovxr-qemu-release
QEMU_VERSION=4.2.0
LOCAL_CACHE=/tmp

GCC_ROOT=/usr
CXX=$(GCC_ROOT)/bin/g++
CCC=$(GCC_ROOT)/bin/gcc
LDFLAGS=-Wl,-rpath,$(GCC_ROOT)/lib64

TARGETS=\
	rapidjson\
	qemu 

RAPID_JSON_INC="$(PWD)/rapidjson/include/rapidjson/"

CLEAN_TARGETS=$(TARGETS:=-clean)

SO_EXT=so

CONFIG_QEMU=./configure \
	--prefix="$(RELEASE_DIR)" \
	--target-list="x86_64-softmmu" \
	--cc=$(CCC) \
	--cxx=$(CXX) \
	--enable-debug \
	--disable-vde \
	--enable-kvm \
	--disable-guest-agent \
	--disable-xen \
	--disable-pie \
	--disable-sdl \
	--disable-gtk \
	--disable-opengl \
	--disable-virtfs \
	--disable-rdma \
	--disable-libusb \
	--disable-usb-redir \
	--disable-snappy \
	--disable-vnc-sasl \
	--disable-libssh \
	--extra-cflags="-g -pthread -fPIC -O2 -DCISCO_VXR=1 -DVXR_X86=1 -I$(RAPID_JSON_INC)" \
	--extra-ldflags="-Wl,-export-dynamic -ldl"

all: $(TARGETS)

rapidjson:
	( if [ -f $(LOCAL_CACHE)/$@.tgz ] ; then \
		tar xfz $(LOCAL_CACHE)/$@.tgz ; else \
			git clone https://github.com/miloyip/rapidjson ; \
	fi )

rapidjson-clean:
		rm -rf rapidjson

qemu: qemu-$(QEMU_VERSION)/config-host.mak
	( cd qemu-$(QEMU_VERSION) ;  $(MAKE) -j12 install)

qemu-$(QEMU_VERSION)/config-host.mak: qemu-$(QEMU_VERSION)/VXR_PATCHED
	( cd qemu-$(QEMU_VERSION) ; $(CONFIG_QEMU) )

qemu-$(QEMU_VERSION)/VXR_PATCHED: | qemu-$(QEMU_VERSION)
	@for i in $$(cat qemu-$(QEMU_VERSION)-patches/LISTNEW) ; do \
		echo "Adding: $$i" ; \
		touch qemu-$(QEMU_VERSION)/$$i ; \
		touch qemu-$(QEMU_VERSION)/$$i.orig ; \
	done
	@for i in $$(cat qemu-$(QEMU_VERSION)-patches/LISTPATCH) ; do \
		echo "patch files: $$i" ; \
		if [ ! -f qemu-$(QEMU_VERSION)/$${i}.orig ] ; then \
		    echo "copying files: $$i $${i}.orig" ; \
			cp qemu-$(QEMU_VERSION)/$$i qemu-$(QEMU_VERSION)/$${i}.orig ; \
		fi ; \
    done
	echo "Applying qemu patch"
	$(MAKE) qemu-patch
	touch qemu-$(QEMU_VERSION)/VXR_PATCHED

qemu-$(QEMU_VERSION): qemu-$(QEMU_VERSION).tar.xz
		tar xfJ $<

qemu-$(QEMU_VERSION).tar.xz:
	( if [ -f $(LOCAL_CACHE)/$@ ] ; then cp $(LOCAL_CACHE)/$@ . ; else \
		wget https://download.qemu.org/$@ ; cp $@ $(LOCAL_CACHE); \
	fi )


qemu-clean:
	rm -rf qemu-$(QEMU_VERSION) qemu-$(QEMU_VERSION).tar.xz
	rm -rf $(RELEASE_DIR)

QEMU_PATCHFILE=qemu-$(QEMU_VERSION)-patches/PATCH_FILE
qemu-genpatch:
	@echo "" > $(QEMU_PATCHFILE)
	@for i in $$(cat qemu-$(QEMU_VERSION)-patches/LISTPATCH) ; do \
		name=`basename $$i`; \
		echo "Adding a patch for $$i ($$name)"; \
		/usr/bin/diff -w -C 0 qemu-$(QEMU_VERSION)/$${i}.orig qemu-$(QEMU_VERSION)/$$i | filterdiff --remove-timestamps >> $(QEMU_PATCHFILE) ; \
		echo $$? > /dev/null ;\
	done
	@for i in $$(cat qemu-$(QEMU_VERSION)-patches/LISTNEW) ; do \
		name=`basename $$i`; \
		echo "Adding a patch for $$i ($$name)"; \
		/usr/bin/diff -w -C 0 qemu-$(QEMU_VERSION)/$${i}.orig qemu-$(QEMU_VERSION)/$$i | filterdiff --remove-timestamps >> $(QEMU_PATCHFILE) ; \
		echo $$? > /dev/null ;\
	done

qemu-patch:
	cd qemu-$(QEMU_VERSION) && /usr/bin/patch -p 1 < ../$(QEMU_PATCHFILE)


clean: $(CLEAN_TARGETS)


.PHONY: all clean 
.PHONY: qemu 
.PHONY: $(CLEAN_TARGETS) 
