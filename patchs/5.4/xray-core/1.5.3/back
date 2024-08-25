include $(TOPDIR)/rules.mk

PKG_NAME:=Xray-core
PKG_VERSION:=1.8.7
PKG_RELEASE:=77

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/XTLS/Xray-core/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=skip

PKG_MAINTAINER:=Tianling Shen <cnsztl@immortalwrt.org>
PKG_LICENSE:=MPL-2.0
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=golang/host 
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0
PKG_BUILD_FLAGS:=no-mips16

GO_PKG:=github.com/xtls/xray-core
GO_PKG_BUILD_PKG:=$(GO_PKG)/main
GO_PKG_LDFLAGS_X:= \
	$(GO_PKG)/core.build=OpenWrt \
	$(GO_PKG)/core.version=$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk
define Download/upx
  FILE:=upx-4.2.3-amd64_linux.tar.xz
  URL_FILE:=upx.tar.xz
  URL:=https://github.com/upx/upx/releases/download/v4.2.3/
  HASH:=skip
endef
define Build/Prepare
	$(call Build/Prepare/Default)
	$(eval $(call Download,upx))
	$(TAR) --strip-components=1 -C $(PKG_BUILD_DIR)/ -xvf $(DL_DIR)/upx-4.2.3-amd64_linux.tar.xz
	$(CP) $(PKG_BUILD_DIR)/upx $(STAGING_DIR_HOST)/bin/upx
endef
define Package/xray/template
  TITLE:=A platform for building proxies to bypass network restrictions
  SECTION:=net
  CATEGORY:=Network
  URL:=https://xtls.github.io
endef

define Package/xray-core
  $(call Package/xray/template)
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
endef

define Package/xray-example
  $(call Package/xray/template)
  TITLE+= (example configs)
  DEPENDS:=xray-core
  PKGARCH:=all
endef

define Package/xray/description
  Xray, Penetrates Everything. It helps you to build your own computer network.
  It secures your network connections and thus protects your privacy.
endef

define Package/xray-core/description
  $(call Package/xray/description)
endef

define Package/xray-example/description
  $(call Package/xray/description)

  This includes example configuration files for xray-core.
endef

define Package/xray-core/conffiles
/etc/xray/
/etc/config/xray
endef

define Package/xray-core/install
	$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))
	$(INSTALL_DIR) $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/main $(1)/usr/bin/xray
	$(STAGING_DIR_HOST)/bin/upx --lzma --best $(1)/usr/bin/xray
	
endef

$(eval $(call BuildPackage,xray-core))
