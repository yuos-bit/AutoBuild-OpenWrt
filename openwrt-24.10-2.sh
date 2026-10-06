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

# ===== 编译前校验 MTK 组件 =====
# 说明：feeds install 之后、make defconfig 之前做一次快速校验。
# 缺包时 make defconfig 只会静默丢弃对应 CONFIG_ 项，等到编译后期才报难以定位的错误，
# 这里提前把问题暴露出来。
MTK_REQUIRED="drivers/mt_wifi drivers/warp drivers/conninfra drivers/wifi-profile \
applications/mtwifi-cfg applications/datconf applications/luci-app-mtwifi-cfg \
applications/luci-app-turboacc-mtk applications/luci-app-eqos-mtk"

MTK_MISSING=""
for d in $MTK_REQUIRED; do
	[ -f "package/mtk/$d/Makefile" ] || MTK_MISSING="$MTK_MISSING $d"
done
if [ -n "$MTK_MISSING" ]; then
	echo "警告：package/mtk 缺少以下组件，编译将失败："
	for d in $MTK_MISSING; do echo "   - $d"; done
	echo "   请确认脚本1 中的 patchs/24.10/mtk 拷贝步骤已执行。"
else
	echo "校验通过：package/mtk 组件齐全"
fi

# kmod-mediatek_hnat 由厂商树的 package/kernel/linux/modules/netdevices.mk 提供，
# 上游 openwrt/openwrt 没有它 —— 用这个判断当前源码树是否为厂商树。
if grep -q "mediatek_hnat" package/kernel/linux/modules/netdevices.mk 2>/dev/null; then
	echo "校验通过：厂商树（含 kmod-mediatek_hnat / HNAT 硬件加速）"
else
	echo "警告：当前源码树没有 kmod-mediatek_hnat，说明不是厂商树。"
	echo "   本配置的 MTK 闭源驱动无法编译，请把 workflow 的 REPO_URL 换成带 package/mtk 的 24.10 厂商树。"
fi

# patchs 的部分包不含源码，源码靠 dl/ 里的 tarball（清单见脚本1）。
# 厂商树的 dl/ 没有这些文件，缺了会在编译阶段报难懂的 tar / failed to build，这里提前查。
MTK_DL_NEEDED="
datconf-757f9679.tar.bz2
mt79xx_conninfra_20231229-f2fa25.tar.xz
mt79xx_20231229-4012a0.tar.xz
warp_20231229-5f71ec.tar.xz
"
MTK_DL_MISSING=""
for f in $MTK_DL_NEEDED; do
	[ -s "dl/$f" ] || MTK_DL_MISSING="$MTK_DL_MISSING $f"
done
if [ -n "$MTK_DL_MISSING" ]; then
	echo "警告：dl/ 缺少以下 MTK 驱动源码包，编译将失败："
	for f in $MTK_DL_MISSING; do echo "   - $f"; done
	echo "   请确认脚本1 中的 dl 补齐步骤已执行（或源码树 dl/ 已自带）。"
else
	echo "校验通过：MTK 驱动源码包齐全"
fi