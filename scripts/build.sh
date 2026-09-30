#!/usr/bin/env bash
#
# coral NetHunter Kernel —— 构建脚本
#
# 用法：
#   ./scripts/build.sh <AOSP_ROOT> [nethunter|baseline]
#
#   <AOSP_ROOT>  AOSP kernel/build 布局根目录，里面要有 build/、prebuilts/、private/msm-google/
#   第二个参数   构建配置，默认 nethunter（= build.config.nethunter-cfi）
#
set -euo pipefail

ROOT="${1:-}"
MODE="${2:-nethunter}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "用法: $0 <AOSP_ROOT> [nethunter|baseline]" >&2
  exit 1
fi

case "$MODE" in
  nethunter) BUILD_CONFIG=build.config.nethunter-cfi ;;
  baseline)  BUILD_CONFIG=build.config.nethunter-baseline ;;
  *) echo "未知模式: $MODE（可选 nethunter | baseline）" >&2; exit 1 ;;
esac

KERNEL_DIR="$ROOT/private/msm-google"
if [ ! -d "$KERNEL_DIR" ]; then
  echo "找不到内核源码树: $KERNEL_DIR" >&2
  exit 1
fi

echo "== 1/3 放置构建配置 =="
cp -f "$HERE/config/build.config.nethunter-cfi" "$ROOT/build.config.nethunter-cfi"
cp -f "$HERE/config/nethunter.config"           "$ROOT/nethunter.config"

echo "== 2/3 检查源码补丁 =="
cd "$KERNEL_DIR"

# 0001 是 coral 4.14 的必需修改（clang 目标）
if grep -q -- '--target=$(CLANG_TARGET_FLAGS)' Makefile && \
   ! grep -q -- '--target=$(notdir $(CROSS_COMPILE:%-=%))' Makefile; then
  echo "  [ok] 0001 clang 目标补丁已在位"
else
  echo "  [!!] 0001 clang 目标补丁未打，正在应用"
  git apply "$HERE/patches/0001-clang-target-aarch64-linux-gnu.patch"
fi

if [ ! -f drivers/misc/kpanic_logger.c ]; then
  echo "  [++] 应用 0002 kpanic_logger"
  git apply "$HERE/patches/0002-kpanic-logger.patch"
  cp -f "$HERE/src/kpanic_logger.c" drivers/misc/
else
  echo "  [ok] 0002 kpanic_logger 已在位"
fi

if [ ! -e .gitmodules ] || ! grep -q KernelSU .gitmodules 2>/dev/null; then
  echo "  [??] 源码树里没有 KernelSU 子模块，跳过检查"
else
  KSU_COUNT="$(cd KernelSU && git rev-list --count HEAD 2>/dev/null || echo 0)"
  KSU_VER=$((30000 + KSU_COUNT + 700))
  if [ "$KSU_VER" -lt 35000 ]; then
    echo "  [!!] KernelSU 版本号 $KSU_VER 与预期不符（应为 35144）。"
    echo "       请执行: git submodule update --init --recursive && cd KernelSU && git fetch --tags && git checkout v4.2.0-rc2"
  else
    echo "  [ok] KernelSU 版本号 $KSU_VER"
  fi
fi

echo "== 3/3 编译 =="
cd "$ROOT"
LOG="$ROOT/build-${MODE}-$(date +%Y%m%d-%H%M%S).log"
echo "  配置: $BUILD_CONFIG"
echo "  日志: $LOG"
BUILD_CONFIG="$BUILD_CONFIG" ./build/build.sh 2>&1 | tee "$LOG"

echo
echo "== 完成 =="
DIST="$ROOT/out/android-msm-pixel-4.14/dist"
ls -la "$DIST/Image.lz4" "$DIST/System.map" 2>/dev/null || true
echo
echo "下一步：把 $DIST/Image.lz4 放进 AnyKernel3 目录打 zip（见 src/anykernel.sh），"
echo "或按 docs/构建与刷入.md 第 6 节操作。"
