#!/bin/bash
#=================================================
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#=================================================


# 增加软件包
#sed -i 's#github.com/immortalwrt/packages.git;openwrt-21.02#github.com/yuos-bit/other.git;immortalwrt-packages-21.02#' feeds.conf.default
#sed -i 's#github.com/immortalwrt/luci.git;openwrt-21.02#github.com/yuos-bit/other.git;immortalwrt-luci-21.02#' feeds.conf.default
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;dev' feeds.conf.default
sed -i '$a src-git small8 https://github.com/kenzok8/openwrt-packages.git;master' feeds.conf.default

# 修改默认编译LUCI进系统
sed -i 's/ppp-mod-pppoe/iptables-mod-tproxy iptables-mod-extra ipset ip-full ppp-mod-pppoe curl ca-certificates/g' include/target.mk

# 设置闭源驱动开机自启
sed -i '2a ifconfig rai0 up\nifconfig ra0 up\nbrctl addif br-lan rai0\nbrctl addif br-lan ra0' package/base-files/files/etc/rc.local

# 设置shadowsocksr-libev
# sed -i 's/ +libopenssl-legacy//g' feeds/small/shadowsocksr-libev/Makefile

# 单独拉取软件包
git clone -b default-imwrt-mt7981 https://github.com/yuos-bit/other package/default-settings
git clone -b debug https://github.com/yuos-bit/luci-theme-edge2 package/luci-theme-edge2
git clone -b passwall https://github.com/yuos-bit/other package/passwall
# 测试 tailscale
git clone -b tailscale https://github.com/yuos-bit/other package/tailscale
# 更改默认wifi
# cp -rf $GITHUB_WORKSPACE/patchs/NX30Pro/mtwifi.sh package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# 创建 iptables-mod-socket / kmod-ipt-socket stub 包
# 说明：21.02 分支中 socket match 功能已内置在 kmod-ipt-tproxy / iptables-mod-tproxy 中，
# 但 PassWall 会检查独立的 iptables-mod-socket 包名，故创建虚包满足依赖检测
mkdir -p package/ipt-socket-stub
cat > package/ipt-socket-stub/Makefile << 'MAKEFILE_EOF'
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=ipt-socket-stub
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

# --- iptables-mod-socket userspace stub ---
define Package/iptables-mod-socket
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Firewall
  TITLE:=Socket match iptables extension (provided by iptables-mod-tproxy)
  DEPENDS:=+iptables-mod-tproxy
  PKGARCH:=all
endef

define Package/iptables-mod-socket/description
  This is a meta-package: libxt_socket.so is already shipped inside
  iptables-mod-tproxy on OpenWrt 21.02. This stub satisfies the
  iptables-mod-socket dependency check used by PassWall.
endef

define Package/iptables-mod-socket/install
	true
endef

# --- kmod-ipt-socket kernel stub ---
define KernelPackage/ipt-socket
  SUBMENU:=Netfilter Extensions
  TITLE:=Socket match netfilter module (provided by kmod-ipt-tproxy)
  DEPENDS:=+kmod-ipt-tproxy
  HIDDEN:=1
endef

define KernelPackage/ipt-socket/description
  This is a meta-package: xt_socket.ko is already built as part of
  kmod-ipt-tproxy on OpenWrt 21.02. This stub satisfies the
  kmod-ipt-socket dependency for iptables-mod-socket.
endef

$(eval $(call BuildPackage,iptables-mod-socket))
$(eval $(call KernelPackage,ipt-socket))
MAKEFILE_EOF

# 删除软件包默认设置
rm -rf package/emortal/default-settings