RELEASE = $(shell uname -r)

PREREQS = install-buildessential install-tipcdeps

ifeq (wildcard /usr/src/linux-headers-$(RELEASE),)
PREREQS += install-headers
endif

MODULE_NAME = tipc.ko
MODULE = net/tipc/$(MODULE_NAME)
LINUX_RELEASE = 4.1.17-hypriotos-v7+

LINUX_DIR = linux
LINUX_CHECK = include/linux/pmu.h
LINUX_URL = https://github.com/raspberrypi/linux
LINUX_BRANCH = rpi-4.1.y

TIPC_DIR = tipcutils
TIPC_SRC = $(TIPC_DIR)/tipc-config/tipc-config.c
TIPC_URL = git://tipc.git.sourceforge.net/gitroot/tipc/tipcutils
TIPC_TAG = tipcutils2.0
TIPC_CONFIG = tipcutils/tipc-config/tipc-config

PATH := $(XCOMPILE):$(PATH)
export PATH

KERNEL=kernel7
JOBS=$(shell grep ^processor /proc/cpuinfo | wc -l)

define config_patch
--- .config	2016-03-21 13:42:01.526746834 +0100
+++ .config+tipc	2016-03-21 13:42:04.086746880 +0100
@@ -952,7 +952,8 @@
 CONFIG_SCTP_COOKIE_HMAC_MD5=y
 CONFIG_SCTP_COOKIE_HMAC_SHA1=y
 # CONFIG_RDS is not set
-# CONFIG_TIPC is not set
+CONFIG_TIPC=m
+CONFIG_TIPC_MEDIA_UDP=y
 CONFIG_ATM=m
 # CONFIG_ATM_CLIP is not set
 # CONFIG_ATM_LANE is not set
endef

export config_patch

ARCHIVE_DIR = rpi-tipc
ARCHIVE = $(ARCHIVE_DIR).tar.xz

all: $(ARCHIVE)

$(ARCHIVE): $(ARCHIVE_DIR)
	cd $< && tar cvf - . | xz > ../$@

$(ARCHIVE_DIR): $(MODULE) $(TIPC_CONFIG)
	-rm -r $@
	mkdir -p $(ARCHIVE_DIR)
	$(MAKE) -C $(TIPC_DIR) install DESTDIR=$(PWD)/$@
	$(MAKE) -C $(LINUX_DIR) modules_install INSTALL_MOD_PATH=$(PWD)/$@

$(TIPC_CONFIG): $(TIPC_SRC)
	cd $(TIPC_DIR) && ./bootstrap && ./configure
	$(MAKE) -C $(TIPC_DIR)

$(TIPC_SRC):
	git clone $(TIPC_URL) $(TIPC_DIR) && git -C $(TIPC_DIR) checkout $(TIPC_TAG)

$(LINUX_CHECK):
	-rm -rf $(LINUX_DIR)
	git clone --depth=1 --branch=$(LINUX_BRANCH) $(LINUX_URL) $(LINUX_DIR)

$(MODULE): $(LINUX_DIR)/scripts/mod/modpost
	$(MAKE) -C $(LINUX_DIR) $(MODULE)

$(LINUX_DIR)/scripts/mod/modpost: $(LINUX_DIR)/.config
	$(MAKE) -C $(LINUX_DIR) modules_prepare

$(LINUX_DIR)/.config: $(RPITOOLS_BIN) $(LINUX_CHECK)
	$(MAKE) -C $(LINUX_DIR) bcm2709_defconfig
	cd $(LINUX_DIR) && echo "$$config_patch" | patch -p0 .config

install-headers:
	apt install linux-headers-$(RELEASE)

install-buildessential:
	apt install build-essential libtool bc

install-tipcdeps:
	apt install libdaemon-dev libnl-3-dev

clean:
	$(MAKE) -C $(LINUX_DIR) mrproper

distclean:
	-rm -rf $(LINUX_DIR)
	-rm -rf $(ARCHIVE) $(ARCHIVE_DIR) $(TIPC_DIR)

.PHONY: install-headers install-build-essential install-tipcdeps clean distclean $(ARCHIVE_DIR)
