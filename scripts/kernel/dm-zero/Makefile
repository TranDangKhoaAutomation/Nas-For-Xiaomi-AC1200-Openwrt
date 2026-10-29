include $(TOPDIR)/rules.mk

PKG_NAME:=dm-zero
PKG_VERSION:=6.12.112
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

define KernelPackage/dm-zero
  SUBMENU:=Block Devices
  TITLE:=Device mapper zero target for BitLocker
  DEPENDS:=+kmod-dm
  FILES:=$(PKG_BUILD_DIR)/dm-zero.ko
  AUTOLOAD:=$(call AutoLoad,31,dm-zero,1)
endef

define KernelPackage/dm-zero/description
  The upstream Linux dm-zero target, built for the exact OpenWrt kernel.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/Makefile ./src/dm-zero.c $(PKG_BUILD_DIR)/
endef

define Build/Compile
	+$(KERNEL_MAKE) $(PKG_JOBS) M="$(PKG_BUILD_DIR)" modules
endef

$(eval $(call KernelPackage,dm-zero))
