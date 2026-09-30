# release

可直接刷入的成品。

| 文件 | 大小 | SHA256 |
|---|---|---|
| `kernel-nethunter-coral-cfiperm-20260928.zip` | 24,251,203 B | `e590c47c4f9a38ecefd1eb0c562c6ce27c978d07ea234df4f7418543a35e4bfe` |
| `boot_gnu_cfiperm.img` | 45,514,752 B | `47e0f749ad255a28d4ff3377d0586baa778206a49af9bee8305d9bd448114f68` |
| `cnmbn-1.0.zip`（中国大陆电信 MBN，KernelSU 模块） | 60,031 B | — |

- 内核版本串：`4.14.357-0xSoul-g26277ea9b0ce-dirty #1 SMP PREEMPT Mon Sep 28 10:00:12 UTC 2026`
- 内核本体 `Image.lz4`：27,310,595 B，`sha256 92d1c0ea5a6e7c1a8552db2d550ceb2f67819722c08b8f3cc97b146f8f52437b`（在上面的 zip 内）

## zip 里有什么

```
anykernel.sh                              # AnyKernel3 脚本
Image.lz4                                 # 内核本体
META-INF/com/google/android/update-binary # AK3 刷入脚本（纯 shell，adb root 下也能跑）
tools/{busybox,magiskboot,magiskpolicy,ak3-core.sh}
LICENSE
```

**注意：`do.modules=0`。** 本版把 WLAN 编进了内核，不带任何 `.ko`，刷内核包之后**不需要**再装模块。

## 两个文件怎么用

- **先验（不落盘）**：`fastboot boot boot_gnu_cfiperm.img`。进系统 → 说明内核没问题。
- **定稿**：`fastboot flash boot boot_gnu_cfiperm.img`（或用 KernelFlasher / ReSukiSU 刷上面那个 zip）。

**刷之前先备份 boot**：

```bash
adb shell "su -c 'dd if=/dev/block/by-name/boot_a of=/data/local/tmp/boot_a_before.img'"
adb pull /data/local/tmp/boot_a_before.img .
```

回退：`fastboot flash boot boot_a_before.img`。

## 关于 GitHub 上的放置

这几个文件加起来约 70 MB，**不适合直接提交进 git 仓库**（`release/` 已在 `.gitignore` 里）。推荐做法是：

1. 仓库里保留本 `README.md`，以及内核产物的哈希；
2. 把刷机包与 boot 镜像传到 **GitHub Releases**（Tag 例如 `v1.0-20260928`），在 Release 描述里贴上面的 SHA256。

`cnmbn-1.0.zip` 就是 `china-telecom/cnmbn/` 的打包结果，源码已在仓库里，需要时可以重新打一份。

如果你更想直接提交进仓库，删掉 `.gitignore` 里的 `release/*.zip`、`release/*.img` 两行即可；两个大文件都在 GitHub 单文件上限内（45 MB 那个会触发大文件提示）。
