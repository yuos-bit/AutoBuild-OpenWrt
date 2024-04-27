#!/bin/bash
#=================================================
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#=================================================

# 修改默认IP
sed -i 's/192.168.1.1/10.32.0.1/g' package/base-files/files/bin/config_generate
# 修改网关
sed -i 's/192.168.$((addr_offset++)).1/10.32.$((addr_offset++)).1/g' package/base-files/files/bin/config_generate

# 修改主机名称
sed -i 's/OpenWrt/Yuos/g' package/base-files/files/bin/config_generate

# 修改默认wifi名称ssid为Xiaoyu-Wifi
sed -i 's/ssid=OpenWrt/ssid=Xiaomi-Wifi/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh

# 修改默认wifi密码key为1234567890
sed -i 's/encryption=none/encryption=psk2/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh

#使用sed 在第四行后添加新字
sed -i '/set wireless.default_radio${devidx}.encryption=psk2/a\set wireless.default_radio${devidx}.key=1234567890' package/kernel/mac80211/files/lib/wifi/mac80211.sh


# Add kernel build user
[ -z $(grep "CONFIG_KERNEL_BUILD_USER=" .config) ] &&
    echo 'CONFIG_KERNEL_BUILD_USER="MOLUN"' >>.config ||
    sed -i 's@\(CONFIG_KERNEL_BUILD_USER=\).*@\1$"MOLUN"@' .config

# Add kernel build domain
[ -z $(grep "CONFIG_KERNEL_BUILD_DOMAIN=" .config) ] &&
    echo 'CONFIG_KERNEL_BUILD_DOMAIN="GitHub Actions"' >>.config ||
    sed -i 's@\(CONFIG_KERNEL_BUILD_DOMAIN=\).*@\1$"GitHub Actions"@' .config

# 添加5.4内核ACC、shortcut-fe补丁
# openwrt21.02 netfilter补丁\
cp -rf $GITHUB_WORKSPACE/patchs/firewall/* package/firmware/
patch -p1 < package/firmware/001-fix-firewall-flock.patch

# nft-fullcone
git clone -b main --single-branch https://github.com/fullcone-nat-nftables/nftables-1.0.5-with-fullcone package/nftables
git clone -b master --single-branch https://github.com/fullcone-nat-nftables/libnftnl-1.2.4-with-fullcone package/libnftnl

# 打补丁
wget -O package/firmware/xt_FULLCONENAT.c https://raw.githubusercontent.com/Chion82/netfilter-full-cone-nat/master/xt_FULLCONENAT.c
cp -rf package/firmware/xt_FULLCONENAT.c package/nftables/include/linux/netfilter/xt_FULLCONENAT.c
cp -rf package/firmware/xt_FULLCONENAT.c package/libnftnl/include/linux/netfilter/xt_FULLCONENAT.c
cp -rf package/firmware/xt_FULLCONENAT.c package/libs/libnetfilter-conntrack/xt_FULLCONENAT.c

# dnsmasq-full升级2.89
rm -rf package/network/services/dnsmasq
cp -rf $GITHUB_WORKSPACE/patchs/5.4/dnsmasq package/network/services/dnsmasq

# 测试编译时间
YUOS_DATE="$(date +%Y.%m.%d)(纯享版)"
BUILD_STRING=${BUILD_STRING:-$YUOS_DATE}
echo "Write build date in openwrt : $BUILD_DATE"
echo -e '\n小渔学长 Build @ '${BUILD_STRING}'\n'  >> package/base-files/files/etc/banner
sed -i '/DISTRIB_REVISION/d' package/base-files/files/etc/openwrt_release
echo "DISTRIB_REVISION=''" >> package/base-files/files/etc/openwrt_release
sed -i '/DISTRIB_DESCRIPTION/d' package/base-files/files/etc/openwrt_release
echo "DISTRIB_DESCRIPTION='小渔学长 Build @ ${BUILD_STRING}'" >> package/base-files/files/etc/openwrt_release
sed -i '/luciversion/d' feeds/luci/modules/luci-base/luasrc/version.lua



#升级golang
find . -type d -name "golang" -exec rm -r {} +
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 22.x feeds/packages/lang/golang

#设置软件唯一性
find . -type d -name "gn" -exec rm -r {} +
mkdir -p feeds/small8/gn/
cp -rf $GITHUB_WORKSPACE/patchs/5.4/gn/* feeds/small8/gn/

find . -type d -name "naiveproxy" -exec rm -r {} +
mkdir -p feeds/small8/naiveproxy/
mkdir -p feeds/helloworld/naiveproxy/
cp -rf $GITHUB_WORKSPACE/patchs/5.4/naiveproxy/* feeds/small8/naiveproxy/
cp -rf $GITHUB_WORKSPACE/patchs/5.4/naiveproxy/* feeds/helloworld/naiveproxy/

# rm -rf feeds/helloworld/hysteria
rm -rf feeds/small/hysteria
cp -rf $GITHUB_WORKSPACE/patchs/5.4/hysteria/* feeds/packages/net/hysteria/
cp -rf $GITHUB_WORKSPACE/patchs/5.4/hysteria/* feeds/helloworld/hysteria/



rm -rf feeds/small/luci-app-passwall2
rm -rf feeds/small/brook
rm -rf feeds/helloworld/shadowsocks-rust
rm -rf feeds/small/shadowsocks-rust

# rm -rf feeds/helloworld/simple-obfs
rm -rf feeds/small/simple-obfs


rm -rf feeds/helloworld/v2ray-plugin
rm -rf feeds/small/v2ray-plugin
# cp -rf feeds/small8/xray-core/* feeds/packages/net/xray-core/
# cp -rf feeds/small8/xray-core/* feeds/Lienol/net/xray-core/
# find . -type d -name "sing-box" -exec rm -r {} +

cp -rf $GITHUB_WORKSPACE/patchs/5.4/tailscale/* feeds/packages/net/tailscale/

#升级cmake
rm -rf tools/cmake
mkdir -p tools/cmake/
cp -rf $GITHUB_WORKSPACE/patchs/5.4/tools/cmake/* tools/cmake/

### 后补的

#FullCone Patch
git clone -b master --single-branch https://github.com/QiuSimons/openwrt-fullconenat package/fullconenat
# Patch FireWall for fullcone
mkdir package/network/config/firewall/patches
wget -P package/network/config/firewall/patches/ https://raw.githubusercontent.com/LGA1150/fullconenat-fw3-patch/master/fullconenat.patch

pushd feeds/luci
wget -O- https://raw.githubusercontent.com/LGA1150/fullconenat-fw3-patch/master/luci.patch | git apply
popd

### 后补的
# SFE kernel patch
cp -n $GITHUB_WORKSPACE/patchs/5.4/hack-5.4/* target/linux/generic/hack-5.4/

# 临时处理
# rm -rf target/linux/generic/hack-5.4/952-net-conntrack-events-support-multiple-registrant.patch
# rm -rf target/linux/generic/hack-5.4/953-net-patch-linux-kernel-to-support-shortcut-fe.patch
# 临时处理

cp -n $GITHUB_WORKSPACE/patchs/5.4/pending-5.4/* target/linux/generic/pending-5.4/
cp -rf $GITHUB_WORKSPACE/patchs/5.4/sfe/* package/yuos/

# 解决kconfig补丁
wget -P target/linux/generic/backport-5.4/ https://raw.githubusercontent.com/hanwckf/immortalwrt-mt798x/openwrt-21.02/target/linux/generic/backport-5.4/500-v5.15-fs-ntfs3-Add-NTFS3-in-fs-Kconfig-and-fs-Makefile.patch
patch -p1 < target/linux/generic/backport-5.4/500-v5.15-fs-ntfs3-Add-NTFS3-in-fs-Kconfig-and-fs-Makefile.patch

mkdir -p target/linux/generic/files-5.4/
cp -rf $GITHUB_WORKSPACE/patchs/5.4/files-5.4/* target/linux/generic/files-5.4/

# 测试
cp -rf $GITHUB_WORKSPACE/patchs/5.4/netsupport.mk package/kernel/linux/modules/netsupport.mk


# upx测试
find . -type d -name "upx" -exec rm -r {} +
find . -type d -name "ucl" -exec rm -r {} +
# git clone https://github.com/kuoruan/openwrt-upx.git package/openwrt-upx
# mkdir -p tools/upx/
# mkdir -p tools/ucl/
# cp -rf $GITHUB_WORKSPACE/patchs/5.4/tools/upx/* tools/upx/
# cp -rf $GITHUB_WORKSPACE/patchs/5.4/tools/upx/* feeds/small8/upx/
# cp -rf $GITHUB_WORKSPACE/patchs/5.4/tools/ucl/* tools/ucl/
# cp -rf $GITHUB_WORKSPACE/patchs/5.4/tools/ucl/* feeds/small8/ucl/
# sed -i '11a tools-y += ucl upx \n$(curdir)/upx/compile := $(curdir)/ucl/compile' tools/Makefile

rm -rf feeds/small8/fullconenat-nft
rm -rf feeds/small8/fullconenat

cp -rf $GITHUB_WORKSPACE/patchs/xray/1.5.3/* feeds/small8/xray-core/
cp -rf $GITHUB_WORKSPACE/patchs/xray/1.5.3/* feeds/small/xray-core/
cp -rf $GITHUB_WORKSPACE/patchs/xray/1.5.3/* feeds/helloworld/xray-core/
cp -rf $GITHUB_WORKSPACE/patchs/xray/1.5.3/* feeds/packages/net/xray-core/
cp -rf $GITHUB_WORKSPACE/patchs/xray/1.5.3/* package/feeds/packages/xray-core/