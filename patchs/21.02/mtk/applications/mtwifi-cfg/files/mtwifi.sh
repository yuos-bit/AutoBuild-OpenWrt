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

				# SSID 按驱动/设备 MAC 衍生成 Xiaomi-<MAC>（与闭源 mt_wifi 默认命名一致，
				# 例如 LAN MAC 88:c3:97:ed:c2:45 → Xiaomi-88C3；5G 加 -5G 后缀）
				if [ -n "$ifname" ]; then
					_hwaddr="$(cat /sys/class/net/${ifname}/address 2>/dev/null)"
				fi
				[ -n "$_hwaddr" ] || _hwaddr="$(cat /sys/class/net/br-lan/address 2>/dev/null)"
				_machead="$(echo "$_hwaddr" | tr -d ':' | cut -c1-4 | tr 'a-f' 'A-F')"
				[ -n "$_machead" ] || _machead="XXXX"

				if [ "$band" = "2g" ]; then
					htmode="HT40"
					htbsscoex="1"
					ssid="Xiaomi-${_machead}"
				else
					htmode="VHT80"
					htbsscoex="0"
					ssid="Xiaomi-${_machead}-5G"
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
