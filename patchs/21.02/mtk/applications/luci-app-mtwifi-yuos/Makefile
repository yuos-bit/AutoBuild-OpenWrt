#
# Copyright (C) 2026 yuos-bit
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-mtwifi-yuos
LUCI_TITLE:=LuCI wireless panel for the MTK mt_wifi closed-source driver
LUCI_DESCRIPTION:=Rewritten Network->Wireless page for mtwifi-cfg: dual-band status dashboard, \
	repeater scan/join, per-SSID MAC access control, associated-station table with kick, 2.4G via mtwifi-sta ioctl helper
LUCI_DEPENDS:=+mtwifi-cfg +luci-mod-network +wireless-tools

PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
