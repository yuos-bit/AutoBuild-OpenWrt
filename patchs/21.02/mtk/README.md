# patchs/21.02/mtk — MT7621 无线驱动 + mtwifi-cfg 管理适配

本目录是把 `hanwckf/immortalwrt-mt798x` 里两代 MTK feed 合并、适配后的产物：

- **驱动** 取自 `patchs/immortalwrt-mt798x/mt/drivers`（MT7621 / ramips 取向）：
  `mt7603e` / `mt7612e` / `mt7615d` / `mt_wifi`(配置 meta 包)。
- **管理应用** 取自 `patchs/immortalwrt-mt798x/mtk/applications`（MT798x 取向的
  新一代 mtwifi-cfg 体系）：`mtwifi-cfg` / `luci-app-mtwifi-cfg` / `datconf` / `8021xd`。

目标：让 **`luci-app-mtwifi-cfg` 这一套（mtk 目录里的新管理面板 + 后端）** 原生管理
**mt7603e / mt7612e / mt7615d** 这三个 MT7621 无线芯片，并整体放进 `patchs/21.02/mtk`
这个「`mtk` 结构」（`drivers/` + `applications/`）里。

---

## 目录结构

```
patchs/21.02/mtk/
├── drivers/
│   ├── mt7603e/        # mt7603e.ko  —— 2.4G（RT2860v2 系）
│   ├── mt7612e/        # mt76x2_ap.ko —— 5G MT7612（PKG_NAME 为 mt76x2e）
│   ├── mt7615d/        # mt_wifi.ko   —— 5G MT7615 DBDC（已剥离旧 mt_dbdc 管理）
│   └── mt_wifi/        # 配置 meta 包：l1profile.dat + .dat + firmware.sh + 91_load_wifi.sh
│                       #   （已剥离旧的 mt7615.lua / wifi_services.lua 检测脚本）
└── applications/
    ├── mtwifi-cfg/          # 后端：mtwifi_cfg + l1util + netifd mtwifi.sh + detect mtwifi.sh（已适配）
    ├── luci-app-mtwifi-cfg/ # 前端：wireless-mtk.js（芯片无关，仅认 type=mtwifi）
    ├── datconf/             # .dat 文件编辑工具（libkvcutil/kvcedit/datconf/datconf-lua）
    └── 8021xd/              # WPA-Enterprise / 802.1X
```

---

## 关键适配点（相对原始 `mt` / `mtk` 的改动）

1. **`drivers/mt_wifi/`（配置 meta 包）**
   - 删除旧的 `mt7615.lua`（旧检测/管理脚本）与 `wifi_services.lua`，避免和
     `mtwifi-cfg` 的 `detect_mtwifi` 产生双重检测。
   - 保留 `.dat` 文件、`l1profile.dat`、`firmware.sh`、`91_load_wifi.sh`、`SingleSKU*`。
   - **补全 `7603_7612-l1profile.dat`**：原始只有 `INDEX0=MT7603`，缺 MT7612 条目，
     导致 mtwifi-cfg 无法枚举 5G 网卡；已按 7603+7615 的格式补上
     `INDEX1=MT7612`（`main_ifname=rai0` → `mt7615.2.dat`）。

2. **`drivers/mt7615d/`**
   - 删掉 `KernelPackage/mt7615d_dbdc` 这个旧管理 meta 包（它会装旧的
     `mt_dbdc.sh` netifd 驱动 + `10_mt7615_dbdc` uci-defaults，与 `mt_wifi` 冲突）。
   - 只保留 `KernelPackage/mt7615d`（纯 `mt_wifi.ko` 驱动），管理交给 mtwifi-cfg。

3. **`applications/mtwifi-cfg/`**
   - `Makefile`：`DEPENDS` 由 `+wifi-dats` 改为 `+mt_wifi`（mt7621 没有 wifi-profile，
     .dat/l1profile 由 `mt_wifi` 配置包提供）；去掉 `@!PACKAGE_wifi-profile`。
   - `files/mtwifi.sh`（detect）：
     - 模块探测由只认 `/sys/module/mt_wifi` 扩展为同时认
       `mt_wifi` / `mt7603e` / `mt76x2_ap`（MT7621 三种驱动组合）。
     - 频段判定：优先 `l1util get band`，失败则按芯片名 `MT7603→2g`、
       `MT7612→5g`、其余按 `subidx`（DBDC：`ra0`=2g / `rax0`=5g）。
     - htmode 由 HE 改为 11ac/11n：2g=`HT40`、5g=`VHT80`（mtwifi_cfg 只取数字，
       `40→HT_BW`、`80→VHT_BW`）。
     - 去掉 `mu_beamformer=1` 默认值（MT7603/MT7612 不支持，MT7615 wave2 才可选开）。

---

## 集成到构建（diy-part2 阶段）

构建源是 `hanwckf/immortalwrt-mt798x @ openwrt-21.02`，其 `package/mtk/` 是 MT798x 取向。
把本目录叠加到 `package/mtk/` 即可让 MT7621 驱动 + 新管理应用进入 feed：

```sh
# 1) 驱动：覆盖 drivers（注意 mt_wifi 目录名冲突，见下）
rm -rf package/mtk/drivers/mt_wifi
cp -rf "$GITHUB_WORKSPACE/patchs/21.02/mtk/drivers/"* package/mtk/drivers/

# 2) 应用：覆盖/补充 applications
cp -rf "$GITHUB_WORKSPACE/patchs/21.02/mtk/applications/"* package/mtk/applications/
```

> **目录名冲突说明**：`package/mtk/drivers/mt_wifi`（MT798x 的 `kmod-mt_wifi` 内核包）
> 与本目录 `drivers/mt_wifi`（MT7621 的 `mt_wifi` 配置 meta 包）同名同目录。
> MT7621 构建需要**覆盖**前者（MT7621 用 mt7603e/mt7612e/mt7615d 三个驱动，不需要
> MT798x 的 mt_wifi.ko）。因此 MT798x 与 MT7621 建议使用**各自的构建工作流/配置**，
> 不要在同一份源码树里混用。

---

## 需要的 config 选项（MT7621）

以「mt7603e + mt7615d」组合（最常见的 K2P 类机型）为例：

```
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt7621=y
CONFIG_TARGET_ramips_mt7621_DEVICE_<设备名>=y

# 驱动
CONFIG_PACKAGE_kmod-mt7603e=y
CONFIG_PACKAGE_kmod-mt7615d=y          # 5G（mt7603+mt7612 组合则用 kmod-mt76x2e）
# CONFIG_PACKAGE_kmod-mt76x2e=y        # 仅 7603+7612 组合需要

# 管理（mtwifi-cfg 会自动拉 mt_wifi 配置包 + datconf）
CONFIG_PACKAGE_mtwifi-cfg=y
CONFIG_PACKAGE_luci-app-mtwifi-cfg=y
```

- `mt_wifi` 配置包的 `config.in` 会按 `kmod-mt7603e` / `kmod-mt76x2e` / `kmod-mt7615d`
  的选中情况自动决定 `MTK_CHIP_MT7603E_MT7612E / MT7603E_MT7615E / MT7615E_DBDC`，
  从而安装对应的 `.dat` + `l1profile.dat`。
- **不要**再选旧的 `luci-app-mtk`（与 mtwifi-cfg 冲突：`@!PACKAGE_luci-app-mtk`）。

---

## 需要真机验证 / 已知注意事项

1. **`mtwifi_cfg` / `l1util` 是预编译二进制**（`applications/mtwifi-cfg/files/...`）。
   两者与原 mtk 目录完全一致，且都依赖 `l1profile.dat` + `.dat` + iwpriv 这套
   MTK 通用接口（MT7621 与 MT798x 的 `l1profile.dat` 格式、`ra0/rai0/rax0` 命名一致），
   从架构上兼容；但 hanwckf 的 mtwifi-cfg 主要在 mt798x 上测试过，**MT7603/MT7612/MT7615
   实际配置效果需上真机确认**（尤其是 `mtwifi_cfg setup` 生成的 iwpriv/dat 指令在旧驱动
   上的表现）。
2. **MT7612 的 EEPROM 偏移/大小**：补全 `7603_7612-l1profile.dat` 时
   `INDEX1_EEPROM_offset=0x8000 / size=0x4000` 沿用 MT7615 的常规值；不同 MT7621 机型的
   factory/e2p 分区布局可能不同，如遇 EEPROM 读取异常需按机型调整。
3. **HE/OFDMA 默认值**：`mtwifi_defs.lua` 里的 `MuOfdmaDlEnable`、`MuOfdmaUlEnable`、
   `DLSCapable` 等 11ax 默认项对 MT7621（11ac/11n）无效，旧驱动会忽略未知 .dat 键，
   一般无害；如想彻底干净可在 `mtwifi_defs.lua` 里删除这些键。
4. **频段判定边界情况**：`7615.l1profile.dat`（默认分支，ra0=2G/rai0=5G 的非 DBDC
   单卡双频）按 `subidx` 判定会把 ra0 判成 5g。这只影响 LuCI 里的「2.4G/5G」标签显示，
   不影响实际 .dat 配置（.dat 由 l1profile 的 profile_path 决定）；如需精确可进一步
   按 `.dat` 的 `WirelessMode`/`Channel` 判定。
