#!/usr/bin/env bash
# =============================================================================
# AI_Radiagnos — HarmonyOS 一键打包脚本
# =============================================================================
# 前置条件（需用户提前准备）：
#   1. 华为官方 Flutter 鸿蒙分支 flutter_flutter_ohos（branch: oh-3.27.0-release）
#      git clone -b oh-3.27.0-release https://gitcode.com/openharmony-sig/flutter_flutter.git
#   2. DevEco Studio（含 HarmonyOS SDK + hvigor）
#      https://developer.harmonyos.com/cn/develop/deveco-studio/
#      安装后设置环境变量：HOS_SDK_HOME / DEVECO_SDK_HOME
#   3. Java JDK 17+
#   4. 鸿蒙 Flutter 版本文件修复（version 文件为 "0.0.0-unknown" 会导致 pub 失败）：
#      echo "3.27.0" > $OHOS_FLUTTER/version
#      # 同时修改 bin/cache/flutter.version.json 中 frameworkVersion 和 flutterVersion 为 "3.27.0"
#
# 用法：
#   OHOS_FLUTTER=/path/to/flutter_flutter bash scripts/build_harmony.sh
#   OHOS_FLUTTER=/path/to/flutter_flutter bash scripts/build_harmony.sh --debug
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_MODE="release"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) BUILD_MODE="debug"; shift;;
    --release) BUILD_MODE="release"; shift;;
    *) shift;;
  esac
done

echo "================================================"
echo "  AI_Radiagnos · HarmonyOS 打包"
echo "  模式: $BUILD_MODE"
echo "  项目: $PROJECT_DIR"
echo "================================================"

# ---------- 1. 定位鸿蒙 Flutter ----------
OHOS_FLUTTER="${OHOS_FLUTTER:-$HOME/flutter_flutter_ohos}"
OHOS_FLUTTER_BIN="$OHOS_FLUTTER/bin/flutter"

if [[ ! -f "$OHOS_FLUTTER_BIN" ]]; then
  echo "[1/5] 未找到鸿蒙 Flutter SDK"
  echo ""
  echo "  请先克隆华为官方鸿蒙分支:"
  echo "    git clone https://gitcode.com/openharmony-sig/flutter_flutter.git $OHOS_FLUTTER"
  echo "    cd $OHOS_FLUTTER && git checkout ohos-dev"
  echo ""
  echo "  然后设置环境变量后重试:"
  echo "    OHOS_FLUTTER=$OHOS_FLUTTER bash $0"
  exit 1
fi
echo "[1/5] 鸿蒙 Flutter: $OHOS_FLUTTER"
export PATH="$OHOS_FLUTTER/bin:$PATH"
export PUB_HOSTed_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# ---------- 1.1 修复 version 文件（0.0.0-unknown 会导致 pub 依赖解析失败）----------
VERSION_FILE="$OHOS_FLUTTER/version"
CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
if [[ "$CURRENT_VERSION" == "0.0.0-unknown" || -z "$CURRENT_VERSION" ]]; then
  echo "  修复 version 文件: 0.0.0-unknown -> 3.27.0"
  echo "3.27.0" > "$VERSION_FILE"
  # 同步更新缓存
  CACHE_VER_JSON="$OHOS_FLUTTER/bin/cache/flutter.version.json"
  if [[ -f "$CACHE_VER_JSON" ]]; then
    sed -i 's/"0.0.0-unknown"/"3.27.0"/g' "$CACHE_VER_JSON" 2>/dev/null || true
  fi
fi

# ---------- 2. DevEco / hvigor ----------
if ! command -v hvigor &>/dev/null && [[ -z "${DEVECO_SDK_HOME:-}" ]]; then
  echo ""
  echo "[2/5] 未检测到 DevEco Studio / hvigor"
  echo "  请安装 DevEco Studio:"
  echo "    https://developer.harmonyos.com/cn/develop/deveco-studio/"
  echo "  并配置 DEVECO_SDK_HOME 环境变量。"
  exit 1
fi
echo "[2/5] DevEco SDK: ${DEVECO_SDK_HOME:-已配置}"

# ---------- 3. Java ----------
if ! command -v java &>/dev/null; then
  echo "[3/5] 未检测到 Java，请安装 JDK 17+"
  exit 1
fi
echo "[3/5] Java: $(java -version 2>&1 | head -1)"

# ---------- 4. 生成 ohos/ 平台目录 ----------
cd "$PROJECT_DIR"
if [[ ! -d "ohos" ]]; then
  echo "[4/5] 生成 ohos/ 平台工程..."
  flutter create --platforms ohos --org com.radatlas .
else
  echo "[4/5] ohos/ 目录已存在，跳过生成"
fi

# ---------- 5. 编译 ----------
echo "[5/5] 开始编译 $BUILD_MODE HAP..."
flutter pub get
if [[ "$BUILD_MODE" == "debug" ]]; then
  flutter build hap --debug
else
  flutter build hap --release
fi

HAP_PATH="build/app/outputs/hap/${BUILD_MODE}/entry-default-signed.hap"
echo ""
echo "================================================"
echo "  ✅ 打包成功"
echo "  HAP: $PROJECT_DIR/$HAP_PATH"
echo "================================================"
echo ""
echo "安装到设备: hdc install \"$HAP_PATH\""
echo ""
echo "⚠️  注意："
echo "  1. HarmonyOS 真机安装需要签名证书，请在 DevEco Studio 中配置："
echo "     File → Project Structure → Signing Configs"
echo "  2. 首次打包可能需要在 DevEco Studio 中打开 ohos/ 目录完成 SDK 同步"
