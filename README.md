# coral NetHunter Kernel

**Google Pixel 4 / 4 XL（coral / flame，sm8150）的 Kali NetHunter 内核。**

官方 NetHunter 没有 coral 的成品内核，第三方唯一的 coral 移植停留在 Android 11。这个仓库提供一套完整的、可直接刷入的成品，以及构建它所需的一切：源码补丁、构建配置、最终内核配置、构建脚本。

- 版本串：`4.14.357-0xSoul-g26277ea9b0ce-dirty #1 SMP PREEMPT Mon Sep 28 10:00:12 UTC 2026`
- 目标设备：Pixel 4 XL（coral）/ Pixel 4（flame），槽位 A/B
- 参考 ROM：Evolution X 12.2 / Android 17（SDK 37）
- root：ReSukiSU（KernelSU 系，SUSFS hook），version code `35144`
- 中国大陆电信：**移动数据可用，拨号不可用**（见下）

## 已知问题

**内置 WiFi 不工作。** 高通 qcacld 驱动已编进内核（`CONFIG_QCA_CLD_WLAN=y`、`CONFIG_ICNSS=y`），但 `wlan0` 不会出现，手机自带的 WiFi 不可用。

**需要另配 USB 外置网卡。** 本内核已内置 **8812au / 8821au（`CONFIG_88XXAU=y`）** 的驱动，上网与无线功能（monitor / 注入）请通过外接 USB 网卡完成。

## 中国大陆电信用户

中国大陆的电信 SIM 在 Pixel 4 上需要额外处理，与内核本身无关，单列在这里。**只有中国大陆电信用户需要看这一节，其它运营商、其它地区不受影响。**

| 项目 | 状态 |
|---|---|
| 移动数据（4G 上网） | ✅ 可用 |
| 4G 注册 / 信号 | ✅ 正常 |
| 拨打电话（VoLTE / IMS） | ❌ 不可用，拨号提示「无法连接到移动网络」 |

Pixel 的基带 MBN 里没有中国任何运营商，电信卡只能落到 2G。本仓库 `china-telecom/` 下提供了一个 KernelSU 模块 `cnmbn`，把中国运营商的 MBN bind-mount 到 `/vendor`，解决 4G 上网。

拨号仍不可用：语音走 VoLTE（IMS），需要 carrier config 的中国运营商 IMS 配置与 Google `CarrierServices` 的支持列表，Pixel 出厂都不含。这属于 ROM / 应用层的 IMS 集成缺口，不在内核范围。

安装与细节见 [`china-telecom/README.md`](china-telecom/README.md)。

## 功能

| 能力 | 内核侧 |
|---|---|
| 外置 USB 网卡注入（8812au / 8821au） | `CONFIG_88XXAU=y` |
| mac80211 monitor / 注入框架 | `CONFIG_MAC80211=y` `CONFIG_MAC80211_MESH=y` `CONFIG_CFG80211_WEXT=y` |
| 其它无线注入网卡 | `CONFIG_ATH9K_HTC=y` `CONFIG_ZD1211RW=y` `CONFIG_RTL8187=y` `CONFIG_RTL8XXXU=y` |
| 内置 WiFi（qcacld） | `CONFIG_QCA_CLD_WLAN=y` `CONFIG_ICNSS=y`（编进内核；**当前不工作**，见「已知问题」） |
| HID / BadUSB（键盘、鼠标） | `CONFIG_USB_F_HID=y` `CONFIG_USB_CONFIGFS_F_HID=y` + NetHunter android HID gadget |
| 外置蓝牙（含 UB500 等） | `CONFIG_BT_HCIBTUSB=y` `CONFIG_BT_HIDP=y` 等 |
| USB 串口 | `CONFIG_USB_SERIAL=y` + FTDI / PL2303 / CP210X / CH341 / OPTION |
| USB 网卡共享（RNDIS） | `CONFIG_USB_CONFIGFS_RNDIS=y` |
| chroot / 容器 | `CONFIG_USER_NS=y` `CONFIG_PID_NS=y` `CONFIG_IPC_NS=y` |
| MITM / 热点网络 | `CONFIG_BRIDGE_NETFILTER=y` `CONFIG_NF_TABLES=y` `CONFIG_NFT_NAT=y` `CONFIG_MACVLAN=y` `CONFIG_IP_NF_TARGET_NETMAP=y` 等 |
| 只读卡带读卡器 | `CONFIG_RTS5208=y` |
| root | `CONFIG_KSU=y` `CONFIG_KSU_SUSFS=y`（+ SUSFS 全套隐藏项） |
| 崩溃现场落盘（可选调试） | `CONFIG_KPANIC_LOGGER=y` |

全部配置见 `config/kernel.config.final`；与原装内核的逐行差异见 `config/config-delta-vs-stock.diff`。

## 成品

| 文件 | 大小 | SHA256 |
|---|---|---|
| `release/kernel-nethunter-coral-cfiperm-20260928.zip` | 24,251,203 B | `e590c47c4f9a38ecefd1eb0c562c6ce27c978d07ea234df4f7418543a35e4bfe` |
| `release/boot_gnu_cfiperm.img` | 45,514,752 B | `47e0f749ad255a28d4ff3377d0586baa778206a49af9bee8305d9bd448114f68` |
| `Image.lz4`（内核本体，在 zip 内） | 27,310,595 B | `92d1c0ea5a6e7c1a8552db2d550ceb2f67819722c08b8f3cc97b146f8f52437b` |

- **`kernel-...zip`**：AnyKernel3 包，用 KernelFlasher / ReSukiSU / 任意支持 AK3 的工具刷入 boot 分区。
- **`boot_gnu_cfiperm.img`**：完整 boot 镜像，以原装 boot 为模板（原装 ramdisk + 原装 dtb，仅替换内核段）。可 `fastboot boot` 先验，不落盘。

> `do.modules=0`：WLAN 已编进内核，本包不带任何 `.ko`，刷完不需要再装模块。

## 刷入

```bash
# 0) 备份当前 boot
adb shell "su -c 'dd if=/dev/block/by-name/boot_a of=/data/local/tmp/boot_a_before.img'"
adb pull /data/local/tmp/boot_a_before.img .

# 1) 先验，不落盘
adb reboot bootloader
fastboot devices
fastboot boot boot_gnu_cfiperm.img

# 2) 确认能开机后落盘
fastboot flash boot boot_gnu_cfiperm.img
fastboot reboot
```

或者直接在 KernelFlasher / ReSukiSU 里选 `kernel-nethunter-coral-cfiperm-20260928.zip`。

**回退**：`fastboot flash boot boot_a_before.img`（或原装内核备份）。

### 刷后验证

```bash
adb shell "cat /proc/version"                 # 应含 4.14.357-0xSoul-g26277ea9b0ce-dirty
adb shell "su -M -c id"                       # uid=0
adb shell "su -M -c 'zcat /proc/config.gz | grep -E \"MAC80211=|88XXAU=|CFI_PERMISSIVE\"'"
adb shell "su -M -c 'ip -br link'"            # 插 OTG 网卡后出现 wlan1
adb shell "su -M -c 'ls /config/usb_gadget/g1/functions/'"   # hid.usb0 → BadUSB
adb shell "su -c 'aireplay-ng --test wlan1'"  # 外置网卡注入
```

## 构建

需要 AOSP 的 `kernel/build` 布局：

```
<root>/
├── build/                     # AOSP kernel/build
├── prebuilts/                 # Google prebuilts clang r416183b
├── private/msm-google/        # 内核源码树（本仓库补丁打在这里）
├── nethunter.config           # ← config/
└── build.config.nethunter-cfi # ← config/
```

一键构建（打补丁 + 检查 + 编译）：

```bash
./scripts/build.sh <root> nethunter
```

或者手动：

```bash
cd private/msm-google
git apply ../patches/0001-clang-target-aarch64-linux-gnu.patch
git apply ../patches/0002-kpanic-logger.patch
cp ../src/kpanic_logger.c drivers/misc/
cd <root>
BUILD_CONFIG=build.config.nethunter-cfi ./build/build.sh 2>&1 | tee build.log
```

产物在 `out/android-msm-pixel-4.14/dist/`：`Image.lz4`、`System.map`、`vmlinux`、`dtbo.img`、各 `.ko`。

详细的依赖、工具链版本、子模块处理、打包与 boot 镜像拼装见 [`docs/构建与刷入.md`](docs/构建与刷入.md)。

## 基线

| 项目 | 值 |
|---|---|
| 源码树 | [`0xSoul24/kernel_google_msm-4.14`](https://github.com/0xSoul24/kernel_google_msm-4.14) 分支 `cnb` |
| 源码 HEAD | `26277ea9b` |
| KernelSU | ReSukiSU tag `v4.2.0-rc2`（`3576e6a5`，4444 commits） |
| 工具链 | Android clang r416183b（12.0.5）+ LLD 12.0.5 |
| 交叉工具链 | `aarch64-linux-android-4.9` |
| 内核 defconfig | `floral_defconfig` |
| NetHunter 补丁 | Kali 官方 `kali-nethunter-kernels` → `patches/4.14`，以提交形式进树（见 `patches/README.md`） |

## 目录

```
├── README.md
├── LICENSE                     # GPL-2.0
├── config/
│   ├── build.config.nethunter-cfi     # 构建配置
│   ├── nethunter.config               # 叠加到 defconfig 的配置清单
│   ├── kernel.config.final            # 最终生效的 .config
│   └── config-delta-vs-stock.diff     # 与原装内核配置的逐行差异
├── patches/
│   ├── 0001-clang-target-aarch64-linux-gnu.patch
│   ├── 0002-kpanic-logger.patch
│   ├── optional/0003-legacy-manual-hook-anchors.patch
│   └── README.md
├── src/
│   ├── kpanic_logger.c                # 可选的崩溃日志落盘驱动
│   └── anykernel.sh                   # AnyKernel3 脚本
├── scripts/
│   └── build.sh
├── china-telecom/
│   └── cnmbn/                         # 中国大陆电信 MBN 模块（KernelSU）
├── docs/
│   ├── 技术说明.md                    # 内核设计要点与关键配置理由
│   └── 构建与刷入.md                  # 环境、编译、打包、刷入、验证、回退
└── release/                           # 成品（见 release/README.md）
```

## 许可

`src/kpanic_logger.c` 与 `patches/` 下的改动遵循 **GPL-2.0**，见 `LICENSE`。`config/`、`docs/`、`scripts/` 同样以 GPL-2.0 提供，方便直接取用。

本仓库**不包含**第三方源码，只包含针对它们的补丁与配置。构建时请从上游获取：

- [`0xSoul24/kernel_google_msm-4.14`](https://github.com/0xSoul24/kernel_google_msm-4.14)（LineageOS coral 4.14 树）
- Kali NetHunter 内核补丁：`https://gitlab.com/kalilinux/nethunter/build-scripts`
- [`aircrack-ng/rtl8812au`](https://github.com/aircrack-ng/rtl8812au) 驱动
- [AnyKernel3](https://github.com/osm0sis/AnyKernel3)
- [ReSukiSU / KernelSU](https://github.com/ReSukiSU/ReSukiSU)

## 声明

刷内核有风险。请备份 boot 分区、确认 bootloader 已解锁，并保留可回退的原装镜像。

---

本项目由 [Hanako](https://github.com/liliMozi/openhanako) 配合 DeepSeek v4.1 Flash 开展。
