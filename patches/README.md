# 补丁

本仓库自己写的改动，应用在源码树 `private/msm-google/` 下：

```bash
cd private/msm-google
git apply ../patches/0001-clang-target-aarch64-linux-gnu.patch
git apply ../patches/0002-kpanic-logger.patch
cp ../src/kpanic_logger.c drivers/misc/
```

---

## 0001-clang-target-aarch64-linux-gnu.patch

**必打。** 把 clang 的 `--target` 修正为 `aarch64-linux-gnu`（coral 4.14 内核的要求）。

```diff
-CLANG_FLAGS	+= --target=$(notdir $(CROSS_COMPILE:%-=%))
+CLANG_FLAGS	+= --target=$(CLANG_TARGET_FLAGS)
```

不打这一处，编出来的内核开机卡 Google 标志。理由见 `docs/技术说明.md` §1。

## 0002-kpanic-logger.patch

给 `drivers/misc/Kconfig` / `drivers/misc/Makefile` 挂上 `kpanic_logger` 驱动，配合 `src/kpanic_logger.c` 使用。作用与取舍见 `docs/技术说明.md` §5。

可选：去掉这个补丁与 `nethunter.config` 里的 `KPANIC_LOGGER` 即可不带它构建。

## optional/0003-legacy-manual-hook-anchors.patch

`fs/stat.c` / `fs/read_write.c` 上的 KernelSU manual hook 锚点。本配置走 SUSFS，这些改动被 `#ifdef CONFIG_KSU_MANUAL_HOOK` 条件编译掉，**属惰性代码**，正常构建不需要应用。

---

## 上游 NetHunter 补丁

本仓库不包含 Kali 官方的 NetHunter 补丁。它们以提交形式打在源码树里，来源：

- `https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernels` → `patches/4.14`
- HID gadget 的 android keyboard/mouse 在同一仓库

实际用到的：

| 补丁 | 用途 |
|---|---|
| `4.14__add-wifi-injection-4.14.patch` | mac80211 注入框架 |
| `4.14__add-rtl88xxau-5.6.4.2-drivers.patch` | `rtl8812au` / `8821au` 外置网卡驱动（约 16 MB） |
| `4.14__fix-ath9k-naming-conflict.patch` | ath9k 命名冲突 |
| `4.14__fix-thread_info.h-compile-time-errors.patch` | 编译适配 |
| `4.14__add-ub500-to-btusb-REAL.patch` | 蓝牙 UB500 适配（真身在 `patches/4.04/`） |
| `hid__hid_gadget-4.14.patch` | HID gadget 的 android keyboard / mouse（BadUSB） |
| `4.14__add-rtw88-drivers-4.14.patch` | 可选，本版未启用 |

未采用：`4.14__add-qcacld-3.0-injection-4.14.patch`（qcacld 本身不支持真注入）、`4.14__add-rtl8188eus-to-rtl8xxxu-drivers*.patch`、`4.14__fix-yylloc.dtc-lexer.lex.c_shipped.patch`。
