# #!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
# 增加软件包
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;master' feeds.conf.default
sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master' feeds.conf.default
sed -i '$a src-git small https://github.com/kenzok8/small.git;master' feeds.conf.default
sed -i '$a src-git small8 https://github.com/kenzok8/small-package.git;main' feeds.conf.default
# 单独拉取软件包
rm -rf package/default-settings
git clone -b default-settings-19.07 https://github.com/yuos-bit/other package/19.07
git clone -b main --single-branch https://github.com/yuos-bit/other package/yuos
# 覆盖源码
cp -rf $GITHUB_WORKSPACE/patchs/4.14/dts/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/
cp -rf $GITHUB_WORKSPACE/patchs/4.14/mt76x8/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/
cp -rf $GITHUB_WORKSPACE/patchs/4.14/mt7621/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/
cp -rf $GITHUB_WORKSPACE/patchs/4.14/board.d/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/base-files/etc/board.d/
cp -rf $GITHUB_WORKSPACE/patchs/4.14/wifi/mac80211.sh $GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/files/lib/wifi/mac80211.sh