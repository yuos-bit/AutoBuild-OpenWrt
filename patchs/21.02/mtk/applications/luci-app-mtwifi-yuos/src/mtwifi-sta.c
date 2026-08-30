/*
 * mtwifi-sta - Query the associated-station table of Ralink/MediaTek
 * closed-source AP drivers (mt7603e / mt76x2 / mt7615d) via the private
 * ioctl RTPRIV_IOCTL_GET_MAC_TABLE (SIOCIWFIRSTPRIV + 0x0F) and print
 * one JSON object per station on stdout.
 *
 * The ASCII "iwpriv <if> get_mac_table" output is compiled out in these
 * builds (AR9_MAPI_SUPPORT / MIXMODE_SUPPORT disabled), so the ioctl
 * returns a binary RT_802_11_MAC_TABLE which we decode here.
 *
 * ABI (verified against mt7603e src, mipsel o32, little-endian):
 *   RT_802_11_MAC_ENTRY (28 bytes):
 *     UCHAR  ApIdx          @ 0
 *     UCHAR  Addr[6]        @ 1
 *     UCHAR  Aid            @ 7
 *     UCHAR  Psm            @ 8
 *     UCHAR  MimoPs         @ 9
 *     CHAR   AvgRssi0..2    @ 10..12
 *     (pad)                 @ 13..15
 *     UINT32 ConnectedTime  @ 16   (seconds)
 *     UINT16 TxRate         @ 20   (MACHTTRANSMIT_SETTING)
 *     (pad)                 @ 22..23
 *     UINT32 LastRxRate     @ 24   (kbit/s, driver-computed)
 *   RT_802_11_MAC_TABLE: ULONG Num @ 0, then entries @ 4.
 *
 *   MACHTTRANSMIT_SETTING (little-endian bit order):
 *     MCS:7 (bits 0-6)  BW:1 (bit 7)  ShortGI:1 (bit 8)
 *     STBC:2 (bits 9-10)  rsv:3  MODE:2 (bits 14-15)
 *     MODE: 0=CCK 1=OFDM 2=HT 3=HT-Greenfield
 *
 * License: GPL-2.0
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <net/if.h>
#include <linux/wireless.h>

#define RTPRIV_IOCTL_GET_MAC_TABLE (SIOCIWFIRSTPRIV + 0x0F)

#define MTW_MAX_ENTRIES		128	/* driver max is 75 (mt7603) / 116 (mt76x2) */
#define MTW_ENTRY_SIZE		28
#define MTW_ENTRY_OFF		4	/* header: ULONG Num */

/* decode a 16-bit MACHTTRANSMIT_SETTING word into kbit/s */
static unsigned int decode_tx_rate(unsigned short word, const char **mode,
				   unsigned int *mcs, unsigned int *bw,
				   unsigned int *sgi)
{
	static const unsigned int cck[] = {
		1000, 2000, 5500, 11000
	};
	static const unsigned int ofdm[] = {
		6000, 9000, 12000, 18000, 24000, 36000, 48000, 54000
	};
	/* HT: [20MHz|40MHz][LGI|SGI][MCS 0..7] */
	static const unsigned int ht[2][2][8] = {
		{ /* 20 MHz */
			{ 6500, 13000, 19500, 26000, 39000, 52000, 58500, 65000 },
			{ 7200, 14400, 21700, 28900, 43300, 57800, 65000, 72200 }
		},
		{ /* 40 MHz */
			{ 13500, 27000, 40500, 54000, 81000, 108000, 121500, 135000 },
			{ 15000, 30000, 45000, 60000, 90000, 120000, 135000, 150000 }
		}
	};

	unsigned int m = word & 0x7f;
	unsigned int b = (word >> 7) & 0x1;
	unsigned int g = (word >> 8) & 0x1;
	unsigned int mod = (word >> 14) & 0x3;
	unsigned int nss, base = 0;

	*mcs = m;
	*bw = b ? 40 : 20;
	*sgi = g;

	switch (mod) {
	case 0:
		*mode = "CCK";
		if (m < sizeof(cck) / sizeof(cck[0]))
			base = cck[m];
		break;
	case 1:
		*mode = "OFDM";
		if (m < sizeof(ofdm) / sizeof(ofdm[0]))
			base = ofdm[m];
		break;
	case 2:
	case 3:
		*mode = "HT";
		if (m < 8) {
			nss = 1;
			base = ht[b][g][m];
		} else if (m < 16) {
			nss = 2;
			base = ht[b][g][m - 8] * 2;
		}
		break;
	default:
		*mode = "";
		break;
	}

	return base;
}

static int all_same(const unsigned char *p, unsigned char c, int len)
{
	int i;

	for (i = 0; i < len; i++)
		if (p[i] != c)
			return 0;
	return 1;
}

int main(int argc, char **argv)
{
	unsigned char buf[MTW_ENTRY_OFF + MTW_MAX_ENTRIES * MTW_ENTRY_SIZE];
	struct iwreq wrq;
	struct ifreq ifr;
	int s, i, num, avail;
	unsigned long len;

	if (argc != 2) {
		fprintf(stderr, "usage: mtwifi-sta <interface>\n");
		return 1;
	}

	memset(&ifr, 0, sizeof(ifr));
	strncpy(ifr.ifr_name, argv[1], IFNAMSIZ - 1);

	s = socket(AF_INET, SOCK_DGRAM, 0);
	if (s < 0) {
		fprintf(stderr, "socket: cannot create\n");
		return 1;
	}

	/* the interface must exist, otherwise the ioctl operates on garbage */
	if (ioctl(s, SIOCGIFFLAGS, &ifr) < 0) {
		fprintf(stderr, "%s: no such interface\n", argv[1]);
		close(s);
		return 1;
	}

	memset(buf, 0, sizeof(buf));
	memset(&wrq, 0, sizeof(wrq));
	strncpy(wrq.ifr_name, argv[1], IFNAMSIZ - 1);
	wrq.u.data.pointer = (void *)buf;
	wrq.u.data.length = sizeof(buf);
	wrq.u.data.flags = 0;

	if (ioctl(s, RTPRIV_IOCTL_GET_MAC_TABLE, &wrq) < 0) {
		fprintf(stderr, "%s: ioctl failed\n", argv[1]);
		close(s);
		return 1;
	}
	close(s);

	len = (unsigned long)wrq.u.data.length;
	if (len < MTW_ENTRY_OFF || len > sizeof(buf))
		return 0;

	memcpy(&num, buf, sizeof(num));
	if (num < 0)
		return 0;

	avail = (int)((len - MTW_ENTRY_OFF) / MTW_ENTRY_SIZE);
	if (num > avail)
		num = avail;
	if (num > MTW_MAX_ENTRIES)
		num = MTW_MAX_ENTRIES;

	for (i = 0; i < num; i++) {
		const unsigned char *e = buf + MTW_ENTRY_OFF + i * MTW_ENTRY_SIZE;
		char mac[18];
		signed char rssi;
		unsigned int connected_time, last_rx_rate;
		unsigned short tx_rate;
		const char *mode = "";
		unsigned int mcs = 0, bw = 20, sgi = 0, kbits;

		/* skip empty / broadcast-ish garbage entries */
		if (all_same(e + 1, 0x00, 6) || all_same(e + 1, 0xff, 6))
			continue;

		snprintf(mac, sizeof(mac),
			 "%02x:%02x:%02x:%02x:%02x:%02x",
			 e[1], e[2], e[3], e[4], e[5], e[6]);

		rssi = (signed char)e[10];

		memcpy(&connected_time, e + 16, sizeof(connected_time));
		memcpy(&tx_rate, e + 20, sizeof(tx_rate));
		memcpy(&last_rx_rate, e + 24, sizeof(last_rx_rate));

		kbits = decode_tx_rate(tx_rate, &mode, &mcs, &bw, &sgi);

		printf("{\"mac\":\"%s\",\"bss\":%d,\"aid\":%d,\"psm\":%d,"
		       "\"rssi\":%d,\"uptime\":%u,"
		       "\"mode\":\"%s\",\"mcs\":%u,\"bw\":%u,\"sgi\":%u,"
		       "\"rx_kbits\":%u,\"tx_kbits\":%u}\n",
		       mac, e[0], e[7], e[8], rssi,
		       connected_time, mode, mcs, bw, sgi,
		       last_rx_rate, kbits);
	}

	return 0;
}
