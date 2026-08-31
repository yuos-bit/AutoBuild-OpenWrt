#!/bin/sh
#
# Copyright (C) 2023, hanwckf <hanwckf@vip.qq.com>
#

append DRIVERS "mtwifi"

detect_mtwifi() {
	local idx ifname chip
	local band htmode htbsscoex ssid dbdc_main
	# mt7621 loads mt7603e/mt76x2_ap/mt_wifi; mt798x loads mt_wifi only
	if [ -d "/sys/module/mt_wifi" ] || [ -d "/sys/module/mt7603e" ] || [ -d "/sys/module/mt76x2_ap" ]; then
		dev_list="$(l1util list)"
		for dev in $dev_list; do
			config_get type ${dev} type
			[ "$type" = "mtwifi" ] || {
				ifname="$(l1util get ${dev} main_ifname)"
				chip="$(l1util get ${dev} INDEX)"

				idx="$(l1util get ${dev} subidx)"
				[ $idx -eq 1 ] && dbdc_main="1" || dbdc_main="0"

				band="$(l1util get ${dev} band)"
				if [ -z "$band" ] || [ "$band" = "nil" ]; then
					case "$chip" in
						MT7603) band="2g" ;;
						MT7612) band="5g" ;;
						*) [ $idx -eq 1 ] && band="2g" || band="5g" ;;
					esac
				fi

				# SSID 生成：Xiaoyu_<MAC4>_2.4G / Xiaoyu_<MAC4>_5G（与固件整体命名方案一致）。
				# 注意：raX 在驱动 EEPROM 初始化完成前 MAC 可能为全零，hotplug 触发的
				# detect 很早，因此优先用以太网口 MAC（eth0，来自 factory 分区，最稳定），
				# 全零时逐级回退 raX → br-lan，仍全零则用 XXXX。
				_hwaddr="$(cat /sys/class/net/eth0/address 2>/dev/null)"
				case "$_hwaddr" in
					""|"00:00:00:00:00:00")
						[ -n "$ifname" ] && _hwaddr="$(cat /sys/class/net/${ifname}/address 2>/dev/null)"
						;;
				esac
				case "$_hwaddr" in
					""|"00:00:00:00:00:00")
						_hwaddr="$(cat /sys/class/net/br-lan/address 2>/dev/null)"
						;;
				esac
				case "$_hwaddr" in
					""|"00:00:00:00:00:00") _hwaddr="" ;;
				esac
				_machead="$(echo "$_hwaddr" | awk -F: '{print toupper($1 $2)}')"
				[ -n "$_machead" ] || _machead="XXXX"

				if [ "$band" = "2g" ]; then
					htmode="HT40"
					htbsscoex="1"
					ssid="Xiaoyu_${_machead}_2.4G"
				else
					htmode="VHT80"
					htbsscoex="0"
					ssid="Xiaoyu_${_machead}_5G"
				fi

				uci -q batch <<-EOF
					set wireless.${dev}=wifi-device
					set wireless.${dev}.type=mtwifi
					set wireless.${dev}.phy=${ifname}
					set wireless.${dev}.band=${band}
					set wireless.${dev}.dbdc_main=${dbdc_main}
					set wireless.${dev}.channel=auto
					set wireless.${dev}.txpower=100
					set wireless.${dev}.htmode=${htmode}
					set wireless.${dev}.country=CN
					set wireless.${dev}.noscan=${htbsscoex}
					set wireless.${dev}.serialize=1

					set wireless.default_${dev}=wifi-iface
					set wireless.default_${dev}.device=${dev}
					set wireless.default_${dev}.network=lan
					set wireless.default_${dev}.mode=ap
					set wireless.default_${dev}.ssid=${ssid}
					set wireless.default_${dev}.encryption=none
EOF
				uci -q commit wireless
			}
		done
	fi
}
