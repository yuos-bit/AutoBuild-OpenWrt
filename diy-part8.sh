#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
# 复制E8820V1配置文件到编译目录
cp -rf $GITHUB_WORKSPACE/patchs/E8820V1/* $GITHUB_WORKSPACE/openwrt/target/linux/ath79/

# 复制E8820V2配置文件到编译目录
cp -rf $GITHUB_WORKSPACE/patchs/E8820V2/mt7621.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt7621.mk
cp -rf $GITHUB_WORKSPACE/patchs/E8820V2/mt7621_zte_e8820v2.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7621_zte_e8820v2.dts
cp -rf $GITHUB_WORKSPACE/patchs/E8820V2/01_leds $GITHUB_WORKSPACE/openwrt/target/linux/ramips/mt7621/base-files/etc/board.d/01_leds
## 复制小米路由配置文件到编译目录
# MT7628
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7628an_xiaomi_mi-router-4c.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7628an_xiaomi_mi-router-4c.dts
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7628an_xiaomi_mi-router-3c.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7628an_xiaomi_mi-router-3c.dts
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7628an_xiaomi_mi-router-3a.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7628an_xiaomi_mi-router-3a.dts
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt76x8/mt76x8.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt76x8.mk
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt76x8/02_network $GITHUB_WORKSPACE/openwrt/target/linux/ramips/mt76x8/base-files/etc/board.d/02_network
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt76x8/mac80211.sh $GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/files/lib/wifi/mac80211.sh
# MT7620
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620a_xiaomi_mi-router-3x.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7620a_xiaomi_mi-router-3x.dts
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620a_xiaomi_mi-router-3.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7620a_xiaomi_mi-router-3.dts
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620/mt7620.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt7620.mk
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620/02_network $GITHUB_WORKSPACE/openwrt/target/linux/ramips/mt7620/base-files/etc/board.d/02_network
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620/mac80211.sh $GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/files/lib/wifi/mac80211.sh
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620/path/ramips $GITHUB_WORKSPACE/openwrt/package/boot/uboot-envtools/files/ramips
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620/path/platform.sh $GITHUB_WORKSPACE/openwrt/target/linux/ramips/mt7620/base-files/lib/upgrade/platform.sh

# MT7621
cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7621_xiaomi_mi-router-4a-gigabit.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7621_xiaomi_mi-router-4a-gigabit.dts

#备用方案
sed -i 's/git.openwrt.org\/project\/luci.git;openwrt-21.02/github.com\/coolsnowwolf\/luci.git;master/g' feeds.conf.default

# 增加软件包
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;master' feeds.conf.default
sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master' feeds.conf.default
sed -i '$a src-git small https://github.com/kenzok8/small.git;master' feeds.conf.default
sed -i '$a src-git small8 https://github.com/kenzok8/small-package.git;main' feeds.conf.default

# # 删除冲突包
# rm -rf feeds/smpackage/{base-files,dnsmasq,firewall*,fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd-alt,miniupnpd-iptables,wireless-regdb}

# 修改默认dnsmasq为dnsmasq-full
sed -i 's/dnsmasq/dnsmasq-full firewall iptables block-mount coremark kmod-nf-nathelper kmod-nf-nathelper-extra kmod-ipt-raw kmod-ipt-raw6 kmod-tun/g' include/target.mk

# 修改默认编译LUCI进系统
sed -i 's/ppp-mod-pppoe/iptables-mod-tproxy iptables-mod-extra ipset ip-full ppp ppp-mod-pppoe default-settings luci curl ca-certificates/g' include/target.mk

# 修改默认红米AC2100 wifi驱动为闭源驱动
sed -i 's/kmod-mt7603 kmod-mt7615e kmod-mt7615-firmware/kmod-mt7603e kmod-mt7615d luci-app-mtwifi -wpad-openssl/g' target/linux/ramips/image/mt7621.mk

# 修改默认小米路由4A千兆版 wifi驱动为闭源驱动
sed -i 's/kmod-mt7603 kmod-mt76x2/kmod-mt7603e kmod-mt76x2e luci-app-mtwifi -wpad-openssl/g' target/linux/ramips/image/mt7621.mk

# 修改默认小米路由3硬改版 wifi驱动为闭源驱动
# sed -i 's/kmod-mt76x2 kmod-usb2 kmod-usb-ohci/kmod-mt7612e kmod-usb2 kmod-usb-ohci luci-app-mtwifi -wpad-openssl/g' target/linux/ramips/image/mt7621.mk

# 修改默认E8820V2 wifi驱动为闭源驱动
# sed -i 's/kmod-mt7603 kmod-mt76x2 kmod-usb3 kmod-usb-ledtrig-usbport luci/kmod-mt7603e kmod-mt7612e luci-app-mtwifi kmod-usb3 kmod-usb-ledtrig-usbport wpad luci/g' target/linux/ramips/image/mt7621.mk

# 修改默认小米路由3G wifi驱动为闭源驱动
# sed -i 's/kmod-mt7603 kmod-mt76x2/kmod-mt7603e kmod-mt76x2e luci-app-mtwifi -wpad-openssl/g' target/linux/ramips/image/mt7621.mk

# 修改默认斐讯K2Pwifi驱动为闭源驱动
# sed -i 's/kmod-mt7615e kmod-mt7615-firmware/-luci-newapi -wpad-openssl kmod-mt7615d_dbdc wireless-tools/g' target/linux/ramips/image/mt7621.mk

# 设置闭源驱动开机自启
sed -i '2a ifconfig rai0 up\nifconfig ra0 up\nbrctl addif br-lan rai0\nbrctl addif br-lan ra0' package/base-files/files/etc/rc.local

# 单独拉取软件包
git clone -b Lienol-default-settings https://github.com/yuos-bit/other package/default-settings
git clone -b main --single-branch https://github.com/yuos-bit/other package/yuos
# git clone -b main --single-branch https://github.com/siwind/luci-app-usb_printer.git package/yuos/luci-app-usb_printer

# 添加iptables-mod-socket
cp -rf $GITHUB_WORKSPACE/patchs/5.4/iptables-mod-socket.patch $GITHUB_WORKSPACE/openwrt/package/iptables-mod-socket.patch
patch -p1 < $GITHUB_WORKSPACE/openwrt/package/iptables-mod-socket.patch

# 添加 kmod-nf-tproxy 依赖
sed -i 's/DEPENDS\+=+kmod-ipt-conntrack +IPV6:kmod-nf-conntrack6/DEPENDS\+=+kmod-nf-tproxy +kmod-nf-conntrack +IPV6:kmod-nf-conntrack6/' package/kernel/linux/modules/netfilter.mk

# 添加 ipt-socket 依赖
sed -i '/$(eval $(call KernelPackage,ipt-led))/a \
\
define KernelPackage/ipt-socket\n\
  TITLE:=Iptables socket matching support\n\
  DEPENDS+=+kmod-nf-socket +kmod-nf-conntrack +IPV6:kmod-nf-conntrack6\n\
  KCONFIG:=$(KCONFIG_IPT_SOCKET)\n\
  FILES:=$(foreach mod,$(IPT_SOCKET-m),$(LINUX_DIR)/net/$(mod).ko)\n\
  AUTOLOAD:=$(call AutoProbe,$(notdir $(IPT_SOCKET-m)))\n\
  $(call AddDepends/ipt)\n\
endef\n\
\n\
define KernelPackage/ipt-socket/description\n\
  Kernel modules for socket matching\n\
endef\n\
\n\
$(eval $(call KernelPackage,ipt-socket))' package/kernel/linux/modules/netfilter.mk

# 添加 iptables-mod-socket 依赖
sed -i '382i\ \
define Package/iptables-mod-socket\n\
$(call Package/iptables/Module, +kmod-ipt-socket)\n\
  TITLE:=Socket match iptables extensions\n\
endef\n\
\n\
define Package/iptables-mod-socket/description\n\
Socket match iptables extensions.\n\
\n\
 Matches:\n\
  - socket\n\
\n\
endef' package/network/utils/iptables/Makefile

# 添加 kmod-inet-diag 依赖
sed -i '/define KernelPackage\/wireguard/,/$(eval $(call KernelPackage,wireguard))/c\
\
define KernelPackage/inet-diag\n\
  SUBMENU:=$(NETWORK_SUPPORT_MENU)\n\
  TITLE:=INET diag support for ss utility\n\
  KCONFIG:= \\\n\
	CONFIG_INET_DIAG \\\n\
	CONFIG_INET_TCP_DIAG \\\n\
	CONFIG_INET_UDP_DIAG \\\n\
	CONFIG_INET_RAW_DIAG \\\n\
	CONFIG_INET_DIAG_DESTROY=n\n\
  FILES:= \\\n\
	$(LINUX_DIR)/net/ipv4/inet_diag.ko \\\n\
	$(LINUX_DIR)/net/ipv4/tcp_diag.ko \\\n\
	$(LINUX_DIR)/net/ipv4/udp_diag.ko \\\n\
	$(LINUX_DIR)/net/ipv4/raw_diag.ko@ge4.10\n\
  AUTOLOAD:=$(call AutoLoad,31,inet_diag tcp_diag udp_diag raw_diag@ge4.10)\n\
endef\n\
\n\
define KernelPackage/inet-diag/description\n\
  Support for INET (TCP, DCCP, etc) socket monitoring interface used by\n\
  native Linux tools such as ss.\n\
endef\n\
\n\
$(eval $(call KernelPackage,inet-diag))' package/kernel/linux/modules/netsupport.mk

# 添加 kmod-nf-socket 依赖
sed -i '/$(eval \$(call KernelPackage,nft-queue))/a\
\
define KernelPackage/nft-socket\n\
  SUBMENU:=$(NF_MENU)\n\
  TITLE:=Netfilter nf_tables socket support\n\
  DEPENDS:=+kmod-nft-core +kmod-nf-socket\n\
  FILES:=$(foreach mod,$(NFT_SOCKET-m),$(LINUX_DIR)/net/$(mod).ko)\n\
  AUTOLOAD:=$(call AutoProbe,$(notdir $(NFT_SOCKET-m)))\n\
  KCONFIG:=$(KCONFIG_NFT_SOCKET)\n\
endef\n\
\n\
$(eval $(call KernelPackage,nft-socket))\n\
\n\
define KernelPackage/nft-tproxy\n\
  SUBMENU:=$(NF_MENU)\n\
  TITLE:=Netfilter nf_tables tproxy support\n\
  DEPENDS:=+kmod-nft-core +kmod-nf-tproxy +kmod-nf-conntrack\n\
  FILES:=$(foreach mod,$(NFT_TPROXY-m),$(LINUX_DIR)/net/$(mod).ko)\n\
  AUTOLOAD:=$(call AutoProbe,$(notdir $(NFT_TPROXY-m)))\n\
  KCONFIG:=$(KCONFIG_NFT_TPROXY)\n\
endef\n\
\n\
$(eval $(call KernelPackage,nft-tproxy))\n\
\n\
define KernelPackage/nft-compat\n\
  SUBMENU:=$(NF_MENU)\n\
  TITLE:=Netfilter nf_tables compat support\n\
  DEPENDS:=+kmod-nft-core +kmod-nf-ipt\n\
  FILES:=$(foreach mod,$(NFT_COMPAT-m),$(LINUX_DIR)/net/$(mod).ko)\n\
  AUTOLOAD:=$(call AutoProbe,$(notdir $(NFT_COMPAT-m)))\n\
  KCONFIG:=$(KCONFIG_NFT_COMPAT)\n\
endef\n\
\n\
$(eval $(call KernelPackage,nft-compat))\n\
\n\
define KernelPackage/nft-xfrm\n\
  SUBMENU:=$(NF_MENU)\n\
  TITLE:=Netfilter nf_tables xfrm support (ipsec)\n\
  DEPENDS:=+kmod-nft-core\n\
  FILES:=$(foreach mod,$(NFT_XFRM-m),$(LINUX_DIR)/net/$(mod).ko)\n\
  AUTOLOAD:=$(call AutoProbe,$(notdir $(NFT_XFRM-m)))\n\
  KCONFIG:=$(KCONFIG_NFT_XFRM)\n\
endef\n\
\n\
$(eval $(call KernelPackage,nft-xfrm))' package/kernel/linux/modules/netfilter.mk

#添加 kmod-inet-diag
sed -i '1227i\
define KernelPackage/inet-diag\n\
  SUBMENU:=$(NETWORK_SUPPORT_MENU)\n\
  TITLE:=INET diag support for ss utility\n\
  KCONFIG:= \\\n\
\tCONFIG_INET_DIAG \\\n\
\tCONFIG_INET_TCP_DIAG \\\n\
\tCONFIG_INET_UDP_DIAG \\\n\
\tCONFIG_INET_RAW_DIAG \\\n\
\tCONFIG_INET_DIAG_DESTROY=n\n\
  FILES:= \\\n\
\t$(LINUX_DIR)/net/ipv4/inet_diag.ko \\\n\
\t$(LINUX_DIR)/net/ipv4/tcp_diag.ko \\\n\
\t$(LINUX_DIR)/net/ipv4/udp_diag.ko \\\n\
\t$(LINUX_DIR)/net/ipv4/raw_diag.ko\n\
  AUTOLOAD:=$(call AutoLoad,31,inet_diag tcp_diag udp_diag raw_diag)\n\
endef\n\
\n\
define KernelPackage/inet-diag/description\n\
Support for INET (TCP, DCCP, etc) socket monitoring interface used by\n\
native Linux tools such as ss.\n\
endef\n\
\n\
$(eval $(call KernelPackage,inet-diag))' package/kernel/linux/modules/netsupport.mk


# nf-tproxy nf-socket
sed -i '/$(eval $(call KernelPackage,nf-flow))/a\
\
define KernelPackage/nf-socket\n  SUBMENU:=$(NF_MENU)\n  TITLE:=Netfilter socket lookup support\n  KCONFIG:= $(KCONFIG_NF_SOCKET)\n  FILES:=$(foreach mod,$(NF_SOCKET-m),$(LINUX_DIR)/net/$(mod).ko)\n  AUTOLOAD:=$(call AutoProbe,$(notdir $(NF_SOCKET-m)))\nendef\n\n$(eval $(call KernelPackage,nf-socket))\
\
define KernelPackage/nf-tproxy\n  SUBMENU:=$(NF_MENU)\n  TITLE:=Netfilter tproxy support\n  KCONFIG:= $(KCONFIG_NF_TPROXY)\n  FILES:=$(foreach mod,$(NF_TPROXY-m),$(LINUX_DIR)/net/$(mod).ko)\n  AUTOLOAD:=$(call AutoProbe,$(notdir $(NF_TPROXY-m)))\nendef\n\n$(eval $(call KernelPackage,nf-tproxy))' package/kernel/linux/modules/netfilter.mk
