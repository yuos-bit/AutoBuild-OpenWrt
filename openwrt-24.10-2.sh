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

# 修复libopenssl-legacy报错
sed -i 's/ +libopenssl-legacy//g' package/passwall/shadowsocksr-libev/Makefile

# 测试编译时间
YUOS_DATE="$(date +%Y.%m.%d)(月更版)"
BUILD_STRING=${BUILD_STRING:-$YUOS_DATE}
echo "Write build date in openwrt : $BUILD_STRING"
echo -e '\n 小渔学长 Build @ '${BUILD_STRING}'\n' >> package/base-files/files/etc/banner

# 清理并重新写入 openwrt_release 的核心变量（给 LuCI 网页读取的）
sed -i '/DISTRIB_REVISION/d' package/base-files/files/etc/openwrt_release
echo "DISTRIB_REVISION=''" >> package/base-files/files/etc/openwrt_release

sed -i '/DISTRIB_DESCRIPTION/d' package/base-files/files/etc/openwrt_release
echo "DISTRIB_DESCRIPTION='小渔学长 Build @ ${BUILD_STRING}'" >> package/base-files/files/etc/openwrt_release

# 修改 luci version.lua
sed -i '/luciversion/d' feeds/luci/modules/luci-base/luasrc/version.lua
echo "luciversion = '${BUILD_STRING}'" >> feeds/luci/modules/luci-base/luasrc/version.lua


#升级golang
rm -rf feeds/packages/lang/golang
find . -type d -name "golang" -prune -exec rm -rf {} \;
git clone https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# ===== 升级 dnsmasq 2.85 -> 2.87 添加 nftset 支持 =====
# 说明：21.02 的 dnsmasq 2.85 不支持 nftset。用本地 patchs 目录中的 2.87 版本替换 feeds 中的 2.85
# Makefile 已直接改为 2.87 + nftset，补丁已处理（删除 2.87 已包含的 CVE 修复，保留 kernel-support 补丁）
DNSMASQ_PATH="feeds/packages/net/dnsmasq"
if [ -d "$DNSMASQ_PATH" ] && [ -d "$GITHUB_WORKSPACE/patchs/21.02/dnsmasq" ]; then
	rm -rf "$DNSMASQ_PATH"
	cp -rf "$GITHUB_WORKSPACE/patchs/21.02/dnsmasq" "$DNSMASQ_PATH"
	echo "dnsmasq: 2.85 -> 2.87 + nftset OK"
fi
