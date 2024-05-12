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
#
## 复制小米路由配置文件到编译目录
## 复制小米路由配置文件到编译目录
# MT7628
## 删除默认文件
rm -rf $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7628an_xiaomi_miwifi-3c.dts
rm -rf $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7628an_xiaomi_mi-router-4c.dts
# MT7628
cp -R $GITHUB_WORKSPACE/patchs/ruijie/mt7628an_xiaomi_mi-router-4c.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7628an_xiaomi_mi-router-4c.dts
cp -R $GITHUB_WORKSPACE/patchs/ruijie/mt7628an_xiaomi_mi-router-3c.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7628an_xiaomi_mi-router-3c.dts
cp -R $GITHUB_WORKSPACE/patchs/ruijie/mt7628an_xiaomi_mi-router-3a.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7628an_xiaomi_mi-router-3a.dts
cp -R $GITHUB_WORKSPACE/patchs/ruijie/mt76x8/mt76x8.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt76x8.mk
cp -R $GITHUB_WORKSPACE/patchs/ruijie/mt76x8/02_network $GITHUB_WORKSPACE/openwrt/target/linux/ramips/mt76x8/base-files/etc/board.d/02_network
cp -R $GITHUB_WORKSPACE/patchs/ruijie/mt76x8/mac80211.sh $GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/files/lib/wifi/mac80211.sh
# MT7620
cp -R $GITHUB_WORKSPACE/patchs/ruijie/mt7620a_xiaomi_mi-router-3x.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7620a_xiaomi_mi-router-3x.dts
cp -R $GITHUB_WORKSPACE/patchs/ruijie/mt7620/mt7620.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt7620.mk
cp -R $GITHUB_WORKSPACE/patchs/ruijie/mt7620/02_network $GITHUB_WORKSPACE/openwrt/target/linux/ramips/mt7620/base-files/etc/board.d/02_network
cp -R $GITHUB_WORKSPACE/patchs/ruijie/mt7620/mac80211.sh $GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/files/lib/wifi/mac80211.sh

# 修改软件包版本为大杂烩-openwrt22.03
sed -i 's/git.openwrt.org\/feed\/packages.git;openwrt-22.03/github.com\/coolsnowwolf\/packages.git;master/g' feeds.conf.default
sed -i 's/git.openwrt.org\/project\/luci.git;openwrt-22.03/github.com\/coolsnowwolf\/luci.git;master/g' feeds.conf.default

# 增加软件包
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;master' feeds.conf.default
sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master' feeds.conf.default
sed -i '$a src-git small https://github.com/kenzok8/small.git;master' feeds.conf.default
sed -i '$a src-git small8 https://github.com/kenzok8/small-package.git;main' feeds.conf.default

# 修改默认第一排插件
sed -i 's/dnsmasq/dnsmasq-full/g' include/target.mk

# # 修改默认第二排插件
sed -i 's/firewall4/firewall block-mount coremark kmod-nf-nathelper kmod-nf-nathelper-extra kmod-ipt-raw kmod-tun/g' include/target.mk

# # 修改默认第三排插件
sed -i 's/nftables/nftables iptables-mod-tproxy/g' include/target.mk

# # 修改默认第四排插件
sed -i 's/kmod-nft-offload/kmod-nft-offload curl ca-certificates/g' include/target.mk

# # 修改默认第五排插件
sed -i 's/odhcp6c/odhcp6c iptables-mod-tproxy iptables-mod-extra/g' include/target.mk

# # 修改默认第六排插件
sed -i 's/odhcpd-ipv6only/odhcpd-ipv6only ipset ip-full default-settings luci/g' include/target.mk

# 单独拉取 default-settings
git clone -b ruijie https://github.com/yuos-bit/other package/yuos

# 单独拉取 lean包到package 目录
git clone -b main https://github.com/yuos-bit/other package/lean

# 设置闭源驱动开机自启
# sed -i '2a ifconfig rai0 up\nifconfig ra0 up\nbrctl addif br-lan rai0\nbrctl addif br-lan ra0' package/base-files/files/etc/rc.local

##补充包##

## 锐捷校园网
git clone -b master https://github.com/Zxilly/UA2F package/yuos/UA2F
# 防检测
git clone -b master https://github.com/CHN-beta/rkp-ipid package/yuos/rkp-ipid
# 防检测
git clone -b main https://github.com/lucikap/Brukamen package/yuos/Brukamen
# 防检测
git clone -b main https://github.com/a76yyyy/HustWebAuth package/yuos/HustWebAuth
# 网页认证\
git clone -b master https://github.com/muink/openwrt-rgmac package/yuos/rgmac
git clone -b master https://github.com/muink/luci-app-change-mac package/yuos/luci-app-change-mac
# 修改mac地址
git clone -b master https://github.com/chenhaowen01/gdut-drcom-for-openwrt package/yuos/drcom
# 拉取哆点

## 其他补丁
# git clone -b master https://github.com/CHN-beta/xmurp-ua package/yuos/xmurp-ua
# 使用 XMURP-UA 修改 UA
# 设置开机自启加入防火墙 针对基于 IPv4 数据包包头内的 TTL 字段的检测的解决方案
sed -i '3a iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53' package/base-files/files/etc/rc.local
sed -i '4a iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53' package/base-files/files/etc/rc.local
sed -i '6a # 防 IPID 检测' package/base-files/files/etc/rc.local
sed -i '7a iptables -t mangle -N IPID_MOD' package/base-files/files/etc/rc.local
sed -i '8a iptables -t mangle -A FORWARD -j IPID_MOD' package/base-files/files/etc/rc.local
sed -i '9a iptables -t mangle -A OUTPUT -j IPID_MOD' package/base-files/files/etc/rc.local
sed -i '10a iptables -t mangle -A IPID_MOD -d 0.0.0.0/8 -j RETURN' package/base-files/files/etc/rc.local
sed -i '11a iptables -t mangle -A IPID_MOD -d 127.0.0.0/8 -j RETURN' package/base-files/files/etc/rc.local
sed -i '12a # 由于本校局域网是 A 类网，所以我将这一条注释掉了，具体要不要注释结合你所在的校园网内网类型' package/base-files/files/etc/rc.local
sed -i '13a #iptables -t mangle -A IPID_MOD -d 10.0.0.0/8 -j RETURN' package/base-files/files/etc/rc.local
sed -i '14a iptables -t mangle -A IPID_MOD -d 172.16.0.0/12 -j RETURN' package/base-files/files/etc/rc.local
sed -i '15a iptables -t mangle -A IPID_MOD -d 192.168.0.0/16 -j RETURN' package/base-files/files/etc/rc.local
sed -i '16a iptables -t mangle -A IPID_MOD -d 255.0.0.0/8 -j RETURN' package/base-files/files/etc/rc.local
sed -i '17a iptables -t mangle -A IPID_MOD -j MARK --set-xmark 0x10/0x10' package/base-files/files/etc/rc.local
sed -i '18a # 防时钟偏移检测' package/base-files/files/etc/rc.local
sed -i '19a iptables -t nat -N ntp_force_local' package/base-files/files/etc/rc.local
sed -i '20a iptables -t nat -I PREROUTING -p udp --dport 123 -j ntp_force_local' package/base-files/files/etc/rc.local
sed -i '21a iptables -t nat -A ntp_force_local -d 0.0.0.0/8 -j RETURN' package/base-files/files/etc/rc.local
sed -i '22a iptables -t nat -A ntp_force_local -d 127.0.0.0/8 -j RETURN' package/base-files/files/etc/rc.local
sed -i '23a iptables -t nat -A ntp_force_local -d 192.168.0.0/16 -j RETURN' package/base-files/files/etc/rc.local
sed -i '24a iptables -t nat -A ntp_force_local -s 192.168.0.0/16 -j DNAT --to-destination 192.168.1.1' package/base-files/files/etc/rc.local
sed -i '25a # 通过 iptables 修改 TTL 值' package/base-files/files/etc/rc.local
sed -i '26a iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64' package/base-files/files/etc/rc.local
## 其他补丁
