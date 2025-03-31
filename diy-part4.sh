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
#
# 复制小米路由配置文件到编译目录
cp -rf $GITHUB_WORKSPACE/patchs/4.14/dts/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/
cp -rf $GITHUB_WORKSPACE/patchs/4.14/mt76x8/mt76x8.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt76x8.mk
cp -rf $GITHUB_WORKSPACE/patchs/4.14/mt7621/mt7621.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt7621.mk
cp -rf $GITHUB_WORKSPACE/patchs/4.14/public/01_leds $GITHUB_WORKSPACE/openwrt/target/linux/ramips/base-files/etc/board.d/01_leds
cp -rf $GITHUB_WORKSPACE/patchs/4.14/public/02_network $GITHUB_WORKSPACE/openwrt/target/linux/ramips/base-files/etc/board.d/02_network

# 增加软件包
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;master' feeds.conf.default
sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master' feeds.conf.default
sed -i '$a src-git small https://github.com/kenzok8/small.git;master' feeds.conf.default
sed -i '$a src-git small8 https://github.com/kenzok8/small-package.git;main' feeds.conf.default
# 单独拉取软件包
git clone -b 19.07 https://github.com/yuos-bit/other package/19.07
git clone -b main --single-branch https://github.com/yuos-bit/other package/yuos