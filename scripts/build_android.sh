#!/usr/bin/env bash
# =============================================================================
# AI_Radiagnos — Android 一键打包脚本
# =============================================================================
# 功能：
#   1. 检查 / 自动安装 Flutter SDK（中国镜像）
#   2. 检查 / 提示安装 Android SDK + Java
#   3. 生成 android/ 平台工程目录
#   4. 编译 release APK（含 debug 签名，可直接安装测试）
#   5. 输出 APK 路径
#
# 用法：
#   bash scripts/build_android.sh           # 默认 release
#   bash scripts/build_android.sh --debug   # 编译 debug APK
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter-sdk}"
FLUTTER_BIN="$FLUTTER_DIR/flutter/bin/flutter"
BUILD_MODE="release"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) BUILD_MODE="debug"; shift;;
    --release) BUILD_MODE="release"; shift;;
    *) echo "未知参数: $1"; exit 1;;
  esac
done

echo "================================================"
echo "  AI_Radiagnos · Android 打包"
echo "  模式: $BUILD_MODE"
echo "  项目: $PROJECT_DIR"
echo "================================================"

# ---------- 1. Flutter SDK ----------
if [[ ! -f "$FLUTTER_BIN" ]]; then
  echo "[1/5] 未找到 Flutter SDK，开始下载到 $FLUTTER_DIR ..."
  mkdir -p "$FLUTTER_DIR"
  # 优先使用中国镜像
  local_url="https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.27.0-stable.zip"
  echo "  下载: $local_url"
  curl -L --fail -o /tmp/flutter.zip "$local_url"
  echo "  解压..."
  unzip -q /tmp/flutter.zip -d "$FLUTTER_DIR"
  # unzip 后目录是 flutter/，内容已在 $FLUTTER_DIR/flutter/
  if [[ -d "$FLUTTER_DIR/flutter" ]]; then
    mv "$FLUTTER_DIR/flutter"/* "$FLUTTER_DIR"/ 2>/dev/null || true
    rmdir "$FLUTTER_DIR/flutter" 2>/dev/null || true
  fi
  rm -f /tmp/flutter.zip
  echo "  Flutter SDK 安装完成。"
else
  echo "[1/5] Flutter SDK 已存在: $FLUTTER_DIR"
fi

export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PATH="$FLUTTER_DIR/bin:$PATH"

echo "  Flutter 版本:"
flutter --version

# ---------- 2. Java ----------
if ! command -v java &>/dev/null; then
  echo ""
  echo "[2/5] 警告: 未检测到 Java（Android 构建需要 JDK 17+）"
  echo "  请安装后重试："
  echo "    • Windows: 下载 https://adoptium.net/temurin/releases/?version=17"
  echo "    • 或 winget install EclipseAdoptium.Temurin.17.JDK"
  echo "  并设置 JAVA_HOME 环境变量。"
  exit 1
else
  echo "[2/5] Java: $(java -version 2>&1 | head -1)"
fi

# ---------- 3. Android SDK ----------
if [[ -z "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ]]; then
  # 尝试默认路径
  if [[ -d "$LOCALAPPDATA/Android/Sdk" ]]; then
    export ANDROID_HOME="$LOCALAPPDATA/Android/Sdk"
  elif [[ -d "$HOME/Android/Sdk" ]]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
  else
    echo ""
    echo "[3/5] 警告: 未检测到 Android SDK"
    echo "  请安装 Android Studio: https://developer.android.com/studio"
    echo "  首次运行 Android Studio 会自动下载 Android SDK。"
    echo "  然后设置 ANDROID_HOME 环境变量。"
    exit 1
  fi
fi
echo "[3/5] Android SDK: $ANDROID_HOME"

# ---------- 4. 生成 android/ 平台目录 ----------
cd "$PROJECT_DIR"
if [[ ! -d "android" ]]; then
  echo "[4/5] 生成 android/ 平台工程..."
  flutter create --platforms android --org com.radatlas .
else
  echo "[4/5] android/ 目录已存在，跳过生成"
fi

# 接受 Android 许可协议
echo "  接受 Android 许可协议..."
flutter doctor --android-licenses || true

# ---------- 5. 编译 ----------
echo "[5/5] 开始编译 $BUILD_MODE APK..."
flutter pub get
if [[ "$BUILD_MODE" == "debug" ]]; then
  flutter build apk --debug
else
  flutter build apk --release
fi

APK_PATH="build/app/outputs/flutter-apk/app-${BUILD_MODE}.apk"
echo ""
echo "================================================"
echo "  ✅ 打包成功"
echo "  APK: $PROJECT_DIR/$APK_PATH"
echo "  大小: $(ls -lh "$APK_PATH" 2>/dev/null | awk '{print $5}')"
echo "================================================"
echo ""
echo "安装到设备: adb install \"$APK_PATH\""
