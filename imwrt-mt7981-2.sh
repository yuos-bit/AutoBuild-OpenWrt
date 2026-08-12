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
# 说明：21.02 的 dnsmasq 2.85 不支持 nftset。升级到 2.87（首个支持 nftset 的版本）
DNSMASQ_PATH="feeds/packages/net/dnsmasq"
if [ -f "$DNSMASQ_PATH/Makefile" ]; then
	# 1. 清除旧版补丁（2.85 补丁不兼容 2.87）
	rm -f "$DNSMASQ_PATH/patches/"*.patch

	# 2. 用 Python 重写 Makefile 的关键字段
	python3 << 'DNSPYEOF'
import re

path = "feeds/packages/net/dnsmasq/Makefile"
with open(path) as f:
    c = f.read()

# 升级版本
c = c.replace("PKG_UPSTREAM_VERSION:=2.85", "PKG_UPSTREAM_VERSION:=2.87")

# 更新哈希 (dnsmasq-2.87.tar.xz sha256)
c = re.sub(r"PKG_HASH:=.*", "PKG_HASH:=0228c0364a7f2356fd7e7f1549937cbf3099a78d3b2eb1ba5bb0c31e2b89de7a", c)

# 在 tftp 配置后、endif 前插入 nftset 配置项
c = c.replace(
    "\t\tdefault y\n\tendif\nendef",
    "\t\tdefault y\n\n\tconfig PACKAGE_dnsmasq_full_nftset\n"
    "\t\tbool \"Build with Nftset support.\"\n"
    "\t\tdefault y\n\tendif\nendef"
)

# 在 COPTS 中追加 -DHAVE_NFTSET 编译标志
c = c.replace(
    "$(if $(CONFIG_PACKAGE_dnsmasq_$(BUILD_VARIANT)_tftp),,-DNO_TFTP)",
    "$(if $(CONFIG_PACKAGE_dnsmasq_$(BUILD_VARIANT)_tftp),,-DNO_TFTP) \\\n"
    "\t\t$(if $(CONFIG_PACKAGE_dnsmasq_$(BUILD_VARIANT)_nftset),-DHAVE_NFTSET,)"
)

# 追加 nftables-json 运行时依赖
c = c.replace(
    "+PACKAGE_dnsmasq_full_conntrack:libnetfilter-conntrack",
    "+PACKAGE_dnsmasq_full_conntrack:libnetfilter-conntrack \\\n"
    "\t+PACKAGE_dnsmasq_full_nftset:nftables-json"
)

with open(path, "w") as f:
    f.write(c)
print("dnsmasq: 2.85 -> 2.87 + nftset OK")
DNSPYEOF
fi
