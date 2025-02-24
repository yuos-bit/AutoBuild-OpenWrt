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
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;master' feeds.conf.default
sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master' feeds.conf.default
sed -i '$a src-git small https://github.com/kenzok8/small.git;master' feeds.conf.default
sed -i '$a src-git small8 https://github.com/kenzok8/small-package.git;main' feeds.conf.default

# 修改默认编译LUCI进系统
sed -i 's/ppp-mod-pppoe/iptables-mod-tproxy iptables-mod-extra ipset ip-full ppp-mod-pppoe curl ca-certificates/g' include/target.mk

# 设置闭源驱动开机自启
sed -i '2a ifconfig rai0 up\nifconfig ra0 up\nbrctl addif br-lan rai0\nbrctl addif br-lan ra0' package/base-files/files/etc/rc.local

# 设置shadowsocksr-libev
# sed -i 's/ +libopenssl-legacy//g' feeds/small/shadowsocksr-libev/Makefile

# 单独拉取软件包
git clone -b Lienol-default-settings https://github.com/yuos-bit/other package/default-settings
git clone -b lua5.4 https://github.com/yuos-bit/other package/lua5.4
rm -rf package/libs/openssl
git clone -b openssl https://github.com/yuos-bit/other package/openssl
git clone -b debug https://github.com/yuos-bit/luci-theme-edge2 package/luci-theme-edge2
# 更改默认wifi
# cp -rf $GITHUB_WORKSPACE/patchs/NX30Pro/mtwifi.sh package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
