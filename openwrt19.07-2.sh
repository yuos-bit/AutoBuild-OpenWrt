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
# 修改 edge 为默认主题,可根据你喜欢的修改成其他的（不选择那些会自动改变为默认主题的主题才有效果）
sed -i 's/luci-theme-bootstrap/luci-theme-edge/g' openwrt/feeds/luci/collections/luci/Makefile

# 单独拉取软件包
#git clone -b default-openwrt-19.07 https://github.com/yuos-bit/other package/default-settings
git clone -b default-19.07-Development https://github.com/yuos-bit/other package/default-settings
git clone -b main-19.07 https://github.com/yuos-bit/other package/yuos

# nft-fullcone
git clone -b main --single-branch https://github.com/fullcone-nat-nftables/nftables-1.0.5-with-fullcone package/nftables
git clone -b master --single-branch https://github.com/fullcone-nat-nftables/libnftnl-1.2.4-with-fullcone package/libnftnl

# 最新主题
find feeds/luci -type d -name "luci-theme-bootstrap" -exec rm -rf {} +
rm -rf package/yuos/luci-theme-bootstrap
# git clone -b master https://github.com/eamonxg/luci-theme-bootstrap package/yuos

cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt76x8/mac80211.sh package/kernel/mac80211/files/lib/wifi/mac80211.sh

# 
# 测试编译时间
YUOS_DATE="$(date +%Y.%m.%d)(Development)"
BUILD_STRING=${BUILD_STRING:-$YUOS_DATE}
echo "Write build date in openwrt : $BUILD_DATE"
echo -e '\nyuos Build @ '${BUILD_STRING}'\n'  >> package/base-files/files/etc/banner
sed -i '/DISTRIB_REVISION/d' package/base-files/files/etc/openwrt_release
echo "DISTRIB_REVISION=''" >> package/base-files/files/etc/openwrt_release
sed -i '/DISTRIB_DESCRIPTION/d' package/base-files/files/etc/openwrt_release
echo "DISTRIB_DESCRIPTION='yuos Build @ ${BUILD_STRING}'" >> package/base-files/files/etc/openwrt_release

# 修改 luci version.lua
sed -i '/luciversion/d' feeds/luci/modules/luci-base/luasrc/version.lua
echo "luciversion = '${BUILD_STRING}'" >> feeds/luci/modules/luci-base/luasrc/version.lua
# 
#升级cmake
find . -type d -name "cmake" -exec rm -r {} +
mkdir -p tools/cmake/
cp -rf $GITHUB_WORKSPACE/patchs/4.14/tools/cmake/* tools/cmake/

#升级golang
find . -type d -name "golang" -exec rm -r {} +
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 20.x feeds/packages/lang/golang