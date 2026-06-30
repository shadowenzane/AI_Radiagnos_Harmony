# AI_Radiagnos — 快速开始

## 当前可用产物

| 产物 | 路径 | 状态 |
|------|------|------|
| Web 版本 | `build/web/index.html` | ✅ 已编译 |
| Android APK | `build/app/outputs/flutter-apk/app-release.apk` | ⏳ 编译中 |
| HarmonyOS HAP | — | 📋 需用户在 DevEco Studio 编译 |

## Web 版本即时预览

Web 版本无需安装任何 SDK，三端 UI 完全一致，适合快速验证。

```bash
# 启动本地预览服务器
cd D:/codes/Buddy/AI_Radigno/build/web
python -m http.server 8080
```

浏览器打开 http://localhost:8080 即可。

## Android APK 安装

编译完成后：

```bash
# 方式 1: adb 安装（需开启 USB 调试）
adb install build/app/outputs/flutter-apk/app-release.apk

# 方式 2: 复制到手机安装
# 把 app-release.apk 拷贝到手机，文件管理器点击安装
```

## 环境变量配置（如需重新编译）

如果在新终端中重新编译，需要设置以下环境变量：

```powershell
# PowerShell
$env:JAVA_HOME = "C:\Users\34368\jdk17"
$env:ANDROID_HOME = "C:\Users\34368\android-sdk"
$env:ANDROID_SDK_ROOT = "C:\Users\34368\android-sdk"
$env:PATH = "C:\Users\34368\jdk17\bin;C:\Users\34368\AppData\Local\Temp\flutter-sdk\flutter\bin;$env:PATH"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:GIT_SSL_NO_REVOKE = "1"
```

```bash
# Git Bash
export JAVA_HOME="/c/Users/34368/jdk17"
export ANDROID_HOME="/c/Users/34368/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="/c/Users/34368/jdk17/bin:/c/Users/34368/AppData/Local/Temp/flutter-sdk/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export GIT_SSL_NO_REVOKE=1
```

## 重新编译命令

```bash
cd D:/codes/Buddy/AI_Radigno

# Web 版本（最快，~1 分钟）
flutter build web --release

# Android APK（~5 分钟）
flutter build apk --release

# Android debug APK（更快，适合测试）
flutter build apk --debug
```

## HarmonyOS 打包

HarmonyOS 需要华为官方 Flutter 鸿蒙分支，详见 `docs/PACKAGING.md` 的"HarmonyOS 打包"章节。

简要说三步：
1. 克隆 `https://gitcode.com/openharmony-sig/flutter_flutter.git` 并切到 `ohos-dev` 分支
2. `OHOS_FLUTTER=路径 bash scripts/build_harmony.sh`
3. 在 DevEco Studio 中配置签名后 `flutter build hap --release`
