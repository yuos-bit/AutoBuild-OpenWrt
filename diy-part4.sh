# #!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
sed -i 's|https://github.com/Lienol/openwrt-luci.git;17.01|https://github.com/coolsnowwolf/luci.git;master|' feeds.conf.default
# 增加软件包
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;master' feeds.conf.default
sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master' feeds.conf.default
sed -i '$a src-git small https://github.com/kenzok8/small.git;master' feeds.conf.default
sed -i '$a src-git small8 https://github.com/kenzok8/small-package.git;main' feeds.conf.default

# 覆盖源码
cp -rf $GITHUB_WORKSPACE/patchs/4.14/dts/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/
cp -rf $GITHUB_WORKSPACE/patchs/4.14/mt76x8/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/
cp -rf $GITHUB_WORKSPACE/patchs/4.14/mt7621/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/
cp -rf $GITHUB_WORKSPACE/patchs/4.14/board.d/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/base-files/etc/board.d/
cp -rf $GITHUB_WORKSPACE/patchs/4.14/wifi/mac80211.sh $GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/files/lib/wifi/mac80211.sh

# 修改默认dnsmasq为dnsmasq-full
sed -i 's/dnsmasq-full/dnsmasq-full coremark kmod-nf-nathelper kmod-nf-nathelper-extra kmod-ipt-raw kmod-ipt-raw6 kmod-tun luci-app-webadmin/g' include/target.mk

# 修改默认编译LUCI进系统
sed -i 's/ppp-mod-pppoe/iptables-mod-tproxy iptables-mod-extra ipset ip-full ppp ppp-mod-pppoe/g' include/target.mk