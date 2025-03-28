# #!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
# 修改默认dnsmasq为dnsmasq-full
sed -i 's/dnsmasq/dnsmasq-full firewall iptables block-mount coremark kmod-nf-nathelper kmod-nf-nathelper-extra kmod-ipt-raw kmod-ipt-raw6 kmod-tun/g' include/target.mk
# 修改默认编译LUCI进系统
sed -i 's/ppp-mod-pppoe/iptables-mod-tproxy iptables-mod-extra ipset ip-full ppp ppp-mod-pppoe default-settings luci curl ca-certificates/g' include/target.mk
#
# 复制小米路由配置文件到编译目录
cp -rf $GITHUB_WORKSPACE/patchs/4.14/dts/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/
cp -rf $GITHUB_WORKSPACE/patchs/4.14/mt76x8/mt76x8.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt76x8.mk
cp -rf $GITHUB_WORKSPACE/patchs/4.14/mt7621/mt7621.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt7621.mk
cp -rf $GITHUB_WORKSPACE/patchs/4.14/public/01_leds $GITHUB_WORKSPACE/openwrt/target/linux/ramips/base-files/etc/board.d/01_leds
cp -rf $GITHUB_WORKSPACE/patchs/4.14/public/02_network $GITHUB_WORKSPACE/openwrt/target/linux/ramips/base-files/etc/board.d/02_network
cp -rf $GITHUB_WORKSPACE/patchs/4.14/public/mac80211.sh $GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/files/lib/wifi/mac80211.sh

# 修改软件包版本为大杂烩-openwrt19.07
sed -i 's/git.openwrt.org\/feed\/packages.git;openwrt-19.07/github.com\/Lienol\/openwrt-packages.git;19.07/g' feeds.conf.default
sed -i 's/git.openwrt.org\/project\/luci.git;openwrt-19.07/github.com\/coolsnowwolf\/luci.git;master/g' feeds.conf.default

# 增加软件包
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;master' feeds.conf.default
sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master' feeds.conf.default
sed -i '$a src-git small https://github.com/kenzok8/small.git;master' feeds.conf.default
sed -i '$a src-git small8 https://github.com/kenzok8/small-package.git;main' feeds.conf.default
# 单独拉取软件包
git clone -b 19.07 https://github.com/yuos-bit/other package/19.07
git clone -b main --single-branch https://github.com/yuos-bit/other package/yuos