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
sed -i 's#github.com/immortalwrt/luci.git;openwrt-24.10#github.com/immortalwrt/luci.git;openwrt-24.10#' feeds.conf.default
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;dev' feeds.conf.default
sed -i '$a src-git small8 https://github.com/kenzok8/openwrt-packages.git;master' feeds.conf.default

# 修改默认编译LUCI进系统
sed -i 's/ppp-mod-pppoe/iptables-mod-tproxy iptables-mod-extra ipset ip-full ppp-mod-pppoe curl ca-certificates/g' include/target.mk

# 设置闭源驱动开机自启
sed -i '2a ifconfig rai0 up\nifconfig ra0 up\nbrctl addif br-lan rai0\nbrctl addif br-lan ra0' package/base-files/files/etc/rc.local

# 覆盖 MTK 闭源驱动/应用包
# 说明：24.10 厂商树自带 package/mtk，这里用本仓库 patchs/24.10/mtk 整目录覆盖，
# 确保使用本仓库维护的 mt_wifi / warp / conninfra / wifi-profile / mtwifi-cfg 等版本。
# 必须放在 feeds update 之前，让后续 feeds install 与 make defconfig 能看到这些包。
MTK_PATCH_DIR="$GITHUB_WORKSPACE/patchs/24.10/mtk"
if [ -d "$MTK_PATCH_DIR" ]; then
	rm -rf package/mtk
	cp -rf "$MTK_PATCH_DIR" package/mtk
	echo "MTK packages: patchs/24.10/mtk -> package/mtk OK"
else
	echo "警告：未找到 $MTK_PATCH_DIR，将使用源码树自带的 package/mtk"
fi

# 设置shadowsocksr-libev
# sed -i 's/ +libopenssl-legacy//g' feeds/small/shadowsocksr-libev/Makefile

# 单独拉取软件包
git clone -b default-settings-24.10 https://github.com/yuos-bit/other package/default-settings
git clone -b debug https://github.com/yuos-bit/luci-theme-edge2 package/luci-theme-edge2
git clone -b passwall https://github.com/yuos-bit/other package/passwall
# 测试 tailscale
git clone -b tailscale https://github.com/yuos-bit/other package/tailscale

# 删除软件包默认设置
rm -rf package/emortal/default-settings