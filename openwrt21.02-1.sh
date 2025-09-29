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
#patches
wget https://github.com/quintus-lab/openwrt-rockchip/raw/21.02/patches/1001-dnsmasq-add-filter-aaaa-option.patch
wget https://github.com/quintus-lab/openwrt-rockchip/raw/21.02/patches/1003-luci-app-firewall_add_fullcone.patch
wget https://github.com/quintus-lab/openwrt-rockchip/raw/21.02/patches/1002-add-fullconenat-support.patch

patch -p1 < ./1002-add-fullconenat-support.patch
patch -p1 < ./1003-luci-app-firewall_add_fullcone.patch
cp ./1001-dnsmasq-add-filter-aaaa-option.patch package/network/services/dnsmasq/patches/

pushd feeds/luci
wget -O- https://github.com/LGA1150/fullconenat-fw3-patch/raw/master/luci.patch | git apply
popd

# SFE kernel patch
pushd target/linux/generic/hack-5.4
wget https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/generic/hack-5.4/999-shortcut-fe-support.patch
popd
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/shortcut-fe package/new/shortcut-fe
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/fast-classifier package/new/fast-classifier

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
# MT76X8
cp -rf $GITHUB_WORKSPACE/patchs/5.4/mt76x8/dts/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/
cp -rf $GITHUB_WORKSPACE/patchs/5.4/mt76x8/mt76x8.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt76x8.mk
cp -rf $GITHUB_WORKSPACE/patchs/5.4/mt76x8/02_network $GITHUB_WORKSPACE/openwrt/target/linux/ramips/mt76x8/base-files/etc/board.d/02_network
#备用方案
sed -i 's/git.openwrt.org\/project\/luci.git;openwrt-21.02/github.com\/coolsnowwolf\/luci.git;master/g' feeds.conf.default
sed -i 's/git.openwrt.org\feed\/packages.git;openwrt-21.02/github.com\/coolsnowwolf\/packages.git;master/g' feeds.conf.default

# 增加软件包
#sed -i 's#github.com/immortalwrt/packages.git;openwrt-21.02#github.com/yuos-bit/other.git;immortalwrt-packages-21.02#' feeds.conf.default
#sed -i 's#github.com/immortalwrt/luci.git;openwrt-21.02#github.com/yuos-bit/other.git;immortalwrt-luci-21.02#' feeds.conf.default
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;master' feeds.conf.default
sed -i '$a src-git small8 https://github.com/kenzok8/small-package.git;main' feeds.conf.default

# 修改默认dnsmasq为dnsmasq-full
sed -i 's/dnsmasq/dnsmasq-full firewall iptables block-mount coremark kmod-nf-nathelper kmod-nf-nathelper-extra kmod-ipt-raw kmod-ipt-raw6 kmod-tun/g' include/target.mk

# 修改默认编译LUCI进系统
sed -i 's/ppp-mod-pppoe/iptables-mod-tproxy iptables-mod-extra ipset ip-full ppp ppp-mod-pppoe default-settings luci curl ca-certificates/g' include/target.mk

# 修改默认红米AC2100 wifi驱动为闭源驱动
sed -i 's/kmod-mt7603 kmod-mt7615e kmod-mt7615-firmware/kmod-mt7603e kmod-mt7615d luci-app-mtwifi -wpad-openssl/g' target/linux/ramips/image/mt7621.mk

# 修改默认小米路由4A千兆版 wifi驱动为闭源驱动，更改闪存分区大小
sed -i 's/kmod-mt7603 kmod-mt76x2/kmod-mt7603e kmod-mt76x2e luci-app-mtwifi -wpad-openssl/g' target/linux/ramips/image/mt7621.mk
sed -i '1509s/IMAGE_SIZE := 14848k/IMAGE_SIZE := 16064k/' target/linux/ramips/image/mt7621.mk

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
git clone -b default-openwrt-21.02 https://github.com/yuos-bit/other package/default-settings
git clone -b passwall https://github.com/yuos-bit/other package/passwall
git clone -b main https://github.com/yuos-bit/other package/main

# 测试 tailscale
git clone -b tailscale https://github.com/yuos-bit/other package/tailscale

# 更改默认wifi
# cp -rf $GITHUB_WORKSPACE/patchs/NX30Pro/mtwifi.sh package/mtk/applications/mtwifi-cfg/files/mtwifi.sh


# 更新openssl3.0
rm -rf package/libs/openssl
git clone -b openssl https://github.com/yuos-bit/other package/openssl
cp -rf $GITHUB_WORKSPACE/patchs/immortalwrt-mt798x/openssl-module.mk $GITHUB_WORKSPACE/openwrt/include/openssl-module.mk

#超频 
#0x362=1100MHz
#0x312=1000MHz
#0x3B2=1200MHz
grep "rt_memc_w32(pll,MEMC_REG_CPU_PLL);" ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
if [ $? -ne 0 ]; then
echo fix over clock
sed -i 's/-111,49 +111,89/-111,49 +111,93/' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
sed -i 's/u32 xtal_clk, cpu_clk, bus_clk;/u32 xtal_clk, cpu_clk, bus_clk,i;/' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
sed -i '157i+		pll &= ~(0x7ff);' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
sed -i '158i+		pll |=  (0x362);' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
sed -i '159i+		rt_memc_w32(pll,MEMC_REG_CPU_PLL);' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
sed -i '160i+		for(i=0;i<1024;i++);' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
fi