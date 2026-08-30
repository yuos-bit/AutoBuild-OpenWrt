'use strict';
'require view';
'require dom';
'require poll';
'require fs';
'require ui';
'require rpc';
'require uci';
'require form';
'require network';
'require firewall';
'require tools.widgets as widgets';

/*
 * luci-app-mtwifi-yuos - rewritten Network -> Wireless page for the
 * MediaTek closed-source mt_wifi driver stack (mtwifi-cfg backend).
 *
 * Drop-in replacement for luci-mod-network's view/network/wireless.js:
 * same require header, same view.extend() export contract, same 5s poll.
 *
 * mtwifi radios (type "mtwifi") get a dedicated dashboard, dual-band
 * status cards, per-SSID management with MAC ACL, AP-Client repeater
 * scan/join and an associated-station table with a kick action
 * (backed by the luci.mtwifi rpcd plugin + /usr/bin/mtwifi-sta).
 * Other hwtypes fall back to a generic subset of the stock options.
 */

var isReadonlyView = !L.hasViewPermission();

var callGetFeatures = rpc.declare({
	object: 'luci.mtwifi', method: 'getFeatures', expect: { '': {} }
});

var callGetStatus = rpc.declare({
	object: 'luci.mtwifi', method: 'getStatus', expect: { '': {} }
});

var callGetAssocList = rpc.declare({
	object: 'luci.mtwifi', method: 'getAssocList', expect: { '': {} }
});

var callScan = rpc.declare({
	object: 'luci.mtwifi', method: 'scan', params: [ 'device' ],
	expect: { '': {} }, timeout: 60000
});

var callKick = rpc.declare({
	object: 'luci.mtwifi', method: 'kick', params: [ 'ifname', 'mac' ],
	expect: { '': {} }
});

/* ----------------------------------------------------------------- css */

var MTW_CSS = '\
:root {\
	--mtw-accent:#0a7ec2; --mtw-ok:#2ea043; --mtw-warn:#b9770e; --mtw-danger:#d9534f;\
	--mtw-card:rgba(128,140,160,.08); --mtw-line:rgba(128,140,160,.30);\
	--mtw-muted:#5f6b7a; --mtw-bar:#ccd2da;\
}\
@media (prefers-color-scheme: dark) {\
	:root:not([data-theme=light]) {\
		--mtw-accent:#5aabdc; --mtw-ok:#46b364; --mtw-warn:#d29922; --mtw-danger:#ef6a60;\
		--mtw-card:rgba(120,140,170,.10); --mtw-line:rgba(120,140,170,.32);\
		--mtw-muted:#94a3b5; --mtw-bar:#39424e;\
	}\
}\
#mtw_dashboard .mtw-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(340px,1fr)); gap:14px; }\
.mtw-card { background:var(--mtw-card); border:1px solid var(--mtw-line); border-radius:8px; padding:14px 16px 12px; }\
.mtw-card .mtw-top { display:flex; align-items:center; gap:9px; flex-wrap:wrap; }\
.mtw-pill { font-size:12px; font-weight:700; padding:1px 9px; border-radius:20px;\
	background:rgba(10,126,194,.12); color:var(--mtw-accent); white-space:nowrap; }\
.mtw-ifname { color:var(--mtw-muted); font-size:12px; font-family:ui-monospace,Consolas,monospace; }\
.mtw-dot { width:8px; height:8px; border-radius:50%; margin-left:auto; flex:none; }\
.mtw-dot.on { background:var(--mtw-ok); box-shadow:0 0 0 3px rgba(46,160,67,.18); }\
.mtw-dot.off { background:var(--mtw-bar); }\
.mtw-state { font-size:12px; color:var(--mtw-muted); }\
.mtw-ssid { font-size:17px; font-weight:650; margin:9px 0 2px; }\
.mtw-chip { font-size:11px; font-weight:600; padding:1px 7px; border-radius:3px; white-space:nowrap;\
	border:1px solid var(--mtw-line); color:var(--mtw-muted); background:transparent; }\
.mtw-chip.sec { color:var(--mtw-ok); border-color:transparent; background:rgba(46,160,67,.12); }\
.mtw-chip.warn { color:var(--mtw-warn); border-color:transparent; background:rgba(185,119,14,.12); }\
.mtw-stats { display:grid; grid-template-columns:repeat(4,1fr); gap:8px; margin-top:10px; }\
.mtw-stats.two { grid-template-columns:repeat(2,1fr); margin-top:8px; }\
.mtw-stat { background:rgba(128,140,160,.07); border-radius:6px; padding:7px 10px; min-width:0; overflow:hidden; }\
.mtw-stat .k { font-size:11px; color:var(--mtw-muted); white-space:nowrap; }\
.mtw-stat .v { font-size:15px; font-weight:650; white-space:nowrap;\
	font-family:ui-monospace,Consolas,monospace; font-variant-numeric:tabular-nums; }\
.mtw-stat .v small { font-size:11px; font-weight:400; color:var(--mtw-muted); margin-left:2px; }\
.mtw-stat .v small.mtw-chip { font-family:system-ui,sans-serif; }\
.mtw-rep-up { color:var(--mtw-ok); }\
.mtw-rep-down { color:var(--mtw-muted); }\
.mtw-actions { display:flex; gap:6px; margin-top:12px; flex-wrap:wrap; }\
.mtw-net { display:inline-flex; align-items:center; gap:6px; }\
.mtw-net .ifn { font-size:11px; color:var(--mtw-muted); border:1px solid var(--mtw-line);\
	border-radius:3px; padding:0 5px; font-family:ui-monospace,Consolas,monospace; }\
.mtw-host small { display:block; color:var(--mtw-muted); }\
.mtw-sig { display:inline-flex; align-items:center; gap:7px; }\
.mtw-sig svg { display:block; }\
.mtw-sig span { font-family:ui-monospace,Consolas,monospace; }\
';

var styleInjected = false;

function injectStyle() {
	if (styleInjected || document.getElementById('mtw-style'))
		return;

	document.head.appendChild(E('style', { 'id': 'mtw-style', 'type': 'text/css' }, [ MTW_CSS ]));
	styleInjected = true;
}

/* ----------------------------------------------------------- constants */

var MTW_ENCRYPTIONS = [
	['none',      _('No Encryption (open network)')],
	['psk2',      'WPA2-PSK'],
	['psk-mixed', 'WPA-PSK/WPA2-PSK Mixed Mode'],
	['sae',       'WPA3-SAE'],
	['sae-mixed', 'WPA2-PSK/WPA3-SAE Mixed Mode'],
	['psk',       'WPA-PSK'],
	['owe',       'OWE (Enhanced Open)']
];

var MTW_COUNTRY_CODES = {
	DB: 'Debug', AE: 'U.A.E.', AL: 'Albania', AR: 'Argentina', AT: 'Austria',
	AM: 'Armenia', AU: 'Australia', AZ: 'Azerbaijan', BE: 'Belgium',
	BH: 'Bahrain', BY: 'Belarus', BO: 'Bolivia', BR: 'Brazil', BN: 'Brunei',
	BG: 'Bulgaria', BZ: 'Belize', CA: 'Canada', CH: 'Switzerland',
	CL: 'Chile', CN: 'China', CO: 'Colombia', CR: 'Costa Rica',
	CY: 'Cyprus', CZ: 'Czech Republic', DE: 'Germany', DK: 'Denmark',
	DO: 'Dominican Republic', DZ: 'Algeria', EC: 'Ecuador', EG: 'Egypt',
	EE: 'Estonia', ES: 'Spain', FI: 'Finland', FR: 'France',
	GE: 'Georgia', GB: 'United Kingdom', GR: 'Greece', GT: 'Guatemala',
	HN: 'Honduras', HK: 'Hong Kong', HU: 'Hungary', HR: 'Croatia',
	IS: 'Iceland', IN: 'India', ID: 'Indonesia', IR: 'Iran', IE: 'Ireland',
	IL: 'Israel', IT: 'Italy', JP: 'Japan', JO: 'Jordan', KP: 'N. Korea',
	KR: 'S. Korea', KW: 'Kuwait', KZ: 'Kazakhstan', LB: 'Lebanon',
	LI: 'Liechtenstein', LT: 'Lithuania', LU: 'Luxembourg', LV: 'Latvia',
	MA: 'Morocco', MC: 'Monaco', MO: 'Macao', MK: 'Macedonia', MX: 'Mexico',
	MY: 'Malaysia', NL: 'Netherlands', NO: 'Norway', NZ: 'New Zealand',
	OM: 'Oman', PA: 'Panama', PE: 'Peru', PH: 'Philippines', PL: 'Poland',
	PK: 'Pakistan', PT: 'Portugal', PR: 'Puerto Rico', QA: 'Qatar',
	RO: 'Romania', RU: 'Russia', SA: 'Saudi Arabia', SG: 'Singapore',
	SK: 'Slovakia', SI: 'Slovenia', SV: 'El Salvador', SE: 'Sweden',
	SY: 'Syria', TH: 'Thailand', TN: 'Tunisia', TR: 'Turkey',
	TT: 'Trinidad & Tobago', TW: 'Taiwan', UA: 'Ukraine', US: 'United States',
	UY: 'Uruguay', UZ: 'Uzbekistan', VE: 'Venezuela', VN: 'Vietnam',
	YE: 'Yemen', ZA: 'South Africa', ZW: 'Zimbabwe'
};

var MTW_CHANNELS_2G = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
var MTW_CHANNELS_5G = [36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112, 116, 132, 136, 140, 149, 153, 157, 161, 165];
var MTW_HTMODES_2G = [['HT20', '20 MHz'], ['HT40', '40 MHz']];
var MTW_HTMODES_5G = [['VHT20', '20 MHz'], ['VHT40', '40 MHz'], ['VHT80', '80 MHz']];

/* ------------------------------------------------------------- helpers */

function count_changes(section_id) {
	var changes = ui.changes.changes, n = 0;

	if (!L.isObject(changes))
		return n;

	if (Array.isArray(changes.wireless))
		for (var i = 0; i < changes.wireless.length; i++)
			n += (changes.wireless[i][1] == section_id);

	return n;
}

function next_free_sid(offset) {
	var sid = 'wifinet' + offset;

	while (uci.get('wireless', sid))
		sid = 'wifinet' + (++offset);

	return sid;
}

function add_dependency_permutations(o, deps) {
	var res = null;

	for (var key in deps) {
		if (!deps.hasOwnProperty(key) || !Array.isArray(deps[key]))
			continue;

		var list = deps[key],
		    tmp = [];

		for (var j = 0; j < list.length; j++) {
			for (var k = 0; k < (res ? res.length : 1); k++) {
				var item = (res ? Object.assign({}, res[k]) : {});
				item[key] = list[j];
				tmp.push(item);
			}
		}

		res = tmp;
	}

	for (var i = 0; i < (res ? res.length : 0); i++)
		o.depends(res[i]);
}

function get_band(device_section) {
	return uci.get('wireless', device_section, 'band') || '2g';
}

function format_uptime(sec) {
	if (sec == null || isNaN(sec) || sec <= 0)
		return '-';

	var d = Math.floor(sec / 86400),
	    h = Math.floor((sec % 86400) / 3600),
	    m = Math.floor((sec % 3600) / 60);

	if (d > 0)
		return '%dd %dh'.format(d, h);
	else if (h > 0)
		return '%dh %dm'.format(h, m);

	return '%dm'.format(m);
}

function signal_bars(dbm) {
	var bars = 0;

	if (dbm == null || isNaN(dbm))
		bars = 0;
	else if (dbm >= -50)
		bars = 4;
	else if (dbm >= -60)
		bars = 3;
	else if (dbm >= -67)
		bars = 2;
	else if (dbm >= -75)
		bars = 1;

	var fill = (bars >= 2) ? 'var(--mtw-ok)'
		: (bars == 1) ? 'var(--mtw-warn)'
		: 'var(--mtw-bar)';

	var heights = [5, 8, 11, 14], rects = [];

	for (var i = 0; i < 4; i++)
		rects.push(E('rect', {
			'x': i * 5, 'y': 14 - heights[i], 'width': 3, 'height': heights[i],
			'rx': 1, 'fill': (i < bars) ? fill : 'var(--mtw-bar)'
		}));

	return E('span', { 'class': 'mtw-sig' }, [
		E('svg', { 'width': 20, 'height': 14, 'viewBox': '0 0 20 14' }, rects),
		E('span', {}, (dbm != null && !isNaN(dbm)) ? '%d %s'.format(dbm, _('dBm')) : '-')
	]);
}

function format_client_rate(e, dir) {
	/* 2.4G entries from mtwifi-sta: flat mode/mcs/bw/sgi fields */
	if (e.mode) {
		var s = (e[dir + '_kbits'] > 0) ? '%.1f %s'.format(e[dir + '_kbits'] / 1000, _('Mbit/s')) : '-';

		if (e.mode == 'HT' && e.mcs != null)
			s += ', MCS %d'.format(e.mcs);
		else if (e.mode == 'CCK' || e.mode == 'OFDM')
			s += ', %s'.format(e.mode);

		if (e.mode == 'HT') {
			if (e.bw)
				s += ', 40 %s'.format(_('MHz'));
			if (e.sgi)
				s += ', ' + _('Short GI').replace(/ /g, ' ');
		}

		return s;
	}

	/* 5G entries from iwinfo: nested rx/tx objects */
	var r = e[dir];

	if (!r || !r.rate)
		return '-';

	var s = '%.1f %s, %d %s'.format(r.rate / 1000, _('Mbit/s'), r.mhz || 0, _('MHz'));

	if (r.vht) {
		s += ', VHT-MCS %d'.format(r.mcs);
		if (r.nss) s += ', VHT-NSS %d'.format(r.nss);
	}
	else if (r.ht) {
		s += ', MCS %s'.format(r.mcs);
		if (r.nss) s += ', NSS %d'.format(r.nss);
	}

	if (r.short_gi)
		s += ', ' + _('Short GI').replace(/ /g, ' ');

	return s;
}

function wifi_svg(color) {
	return E('svg', {
		'width': 18, 'height': 18, 'viewBox': '0 0 24 24',
		'fill': 'none', 'stroke': color, 'stroke-width': 2, 'stroke-linecap': 'round'
	}, [
		E('path', { 'd': 'M5 12.55a11 11 0 0 1 14.08 0' }),
		E('path', { 'd': 'M8.53 16.11a6 6 0 0 1 6.95 0' }),
		E('circle', { 'cx': 12, 'cy': 20, 'r': 1, 'fill': color, 'stroke': 'none' })
	]);
}

/* scan rows carry a 0-100 signal quality percent, not a dBm value */
function signal_bars_pct(pct) {
	var bars = (pct >= 70) ? 4 : (pct >= 50) ? 3 : (pct >= 30) ? 2 : (pct > 0) ? 1 : 0,
	    heights = [5, 8, 11, 14], rects = [];

	for (var i = 0; i < 4; i++)
		rects.push(E('rect', {
			'x': i * 5, 'y': 14 - heights[i], 'width': 3, 'height': heights[i],
			'rx': 1, 'fill': (i < bars) ? 'var(--mtw-accent)' : 'var(--mtw-bar)'
		}));

	return E('span', { 'class': 'mtw-sig' }, [
		E('svg', { 'width': 20, 'height': 14, 'viewBox': '0 0 20 14' }, rects),
		E('span', {}, (pct != null && !isNaN(pct)) ? '%d%%'.format(pct) : '-')
	]);
}

function band_label(band) {
	return (band == '5g') ? '5 GHz' : (band == '6g') ? '6 GHz' : '2.4 GHz';
}

function encryption_label(v) {
	for (var i = 0; i < MTW_ENCRYPTIONS.length; i++)
		if (MTW_ENCRYPTIONS[i][0] == v)
			return MTW_ENCRYPTIONS[i][1];

	return v || '-';
}

function network_updown(id, map, ev) {
	var radio = uci.get('wireless', id, 'device'),
	    disabled = (uci.get('wireless', id, 'disabled') == '1') ||
	               (uci.get('wireless', radio, 'disabled') == '1');

	if (disabled) {
		uci.unset('wireless', id, 'disabled');
		uci.unset('wireless', radio, 'disabled');
	}
	else {
		uci.set('wireless', id, 'disabled', '1');

		var all_networks_disabled = true,
		    wifi_ifaces = uci.sections('wireless', 'wifi-iface');

		for (var i = 0; i < wifi_ifaces.length; i++) {
			if (wifi_ifaces[i].device == radio && wifi_ifaces[i].disabled != '1') {
				all_networks_disabled = false;
				break;
			}
		}

		if (all_networks_disabled)
			uci.set('wireless', radio, 'disabled', '1');
	}

	return map.save().then(function() {
		ui.changes.apply()
	});
}

/* ------------------------------------------------------- radio restart */

function mark_radio_restart(view, section_id) {
	var row = document.querySelector('.cbi-section-table-row[data-sid="%s"]'.format(section_id)),
	    dsc = row ? row.querySelector('[data-name="_stat"] > div') : null;

	if (dsc) {
		dsc.setAttribute('restart', '');
		dom.content(dsc, E('em', _('Device is restarting…')));
	}
}

/* ------------------------------------------------------------ the view */

return view.extend({
	poll_status: function(map, data) {
		var hosts = data[0],
		    status = data[1] || {},
		    assoc = (data[2] && data[2].list) || [];

		/* ------------------------------------------------ dashboard */
		var dash = document.getElementById('mtw_dashboard_content');

		if (dash) {
			var cards = [],
			    radios = this.mtw_radios || {};

			if (!this.mtw_ok) {
				cards.push(E('div', { 'class': 'mtw-card' },
					E('em', _('mtwifi status backend (luci.mtwifi) is not available - is mtwifi-cfg installed?'))));
			}
			else {
				for (var name in radios) {
					var f = radios[name],
					    st = status[name] || {},
					    firstSsid = null, firstEnc = null, hidden = false,
					    ifaces = uci.sections('wireless', 'wifi-iface');

					for (var i = 0; i < ifaces.length; i++) {
						if (ifaces[i].device == name && ifaces[i].mode != 'sta') {
							firstSsid = ifaces[i].ssid || '?';
							firstEnc = ifaces[i].encryption || 'none';
							hidden = (ifaces[i].hidden == '1');
							break;
						}
					}

					var up = !!st.up && uci.get('wireless', name, 'disabled') != '1',
					    chips = [];

					if (firstEnc && firstEnc != 'none')
						chips.push(E('span', { 'class': 'mtw-chip sec' }, encryption_label(firstEnc).split('/')[0]));
					else
						chips.push(E('span', { 'class': 'mtw-chip warn' }, _('open network')));

					if (hidden)
						chips.push(E('span', { 'class': 'mtw-chip' }, _('hidden')));

					var stats = [
						E('div', { 'class': 'mtw-stat' }, [
							E('div', { 'class': 'k' }, _('Channel')),
							E('div', { 'class': 'v' }, [
								st.channel || '?',
								E('small', {}, uci.get('wireless', name, 'htmode') || '')
							])
						]),
						E('div', { 'class': 'mtw-stat' }, [
							E('div', { 'class': 'k' }, _('Bitrate')),
							E('div', { 'class': 'v' }, [
								st.bitrate ? '%.1f'.format(st.bitrate) : '?',
								E('small', {}, _('Mbit/s'))
							])
						]),
						E('div', { 'class': 'mtw-stat' }, [
							E('div', { 'class': 'k' }, _('Tx-Power')),
							E('div', { 'class': 'v' }, [
								st.txpower != null ? st.txpower : '?',
								E('small', {}, _('dBm'))
							])
						]),
						E('div', { 'class': 'mtw-stat' }, [
							E('div', { 'class': 'k' }, _('Associated Stations')),
							E('div', { 'class': 'v' }, [
								st.clients != null ? st.clients : '?',
								E('small', {}, _('devices'))
							])
						])
					];

					var extra = [];

					if (f.apcli)
						extra.push(E('div', { 'class': 'mtw-stat' }, [
							E('div', { 'class': 'k' }, _('Repeater (%s)').format(f.apcli)),
							E('div', { 'class': 'v ' + ((st.apcli && st.apcli.assoc) ? 'mtw-rep-up' : 'mtw-rep-down'),
								'style': 'font-size:13px;font-family:system-ui' },
								(st.apcli && st.apcli.assoc) ? _('connected') : _('inactive'))
						]));

					cards.push(E('div', { 'class': 'mtw-card' }, [
						E('div', { 'class': 'mtw-top' }, [
							E('span', { 'class': 'mtw-pill' }, band_label(f.band)),
							E('span', { 'class': 'mtw-ifname' }, '%s · %s'.format(f.phy, name)),
							E('span', { 'class': 'mtw-dot ' + (up ? 'on' : 'off') }),
							E('span', { 'class': 'mtw-state' }, up ? _('running') : _('disabled'))
						]),
						E('div', { 'class': 'mtw-ssid' }, [ firstSsid || '?', ' ', chips ]),
						E('div', { 'class': 'mtw-stats' }, stats),
						extra.length ? E('div', { 'class': 'mtw-stats two' }, extra) : E([]),
						E('div', { 'class': 'mtw-actions' },
							E('button', {
								'class': 'cbi-button cbi-button-neutral',
								'click': ui.createHandlerFn(this, 'handleRestartRadio', name)
							}, _('Restart')))
					]));
				}
			}

			dom.content(dash, E('div', { 'class': 'mtw-grid' }, cards));
		}

		/* ------------------------------------------- device row cells */
		for (var name in (this.mtw_radios || {})) {
			var row = document.querySelector('.cbi-section-table-row[data-sid="%s"]'.format(name)),
			    cell = row ? row.querySelector('[data-name="_stat"] > div') : null;

			if (!cell || cell.hasAttribute('restart'))
				continue;

			var f = this.mtw_radios[name],
			    st = status[name] || {},
			    disabled = (uci.get('wireless', name, 'disabled') == '1'),
			    up = !!st.up && !disabled,
			    statline;

			if (up)
				statline = '%s %s · %s %.1f %s · %s %d'.format(
					_('Channel'), (st.channel || '?') + ' ' + (uci.get('wireless', name, 'htmode') || ''),
					_('Bitrate'), st.bitrate || 0, _('Mbit/s'),
					_('Clients'), st.clients || 0);

			dom.content(cell, [
				E('strong', {}, '%s '.format(name)),
				E('span', { 'class': 'mtw-chip' }, band_label(f.band)),
				disabled ? E('span', { 'class': 'mtw-chip warn' }, _('disabled')) : E([]),
				E('div', {}, up ? statline : E('em', {}, _('Device is not active')))
			]);
		}

		/* ---------------------------------------------- assoc table */
		var table = document.querySelector('#wifi_assoclist_table');

		if (table) {
			var trows = [];

			for (var i = 0; i < assoc.length; i++) {
				var e = assoc[i],
				    mac = e.mac || '?',
				    hint = hosts ? hosts.getHostnameByMACAddr(mac) : null,
				    ipv4 = hosts ? hosts.getIPAddrByMACAddr(mac) : null,
				    ipv6 = hosts ? hosts.getIP6AddrByMACAddr(mac) : null,
				    host;

				if (hint && (ipv4 || ipv6))
					host = E('span', { 'class': 'mtw-host' }, [
						hint,
						E('small', {}, '%s · %s'.format(mac, ipv4 || ipv6))
					]);
				else if (hint)
					host = E('span', { 'class': 'mtw-host' }, [ hint, E('small', {}, mac) ]);
				else
					host = E('span', { 'class': 'mtw-host' }, [ mac,
						ipv4 ? E('small', {}, ipv4) : E([]) ]);

				trows.push([
					E('span', { 'class': 'mtw-net' }, [
						e.ssid || '?',
						E('span', { 'class': 'ifn' }, e.ifname || '')
					]),
					host,
					signal_bars(e.signal),
					E('span', {}, [
						E('span', {}, format_client_rate(e, 'rx')),
						E('br'),
						E('span', {}, format_client_rate(e, 'tx'))
					]),
					format_uptime(e.uptime),
					E('button', {
						'class': 'cbi-button cbi-button-remove',
						'click': ui.createHandlerFn(this, 'handleKick', e.ifname, mac),
						'disabled': isReadonlyView || null
					}, [ _('Kick') ])
				]);
			}

			cbi_update_table(table, trows,
				E('em', {}, this.mtw_ok ? _('No clients associated') : _('No information available')));
		}

		/* ------------------------------------------------- restarts */
		var section_ids = this.dev_section ? this.dev_section.cfgsections() : [],
		    tasks = [];

		for (var i = 0; i < section_ids.length; i++) {
			var row = document.querySelector('.cbi-section-table-row[data-sid="%s"]'.format(section_ids[i])),
			    dsc = row ? row.querySelector('[data-name="_stat"] > div') : null;

			if (dsc && dsc.getAttribute('restart') == '') {
				dsc.setAttribute('restart', '1');
				tasks.push(fs.exec('/sbin/wifi', ['up', section_ids[i]]).catch(function(e) {
					ui.addNotification(null, E('p', e.message));
				}));
			}
			else if (dsc && dsc.getAttribute('restart') == '1') {
				dsc.removeAttribute('restart');
				var btn = row.querySelector('.mtw-actions button, .cbi-section-actions button');
				if (btn) {
					btn.classList.remove('spinning');
					btn.disabled = false;
				}
			}
		}

		return Promise.resolve();
	},

	load: function() {
		return Promise.all([
			uci.changes(),
			uci.load('wireless'),
			callGetFeatures().then(L.bind(function(rv) {
				this.mtw_radios = (rv && rv.radios) || {};
				this.mtw_ok = !!(rv && rv.mtwifi);
			}, this)).catch(L.bind(function() {
				this.mtw_radios = {};
				this.mtw_ok = false;
			}, this))
		]);
	},

	checkAnonymousSections: function() {
		var wifiIfaces = uci.sections('wireless', 'wifi-iface');

		for (var i = 0; i < wifiIfaces.length; i++)
			if (wifiIfaces[i]['.anonymous'])
				return true;

		return false;
	},

	callUciRename: rpc.declare({
		object: 'uci',
		method: 'rename',
		params: [ 'config', 'section', 'name' ]
	}),

	handleRestartRadio: function(section_id, ev) {
		mark_radio_restart(this, section_id);
	},

	handleKick: function(ifname, mac, ev) {
		var btn = ev.currentTarget;

		btn.classList.add('spinning');
		btn.disabled = true;
		btn.blur();

		return callKick(ifname, mac).then(L.bind(function(res) {
			if (!res || res.ok === false)
				ui.addNotification(null, E('p', _('Failed to disconnect the client') +
					((res && res.error) ? (': ' + res.error) : '')));

			btn.classList.remove('spinning');
			btn.disabled = isReadonlyView;
		}, this)).catch(L.bind(function(e) {
			ui.addNotification(null, E('p', e.message));
			btn.classList.remove('spinning');
			btn.disabled = isReadonlyView;
		}, this));
	},

	/* scan the given radio's apcli interface and show a join modal */
	handleRepeaterScan: function(section_id, ev) {
		var self = this,
		    devName = section_id,
		    feat = (this.mtw_radios || {})[devName];

		if (!feat || !feat.apcli) {
			ui.addNotification(null, E('p', _('This radio does not support AP-Client mode')));
			return;
		}

		var table = E('table', { 'class': 'table' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th col-2 middle center' }, _('Signal')),
				E('th', { 'class': 'th col-4 middle left' }, _('SSID')),
				E('th', { 'class': 'th col-2 middle center hide-xs' }, _('Channel')),
				E('th', { 'class': 'th col-2 middle left hide-xs' }, _('BSSID')),
				E('th', { 'class': 'th col-3 middle left' }, _('Encryption')),
				E('th', { 'class': 'th cbi-section-actions right' }, ' ')
			])
		]);

		cbi_update_table(table, [], E('em', { 'class': 'spinning' }, _('Wireless scan is running…')));

		var md = ui.showModal(_('Repeater Scan: %s').format(feat.apcli), [
			E('p', {}, _('Select the upstream network to connect to. The AP-Client interface will bridge it into the selected network.')),
			table,
			E('div', { 'class': 'right' },
				E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Dismiss')))
		]);

		md.style.maxWidth = '90%';
		md.style.maxHeight = 'none';

		return callScan({ device: devName }).then(function(res) {
			var list = (res && res.list) || [],
			    rows = [];

			for (var i = 0; i < list.length; i++) {
				var bss = list[i];

				rows.push([
					signal_bars_pct(bss.signal_pct),
					(bss.ssid != null) ? '%h'.format(bss.ssid) : E('em', _('hidden')),
					E('span', { 'class': 'hide-xs' }, '%d'.format(bss.ch || 0)),
					E('span', { 'class': 'hide-xs' }, '%h'.format(bss.bssid || '')),
					'%h'.format(bss.security || '?'),
					E('div', { 'class': 'right' }, E('button', {
						'class': 'cbi-button cbi-button-action important',
						'click': ui.createHandlerFn(self, 'handleRepeaterJoin', devName, bss)
					}, _('Join Network')))
				]);
			}

			cbi_update_table(table, rows,
				E('em', {}, _('No networks found - the interface may be busy or the band has no nearby APs')));
		}).catch(function(e) {
			cbi_update_table(table, [], E('em', {}, e.message || _('Scan failed')));
		});
	},

	handleRepeaterJoin: function(devName, bss, ev) {
		ui.hideModal();

		var self = this,
		    section_id = null,
		    existing_sta = null,
		    ifaces = uci.sections('wireless', 'wifi-iface');

		for (var i = 0; i < ifaces.length; i++)
			if (ifaces[i].device == devName && ifaces[i].mode == 'sta')
				existing_sta = ifaces[i]['.name'];

		return this.map.save(function() {
			/* mtwifi supports at most one sta per device: reuse it */
			if (existing_sta) {
				section_id = existing_sta;
				uci.unset('wireless', section_id, 'disabled');
			}
			else {
				var wifi_sections = uci.sections('wireless', 'wifi-iface');

				section_id = next_free_sid(wifi_sections.length);
				uci.add('wireless', 'wifi-iface', section_id);
				uci.set('wireless', section_id, 'device', devName);
				uci.set('wireless', section_id, 'mode', 'sta');
				uci.set('wireless', section_id, 'network', 'wwan');
			}

			uci.unset('wireless', devName, 'disabled');

			uci.set('wireless', section_id, 'ssid', bss.ssid || '');
			uci.set('wireless', section_id, 'bssid', bss.bssid);
			uci.set('wireless', section_id, 'encryption', bss.enc || 'psk2');

			return network.addNetwork('wwan', { proto: 'dhcp' }).then(function(net) {
				firewall.deleteNetwork(net.getName());

				return firewall.getZone('wan').then(function(zone) {
					return (zone || firewall.addZone('wan')).then(function(zone) {
						if (zone)
							zone.addNetwork(net.getName());
					});
				});
			});
		}).then(L.bind(function() {
			ui.addNotification(null, E('p', _('Client interface "%s" configured - check the WPA key below and apply.').format(section_id)));
			return this.renderMoreOptionsModal(section_id);
		}, this));
	},

	render: function() {
		if (this.checkAnonymousSections())
			return this.renderMigration();
		else
			return this.renderOverview();
	},

	handleMigration: function(ev) {
		var wifiIfaces = uci.sections('wireless', 'wifi-iface'),
		    id_offset = 0,
		    tasks = [];

		for (var i = 0; i < wifiIfaces.length; i++) {
			if (!wifiIfaces[i]['.anonymous'])
				continue;

			var new_name = next_free_sid(id_offset);

			tasks.push(this.callUciRename('wireless', wifiIfaces[i]['.name'], new_name));
			id_offset = +new_name.substring(7) + 1;
		}

		return Promise.all(tasks)
			.then(L.bind(ui.changes.init, ui.changes))
			.then(L.bind(ui.changes.apply, ui.changes));
	},

	renderMigration: function() {
		ui.showModal(_('Wireless configuration migration'), [
			E('p', _('The existing wireless configuration needs to be changed for LuCI to function properly.')),
			E('p', _('Upon pressing "Continue", anonymous "wifi-iface" sections will be assigned with a name in the form <em>wifinet#</em> and the network will be restarted to apply the updated configuration.')),
			E('div', { 'class': 'right' },
				E('button', {
					'class': 'btn cbi-button-action important',
					'click': ui.createHandlerFn(this, 'handleMigration')
				}, _('Continue')))
		]);
	},

	renderOverview: function() {
		injectStyle();

		var self = this,
		    m, s, o, s2;

		m = new form.Map('wireless');
		m.chain('network');
		m.chain('firewall');

		/* ================================================ devices */

		s = m.section(form.GridSection, 'wifi-device', _('Wireless Status'));
		s.anonymous = true;
		s.addremove = false;

		s.load = function() {
			return network.getWifiDevices().then(L.bind(function(radios) {
				this.radios = radios.sort(function(a, b) {
					return a.getName() > b.getName();
				});

				var tasks = [];

				for (var i = 0; i < radios.length; i++)
					tasks.push(radios[i].getWifiNetworks());

				return Promise.all(tasks);
			}, this)).then(L.bind(function(data) {
				this.wifis = [];

				for (var i = 0; i < data.length; i++)
					this.wifis.push.apply(this.wifis, data[i]);
			}, this));
		};

		s.cfgsections = function() {
			var rv = [];

			for (var i = 0; i < this.radios.length; i++)
				rv.push(this.radios[i].getName());

			return rv;
		};

		s.modaltitle = function(section_id) {
			return '%s (%s)'.format(section_id, band_label(get_band(section_id)));
		};

		s.renderRowActions = function(section_id) {
			var btns = [
				E('button', {
					'class': 'cbi-button cbi-button-neutral',
					'title': _('Restart radio interface'),
					'click': ui.createHandlerFn(self, 'handleRestartRadio', section_id)
				}, _('Restart')),
				E('button', {
					'class': 'cbi-button cbi-button-edit',
					'title': _('Edit this device'),
					'click': ui.createHandlerFn(this, 'renderMoreOptionsModal', section_id)
				}, _('Edit')),
				E('button', {
					'class': 'cbi-button cbi-button-add',
					'title': _('Provide new network'),
					'click': ui.createHandlerFn(self, 'handleAddIface', section_id)
				}, _('Add'))
			];

			if ((self.mtw_radios || {})[section_id] && self.mtw_radios[section_id].apcli)
				btns.push(E('button', {
					'class': 'cbi-button cbi-button-action important',
					'title': _('Scan for upstream networks and set up a repeater link'),
					'click': ui.createHandlerFn(self, 'handleRepeaterScan', section_id)
				}, _('Repeater Scan')));

			return E('td', { 'class': 'td middle cbi-section-actions' }, E('div', btns));
		};

		s.addModalOptions = function(s) {
			return network.getWifiNetwork(s.section).then(function(radioNet) {
				var hwtype = uci.get('wireless', s.section, 'type'),
				    band = get_band(s.section),
				    is_mtwifi = (hwtype == 'mtwifi'),
				    o, ss;

				o = s.option(form.SectionValue, '_device', form.NamedSection, s.section, 'wifi-device', _('Device Configuration'));
				o.modalonly = true;

				ss = o.subsection;
				ss.tab('general', _('General Setup'));
				ss.tab('advanced', _('Advanced Settings'));

				var isDisabled = (uci.get('wireless', s.section, 'disabled') == '1');

				o = ss.taboption('general', form.Button, '_toggle', isDisabled ? _('Wireless network is disabled') : _('Wireless network is enabled'));
				o.inputstyle = isDisabled ? 'apply' : 'reset';
				o.inputtitle = isDisabled ? _('Enable') : _('Disable');
				o.onclick = ui.createHandlerFn(s, network_updown, s.section, s.map);

				if (is_mtwifi) {
					o = ss.taboption('general', form.ListValue, 'channel', _('Channel'));
					o.value('auto', _('auto'));

					var chan_list = (band == '5g') ? MTW_CHANNELS_5G : MTW_CHANNELS_2G;

					for (var i = 0; i < chan_list.length; i++)
						o.value(String(chan_list[i]), '%d (%d MHz)'.format(chan_list[i],
							(band == '5g') ? (5000 + chan_list[i] * 5) : (2407 + chan_list[i] * 5)));

					o.default = 'auto';
					o.rmempty = false;

					o = ss.taboption('general', form.ListValue, 'htmode', _('Operating width'));
					var htmodes = (band == '5g') ? MTW_HTMODES_5G : MTW_HTMODES_2G;

					for (var i = 0; i < htmodes.length; i++)
						o.value(htmodes[i][0], htmodes[i][1]);

					o.rmempty = true;

					o = ss.taboption('general', form.Value, 'txpower', _('Maximum transmit power'), _('Transmit power in percent (0-100), 100 = driver default / maximum.'));
					o.datatype = 'range(0,100)';
					o.placeholder = '100';
					o.rmempty = true;

					o = ss.taboption('general', form.ListValue, 'country', _('Country Code'));
					o.default = 'CN';
					o.rmempty = false;

					for (var code in MTW_COUNTRY_CODES)
						o.value(code, MTW_COUNTRY_CODES[code]);

					o = ss.taboption('general', form.Flag, 'noscan', _('Force 40MHz mode'), _('Always use 40MHz channels even if the secondary channel overlaps. Using this option does not comply with IEEE 802.11n-2009!'));
					o.rmempty = true;

					o = ss.taboption('advanced', form.Value, 'beacon_int', _('Beacon Interval'));
					o.datatype = 'range(15,65535)';
					o.placeholder = 100;
					o.rmempty = true;

					if (band == '5g') {
						o = ss.taboption('advanced', form.Flag, 'mu_beamformer', _('MU-MIMO beamformer'));
						o.rmempty = true;
					}

					o = ss.taboption('advanced', form.Flag, 'whnat', _('Wireless hardware NAT (HWNAT)'));
					o.rmempty = true;

					o = ss.taboption('advanced', form.DummyValue, 'dbdc_main', _('DBDC main band'));
					o.cfgvalue = function() { return uci.get('wireless', s.section, 'dbdc_main') || _('auto'); };
					o.write = function() {};
				}
				else {
					/* generic (non-mtwifi) devices: minimal stock subset */
					o = ss.taboption('general', form.Value, 'channel', _('Channel'));
					o.placeholder = 'auto';

					o = ss.taboption('general', form.Value, 'htmode', _('HT mode'));
					o.placeholder = band == '5g' ? 'VHT80' : 'HT40';

					o = ss.taboption('general', form.Value, 'txpower', _('Maximum transmit power'));
					o.datatype = 'range(0,100)';

					o = ss.taboption('advanced', form.Value, 'country', _('Country Code'));
					o.datatype = 'and(uppercase,minlength(2),maxlength(2))';
				}
			});
		};

		/* device row summary cell (populated statically + by poll) */
		o = s.option(form.DummyValue, '_stat', _('Status'));
		o.modalonly = false;
		o.textvalue = function(section_id) {
			var f = (self.mtw_radios || {})[section_id],
			    disabled = (uci.get('wireless', section_id, 'disabled') == '1'),
			    nodes = [ E('strong', {}, '%s '.format(section_id)) ];

			if (f)
				nodes.push(E('span', { 'class': 'mtw-chip' }, band_label(f.band)));

			if (disabled)
				nodes.push(E('span', { 'class': 'mtw-chip warn' }, _('disabled')));

			nodes.push(E('div', {}, E('em', {}, _('Collecting data...'))));

			return E('div', { 'data-name': 'mtw-devstat' }, nodes);
		};

		this.dev_section = s;

		/* ================================================ ifaces */

		s2 = m.section(form.GridSection, 'wifi-iface', _('Wireless Networks'));
		s2.anonymous = true;
		s2.addremove = false;

		s2.cfgsections = function() {
			var rv = [],
			    order = [];

			/* order: group by device, APs first, keep uci order */
			uci.sections('wireless', 'wifi-device', function(d) { order.push(d['.name']) });

			for (var i = 0; i < order.length; i++)
				uci.sections('wireless', 'wifi-iface', function(v) {
					if (v.device == order[i])
						rv.push(v['.name']);
				});

			/* orphaned ifaces (unknown device) */
			uci.sections('wireless', 'wifi-iface', function(v) {
				if (order.indexOf(v.device) < 0 && rv.indexOf(v['.name']) < 0)
					rv.push(v['.name']);
			});

			return rv;
		};

		s2.modaltitle = function(section_id) {
			return '%s (%s)'.format(uci.get('wireless', section_id, 'ssid') || _('unnamed'), section_id);
		};

		/* iface row summary cell */
		o = s2.option(form.DummyValue, '_net', _('Network'));
		o.modalonly = false;
		o.textvalue = function(section_id) {
			var v = uci.get('wireless', section_id) || {},
			    devName = v.device,
			    f = (self.mtw_radios || {})[devName],
			    isSta = (v.mode == 'sta'),
			    disabled = (v.disabled == '1'),
			    chips = [],
			    ifname = '';

			if (f) {
				if (isSta) {
					ifname = f.apcli;
				}
				else {
					var apIdx = -1, n = 0;

					uci.sections('wireless', 'wifi-iface', function(x) {
						if (x.device == devName && (x.mode || 'ap') == 'ap') {
							if (x['.name'] == section_id)
								apIdx = n;
							n++;
						}
					});

					if (apIdx >= 0)
						ifname = f.ext + apIdx;
				}
			}

			if (v.encryption && v.encryption != 'none')
				chips.push(E('span', { 'class': 'mtw-chip sec' }, encryption_label(v.encryption).split('/')[0]));
			else
				chips.push(E('span', { 'class': 'mtw-chip warn' }, _('open network')));

			if (v.hidden == '1')
				chips.push(E('span', { 'class': 'mtw-chip' }, _('hidden')));

			if (v.isolate == '1')
				chips.push(E('span', { 'class': 'mtw-chip' }, _('isolated')));

			if (disabled)
				chips.push(E('span', { 'class': 'mtw-chip warn' }, _('disabled')));

			return E('div', {}, [
				E('strong', {}, [ wifi_svg(disabled ? 'var(--mtw-muted)' : 'var(--mtw-accent)'), ' %s '.format(v.ssid || '?') ]),
				chips,
				E('div', {}, E('span', { 'class': 'mtw-ifname' }, '%s%s · %s'.format(
					ifname ? ifname + ' · ' : '',
					f ? band_label(f.band) : (devName || '?'),
					L.toArray(v.network).join(', ') || '-')))
			]);
		};

		s2.renderRowActions = function(section_id) {
			var isDisabled = (uci.get('wireless', section_id, 'disabled') == '1') ||
			                 (uci.get('wireless', uci.get('wireless', section_id, 'device'), 'disabled') == '1');

			return E('td', { 'class': 'td middle cbi-section-actions' }, E('div', [
				E('button', {
					'class': 'cbi-button cbi-button-neutral enable-disable',
					'title': isDisabled ? _('Enable this network') : _('Disable this network'),
					'click': ui.createHandlerFn(this, network_updown, section_id, this.map)
				}, isDisabled ? _('Enable') : _('Disable')),
				E('button', {
					'class': 'cbi-button cbi-button-action important',
					'title': _('Edit this network'),
					'click': ui.createHandlerFn(this, 'renderMoreOptionsModal', section_id)
				}, _('Edit')),
				E('button', {
					'class': 'cbi-button cbi-button-negative remove',
					'title': _('Delete this network'),
					'click': ui.createHandlerFn(this, 'handleRemoveIface', section_id)
				}, _('Remove'))
			]));
		};

		s2.handleRemoveIface = function(section_id, ev) {
			var mode = uci.get('wireless', section_id, 'mode') || 'ap',
			    dev = uci.get('wireless', section_id, 'device'),
			    ap_count = 0;

			if (mode == 'ap') {
				uci.sections('wireless', 'wifi-iface', function(v) {
					if (v.device == dev && v['.name'] != section_id && (v.mode || 'ap') == 'ap')
						ap_count++;
				});

				if (ap_count == 0) {
					ui.addNotification(null, E('p', _('At least one Access Point interface must be kept on each radio (MBSSID limit).')));
					return;
				}
			}

			document.querySelector('.cbi-section-table-row[data-sid="%s"]'.format(section_id)).style.opacity = 0.5;

			return form.TypedSection.prototype.handleRemove.apply(this, [section_id, ev]);
		};

		s2.handleAddIface = function(devName, ev) {
			var section_id = next_free_sid(uci.sections('wireless', 'wifi-iface').length),
			    ssid = 'OpenWrt',
			    ifaces = uci.sections('wireless', 'wifi-iface');

			for (var i = 0; i < ifaces.length; i++)
				if (ifaces[i].device == devName && (ifaces[i].mode || 'ap') == 'ap' && ifaces[i].ssid) {
					ssid = ifaces[i].ssid + '-2';
					break;
				}

			if (uci.sections('wireless', 'wifi-iface').length >= 16) {
				ui.addNotification(null, E('p', _('A maximum of 16 MBSSID interfaces is supported.')));
				return;
			}

			uci.unset('wireless', devName, 'disabled');

			uci.add('wireless', 'wifi-iface', section_id);
			uci.set('wireless', section_id, 'device', devName);
			uci.set('wireless', section_id, 'mode', 'ap');
			uci.set('wireless', section_id, 'ssid', ssid);
			uci.set('wireless', section_id, 'encryption', 'psk2');
			uci.set('wireless', section_id, 'key', '1234567890');

			return this.renderMoreOptionsModal(section_id);
		};

		s2.addModalOptions = function(s) {
			return network.getWifiNetwork(s.section).then(function(radioNet) {
				var devName = radioNet.getWifiDeviceName(),
				    hwtype = uci.get('wireless', devName, 'type'),
				    is_mtwifi = (hwtype == 'mtwifi'),
				    band = get_band(devName),
				    o, ss, encr;

				o = s.option(form.SectionValue, '_iface', form.NamedSection, radioNet.getName(), 'wifi-iface', _('Interface Configuration'));
				o.modalonly = true;

				ss = o.subsection;
				ss.tab('general', _('General Setup'));
				ss.tab('encryption', _('Wireless Security'));
				ss.tab('macfilter', _('Access Control'));
				ss.tab('advanced', _('Advanced Settings'));

				var mode = ss.option(form.ListValue, 'mode', _('Mode'));
				mode.value('ap', _('Access Point'));
				mode.value('sta', _('Client'));

				if (!is_mtwifi) {
					mode.value('adhoc', _('Ad-Hoc'));
					mode.value('mesh', '802.11s');
				}

				mode.rmempty = false;

				o = ss.option(form.Value, 'ssid', _('<abbr title="Extended Service Set Identifier">ESSID</abbr>'));
				o.datatype = 'maxlength(32)';
				o.depends('mode', 'ap');
				o.depends('mode', 'sta');
				if (!is_mtwifi)
					o.depends('mode', 'adhoc');

				o = ss.option(form.Value, 'bssid', _('<abbr title="Basic Service Set Identifier">BSSID</abbr>'), _('Only associate with the given BSSID (client mode)'));
				o.datatype = 'macaddr';
				o.depends('mode', 'sta');
				if (!is_mtwifi)
					o.depends('mode', 'adhoc');

				o = ss.option(widgets.NetworkSelect, 'network', _('Network'), _('Choose the network(s) you want to attach to this wireless interface or fill out the <em>custom</em> field to define a new network.'));
				o.rmempty = true;
				o.multiple = true;
				o.novirtual = true;
				o.write = function(section_id, value) {
					return network.getDevice(section_id).then(L.bind(function(dev) {
						var old_networks = dev.getNetworks().reduce(function(o, v) { o[v.getName()] = v; return o }, {}),
						    new_networks = {},
						    values = L.toArray(value),
						    tasks = [];

						for (var i = 0; i < values.length; i++) {
							new_networks[values[i]] = true;

							if (old_networks[values[i]])
								continue;

							tasks.push(network.getNetwork(values[i]).then(L.bind(function(name, net) {
								return net || network.addNetwork(name, { proto: 'none' });
							}, this, values[i])).then(L.bind(function(dev, net) {
								if (net) {
									if (!net.isEmpty()) {
										var target_dev = net.getDevice();

										/* Resolve parent interface of vlan */
										while (target_dev && target_dev.getType() == 'vlan')
											target_dev = target_dev.getParent();

										if (!target_dev || target_dev.getType() != 'bridge')
											net.set('type', 'bridge');
									}

									net.addDevice(dev);
								}
							}, this, dev)));
						}

						for (var name in old_networks)
							if (!new_networks[name])
								tasks.push(network.getNetwork(name).then(L.bind(function(dev, net) {
									if (net)
										net.deleteDevice(dev);
								}, this, dev)));

						return Promise.all(tasks);
					}, this));
				};

				if (is_mtwifi) {
					o = ss.option(form.DummyValue, '_repeater_hint', _('Repeater'), _('Use the "Repeater Scan" button on the radio row to discover upstream networks. Only one client interface per radio is supported.'));
					o.depends('mode', 'sta');
					o.write = function() {};

					o = ss.option(form.Flag, 'hidden', _('Hide <abbr title="Extended Service Set Identifier">ESSID</abbr>'), _('Where the ESSID is hidden, clients may fail to roam and airtime efficiency may be significantly reduced.'));
					o.depends('mode', 'ap');

					o = ss.option(form.Flag, 'wmm', _('WMM Mode'), _('Where Wi-Fi Multimedia (WMM) Mode QoS is disabled, clients may be limited to 802.11a/802.11g rates.'));
					o.depends('mode', 'ap');
					o.default = o.enabled;

					o = ss.option(form.Flag, 'isolate', _('Isolate Clients'), _('Prevents client-to-client communication'));
					o.depends('mode', 'ap');
				}
				else {
					o = ss.option(form.Flag, 'hidden', _('Hide <abbr title="Extended Service Set Identifier">ESSID</abbr>'));
					o.depends('mode', 'ap');

					o = ss.option(form.Flag, 'isolate', _('Isolate Clients'));
					o.depends('mode', 'ap');
				}

				encr = ss.option(form.ListValue, 'encryption', _('Encryption'));
				encr.rmempty = false;

				for (var i = 0; i < MTW_ENCRYPTIONS.length; i++)
					encr.value(MTW_ENCRYPTIONS[i][0], MTW_ENCRYPTIONS[i][1]);

				encr.write = function(section_id, value) {
					if (value == 'none' || value == 'owe') {
						uci.unset('wireless', section_id, 'key');
					}
					else {
						var kv = this.section.children.filter(function(o) { return o.option == 'key' })[0].formvalue(section_id);

						if (kv)
							uci.set('wireless', section_id, 'key', kv);
					}

					uci.set('wireless', section_id, 'encryption', value);
				};

				o = ss.option(form.Value, 'key', _('Key'));
				o.datatype = 'wpakey';
				o.password = true;
				o.depends('encryption', 'psk');
				o.depends('encryption', 'psk2');
				o.depends('encryption', 'psk-mixed');
				o.depends('encryption', 'sae');
				o.depends('encryption', 'sae-mixed');

				/* ------------------------------------------ ACL tab */
				var macfilter = ss.option(form.ListValue, 'macfilter', _('MAC Address Filter'), _('Up to 129 entries are supported. Changes take effect after the wireless is reloaded.'));
				macfilter.depends('mode', 'ap');
				macfilter.value('', _('disable'));
				macfilter.value('allow', _('Allow listed only'));
				macfilter.value('deny', _('Allow all except listed'));

				var maclist = ss.option(form.DynamicList, 'maclist', _('MAC-List'));
				maclist.datatype = 'macaddr';
				maclist.retain = true;
				maclist.depends('macfilter', 'allow');
				maclist.depends('macfilter', 'deny');
				maclist.load = function(section_id) {
					return network.getHostHints().then(L.bind(function(hints) {
						hints.getMACHints().map(L.bind(function(hint) {
							this.value(hint[0], hint[1] ? '%s (%s)'.format(hint[0], hint[1]) : hint[0]);
						}, this));

						return form.DynamicList.prototype.load.apply(this, [section_id]);
					}, this));
				};

				/* -------------------------------------- advanced tab */
				o = ss.option(form.Value, 'wpa_group_rekey', _('Time interval for rekeying GTK'), _('sec'));
				o.optional = true;
				o.placeholder = 3600;
				o.datatype = 'uinteger';

				o = ss.option(form.Value, 'dtim_period', _('DTIM Interval'));
				o.optional = true;
				o.placeholder = 1;
				o.datatype = 'range(1,255)';

				o = ss.option(form.Value, 'frag', _('Fragmentation Threshold'));
				o.optional = true;
				o.placeholder = '2346';
				o.datatype = 'range(256,2346)';

				o = ss.option(form.Value, 'rts', _('RTS/CTS Threshold'));
				o.optional = true;
				o.placeholder = '2347';
				o.datatype = 'range(1,2347)';

				if (is_mtwifi) {
					o = ss.option(form.Value, 'kicklow', _('Kick low-RSSI clients below (dBm)'), _('Stations with an average signal below this threshold are disconnected (0 = off).'));
					o.optional = true;
					o.placeholder = '0';
					o.datatype = 'range(-100,0)';

					o = ss.option(form.Value, 'assocthres', _('Association RSSI threshold (dBm)'), _('Association requests with a signal below this threshold are rejected (0 = off).'));
					o.optional = true;
					o.placeholder = '0';
					o.datatype = 'range(-100,0)';

					o = ss.option(form.Flag, 'ieee80211k', _('802.11k RRM'), _('Enables radio resource measurements for assisted roaming.'));
					o.depends('mode', 'ap');
					o.rmempty = true;

					if (band == '5g') {
						o = ss.option(form.Flag, 'mumimo_dl', _('MU-MIMO downlink'));
						o.rmempty = true;

						o = ss.option(form.Flag, 'mumimo_ul', _('MU-MIMO uplink'));
						o.rmempty = true;

						o = ss.option(form.Flag, 'ofdma_dl', _('OFDMA downlink'));
						o.rmempty = true;

						o = ss.option(form.Flag, 'ofdma_ul', _('OFDMA uplink'));
						o.rmempty = true;
					}

					o = ss.option(form.Flag, 'amsdu', _('A-MSDU aggregation'));
					o.rmempty = true;

					o = ss.option(form.Flag, 'autoba', _('Automatic Block ACK'));
					o.rmempty = true;

					o = ss.option(form.Flag, 'uapsd', _('U-APSD power saving'));
					o.rmempty = true;
				}
			});
		};

		/* ----------------------------------------------- page frame */

		return m.render().then(L.bind(function(m, nodes) {
			poll.add(L.bind(function() {
				return Promise.all([
					network.getHostHints(),
					this.mtw_ok ? callGetStatus() : Promise.resolve({}),
					this.mtw_ok ? callGetAssocList() : Promise.resolve({})
				]).then(L.bind(this.poll_status, this, nodes));
			}, this), 5);

			var dash = E('div', { 'id': 'mtw_dashboard' }, [
				E('div', { 'id': 'mtw_dashboard_content' },
					E('em', { 'class': 'spinning' }, _('Collecting data...')))
			]);

			var table = E('table', { 'class': 'table assoclist', 'id': 'wifi_assoclist_table' }, [
				E('tr', { 'class': 'tr table-titles' }, [
					E('th', { 'class': 'th' }, _('Network')),
					E('th', { 'class': 'th hide-xs' }, _('Host')),
					E('th', { 'class': 'th' }, _('Signal')),
					E('th', { 'class': 'th' }, _('RX Rate / TX Rate')),
					E('th', { 'class': 'th hide-xs' }, _('Uptime')),
					E('th', { 'class': 'th cbi-section-actions' }, ' ')
				])
			]);

			cbi_update_table(table, [], E('em', { 'class': 'spinning' }, _('Collecting data...')));

			return E([
				dash,
				nodes,
				E('h3', {}, _('Associated Stations')),
				E('div', { 'class': 'cbi-map-descr' },
					_('2.4 GHz stations are queried through the driver ioctl (mtwifi-sta), 5 GHz stations through nl80211. Click "Kick" to disconnect a client.')),
				table
			]);
		}, this, m));
	}
});
