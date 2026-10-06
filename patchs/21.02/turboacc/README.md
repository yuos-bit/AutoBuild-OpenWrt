# 通用 TurboACC（OpenWrt 21.02 / iptables / fw3）

针对 OpenWrt 21.02（内核 5.4，防火墙为 **firewall3(fw3) + iptables**，而非 nftables/firewall4）
的**通用**加速包，支持：

| 功能 | 后端 | 说明 |
|------|------|------|
| 软件流加速 | `xt_FLOWOFFLOAD`（kmod-ipt-offload） | 通用、最稳，MT7621 可开硬件 offload |
| Shortcut-FE (SFE) | `kmod-shortcut-fe` + `kmod-fast-classifier` / `kmod-shortcut-fe-cm` | 高通 SFE 转发引擎 |
| **全锥形 NAT (FullCone / NAT1)** | `xt_FULLCONENAT` + fw3 `fullcone` 选项 | **iptables 版**，非 nft-fullcone |
| TCP BBR | `kmod-tcp-bbr` | 拥塞控制算法 |

> 说明：`chenmozhijin/turboacc` 面向 firewall4/nftables，21.02 无法直接使用。
> 本项目改用 ImmortalWrt 21.02 的 iptables/fw3 实现（`luci-app-turboacc` 通用版），
> 并重命名为 `luci-app-turboacc-mtk`（沿用你仓库里的包名）。

## 目录结构

```
patchs/21.02/turboacc/
├── README.md
├── packages/                         # 复制到 openwrt/package/turboacc/
│   ├── luci-app-turboacc-mtk/        # 前端（通用 turboacc，含 fullcone/SFE/flowoffload/BBR）
│   ├── fullconenat/                  # kmod-ipt-fullconenat + iptables-mod-fullconenat
│   ├── shortcut-fe/                  # kmod-shortcut-fe + kmod-shortcut-fe-cm
│   └── fast-classifier/              # kmod-fast-classifier（配套 ImmortalWrt shortcut-fe）
├── kernel-patches/                   # 复制到 openwrt/target/linux/generic/hack-5.4/
│   ├── 952-net-conntrack-events-support-multiple-registrant.patch
│   └── 953-net-patch-linux-kernel-to-support-shortcut-fe.patch
└── firewall/
    └── 100-fullconenat.patch         # 复制到 package/network/config/firewall/patches/
```

## 工作原理（关键：iptables/fw3）

### 1. 全锥形 NAT（本包核心）

fw3 默认在 wan 出口生成 `-j MASQUERADE`。全锥形 NAT 需要把这条规则替换成 `-j FULLCONENAT`
（并在 prerouting/postrouting 两个链都加）。这需要三层配合：

1. **内核模块** `xt_FULLCONENAT.ko`（`fullconenat` 包，源码来自 Chion82/netfilter-full-cone-nat，固定 commit）；
2. **iptables 扩展** `libipt_FULLCONENAT.so`（同上包，`iptables-mod-fullconenat`）；
3. **fw3 补丁** `100-fullconenat.patch`：给 fw3 的 `defaults` 增加 `fullcone` 布尔选项，
   当 `firewall.@defaults[0].fullcone=1` 时，`zones.c` 用 `FULLCONENAT` 取代 `MASQUERADE`。

前端 `luci-app-turboacc-mtk` 的 `init.d/turboacc` 会把用户勾选的全锥形选项写入
`firewall.@defaults[0].fullcone` 并重启 firewall。开机 `uci-defaults/turboacc` 检测到
`xt_FULLCONENAT.ko` 存在时自动开启 fullcone。

> 注意：这里用的是 **iptables 版**（`xt_FULLCONENAT`），不是 nftables 的 `nft-fullcone`。
> 21.02 是 fw3/iptables，所以必须用 fw3 补丁 + xt_FULLCONENAT 这条路径。

### 2. SFE（Shortcut Forwarding Engine）

需要内核补丁 `952`（conntrack 事件多注册者，让 fullcone 与 SFE 能共存）+ `953`（内核 SFE 钩子），
配合 `shortcut-fe` + `fast-classifier`（或 `shortcut-fe-cm`）内核模块。前端构建期通过
`PACKAGE_TURBOACC_INCLUDE_*` 选择引擎，运行期 `uci-defaults` 自动探测最优点。

### 3. 软件流加速（flow offloading）

无需额外补丁，依赖 `kmod-ipt-offload`（`xt_FLOWOFFLOAD`）。fw3 原生支持
`flow_offloading` / `flow_offloading_hw` 选项。MT7621 可开硬件 offload（`fastpath_fo_hw`）。

## 构建接入（diy-part1 阶段）

所有包与补丁都在 `openwrt21.02-1.sh`（`./scripts/feeds update` **之前**）完成，因为：

- 包复制到 `package/`（主树，不依赖 feeds）；
- 内核补丁复制到 `target/linux/generic/hack-5.4/`（内核编译前就位）；
- fw3 补丁复制到 `package/network/config/firewall/patches/`（fw3 包编译时自动 `patch -p1` 应用）。

`openwrt21.02-1.sh` 中新增的代码：

```bash
# ===== 通用 TurboACC：flow offload + SFE + 全锥形 NAT + BBR（iptables/fw3） =====
rm -rf package/main/fast-classifier       # 用配套版本替换 package/main 里的旧 fast-classifier，避免重名
mkdir -p package/turboacc
cp -rf "$GITHUB_WORKSPACE/patchs/21.02/turboacc/packages/"* package/turboacc/
cp -rf "$GITHUB_WORKSPACE/patchs/21.02/turboacc/kernel-patches/"* target/linux/generic/hack-5.4/
cp -rf "$GITHUB_WORKSPACE/patchs/21.02/turboacc/firewall/"* package/network/config/firewall/patches/
```

## 需在 .config 中启用的项（以小米 AC2100 / MT7621 为例）

```
CONFIG_PACKAGE_luci-app-turboacc-mtk=y
CONFIG_PACKAGE_TURBOACC_INCLUDE_FLOW_OFFLOADING=y   # fastpath 引擎：流加速（MT7621 推荐）
CONFIG_PACKAGE_TURBOACC_INCLUDE_BBR_CCA=y
CONFIG_PACKAGE_kmod-ipt-fullconenat=y               # 全锥形 NAT 内核模块
CONFIG_PACKAGE_iptables-mod-fullconenat=y           # 全锥形 NAT iptables 扩展
CONFIG_PACKAGE_kmod-ipt-offload=y                   # 流加速模块
```

- 若要用 SFE 代替流加速，把 `TURBOACC_INCLUDE_FLOW_OFFLOADING` 换成
  `CONFIG_PACKAGE_TURBOACC_INCLUDE_FAST_CLASSIFIER=y`（或 `..._SHORTCUT_FE_CM=y`）。
- 三个 fastpath 引擎是互斥（choice），BBR 可独立开启。

## 源码来源（ImmortalWrt 21.02，已验证兼容内核 5.4 / fw3）

- `immortalwrt/immortalwrt @ openwrt-21.02`：`package/network/utils/{fullconenat,shortcut-fe,fast-classifier}`、
  `package/network/config/firewall/patches/100-fullconenat.patch`、
  `target/linux/generic/hack-5.4/{952,953}-*.patch`
- `immortalwrt/luci @ openwrt-21.02`：`applications/luci-app-turboacc`（改名为 `luci-app-turboacc-mtk`）
- `Chion82/netfilter-full-cone-nat`：xt_FULLCONENAT 内核源码（fullconenat 包按 commit 拉取）
