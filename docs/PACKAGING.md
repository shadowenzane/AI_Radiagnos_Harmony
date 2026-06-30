# AI_Radiagnos — 打包指南

本指南介绍如何将 AI_Radiagnos 打包到 **Android** 和 **HarmonyOS** 平台，以及如何快速编译 **Web 版本**用于即时演示。

## 快速开始（三选一）

| 平台 | 命令 | 产物 | 耗时 |
|------|------|------|------|
| **Web**（最快） | `flutter build web --release` | `build/web/index.html` | ~1 分钟 |
| **Android** | `bash scripts/build_android.sh` 或 `powershell -File scripts/build_android.ps1` | `build/app/outputs/flutter-apk/app-release.apk` | ~5 分钟 |
| **HarmonyOS** | `OHOS_FLUTTER=路径 bash scripts/build_harmony.sh` | `build/app/outputs/hap/release/entry-default-signed.hap` | ~5 分钟 |

Web 版本无需任何额外 SDK，适合快速验证 UI 和交互；Android/HarmonyOS 需要对应平台 SDK。

---

## 零、Web 版本（即时演示）

### 编译
```bash
cd D:/codes/Buddy/AI_Radigno
flutter build web --release
```

### 本地预览
```bash
cd build/web
python -m http.server 8080
# 浏览器打开 http://localhost:8080
```

### 注意事项
- Web 版本的 `flutter_secure_storage` 使用浏览器 localStorage（不加密），仅用于演示
- `url_launcher` 在 Web 上通过 `window.open` 实现，可能被弹窗拦截器拦截
- 三端 UI 完全一致，Web 版本可完整体验所有功能

---

## 一、Android 打包

### 方式 A：一键脚本（推荐）

```bash
# 进入项目目录
cd D:/codes/Buddy/AI_Radigno

# 编译 release APK（自动检查/安装 Flutter SDK）
bash scripts/build_android.sh

# 或编译 debug APK（更快，适合测试）
bash scripts/build_android.sh --debug
```

脚本会自动：
1. 下载 Flutter SDK 到 `~/flutter-sdk`（如未安装）
2. 检查 Java 和 Android SDK
3. 生成 `android/` 平台工程
4. 执行 `flutter build apk`

产出位置：`build/app/outputs/flutter-apk/app-release.apk`

### 方式 B：手动步骤

#### 1. 安装前置依赖

| 依赖 | 版本 | 下载地址 |
|------|------|----------|
| Flutter SDK | ≥ 3.13 | https://flutter.dev/docs/get-started/install/windows |
| Java JDK | 17+ | https://adoptium.net/ |
| Android SDK | API 34 | 通过 Android Studio 安装 |

#### 2. 配置中国镜像（可选，加速下载）

```bash
# 在系统环境变量中设置
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

#### 3. 生成 Android 工程

```bash
cd D:/codes/Buddy/AI_Radigno
flutter create --platforms android --org com.radatlas .
```

#### 4. 编译

```bash
flutter pub get
flutter build apk --release     # release 包
flutter build apk --debug       # debug 包
flutter build appbundle --release  # 上架 Google Play 用
```

#### 5. 安装到设备

```bash
# 开启 USB 调试后
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 签名配置（可选）

默认使用 debug 签名，测试够用。如需 release 签名上架：

1. 生成 keystore：
```bash
keytool -genkey -v -keystore ~/radatlas.jks -keyalg RSA -keysize 2048 -validity 10000 -alias radatlas
```

2. 在 `android/key.properties` 创建：
```properties
storePassword=你的密码
keyPassword=你的密码
keyAlias=radatlas
storeFile=/Users/你的用户名/radatlas.jks
```

3. 修改 `android/app/build.gradle`，在 `android {` 块内加入：
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

---

## 二、HarmonyOS 打包

HarmonyOS 需要使用**华为官方维护的 Flutter 鸿蒙分支**（不是官方 Flutter），并配合 DevEco Studio。

### 前置准备

| 依赖 | 说明 | 下载 |
|------|------|------|
| flutter_flutter_ohos | 华为官方 Flutter 鸿蒙分支 | `git clone https://gitcode.com/openharmony-sig/flutter_flutter.git` |
| DevEco Studio | 鸿蒙官方 IDE（含 SDK + hvigor） | https://developer.harmonyos.com/cn/develop/deveco-studio/ |
| Java JDK | 17+ | https://adoptium.net/ |

### 方式 A：一键脚本

```bash
# 先克隆鸿蒙 Flutter 分支
git clone https://gitcode.com/openharmony-sig/flutter_flutter.git ~/flutter_flutter_ohos
cd ~/flutter_flutter_ohos && git checkout ohos-dev

# 指定鸿蒙 Flutter 路径并打包
OHOS_FLUTTER=~/flutter_flutter_ohos bash scripts/build_harmony.sh

# debug 模式
OHOS_FLUTTER=~/flutter_flutter_ohos bash scripts/build_harmony.sh --debug
```

产出位置：`build/app/outputs/hap/release/entry-default-signed.hap`

### 方式 B：手动步骤

#### 1. 安装鸿蒙 Flutter

```bash
git clone https://gitcode.com/openharmony-sig/flutter_flutter.git
cd flutter_flutter
git checkout ohos-dev
export PATH="$PWD/bin:$PATH"
flutter --version  # 应显示 ohos channel
```

#### 2. 生成 ohos 工程

```bash
cd D:/codes/Buddy/AI_Radigno
flutter create --platforms ohos --org com.radatlas .
```

#### 3. 配置签名（DevEco Studio）

1. 用 DevEco Studio 打开 `ohos/` 目录
2. `File → Project Structure → Signing Configs`
3. 选择 `Automatically generate signature`（测试用）或导入自有证书

#### 4. 编译

```bash
flutter pub get
flutter build hap --release
```

或在 DevEco Studio 中：`Build → Build Hap(s)/APP(s) → Build Hap(s)`

#### 5. 安装到真机

```bash
hdc install build/app/outputs/hap/release/entry-default-signed.hap
```

### HarmonyOS 注意事项

1. **签名是硬要求**：未签名的 hap 无法安装到真机。最便捷的方式是用 DevEco Studio 自动生成调试签名。
2. **首次 SDK 同步**：第一次打开 `ohos/` 目录时 DevEco Studio 会下载 HarmonyOS SDK，需联网。
3. **真机需开启开发者模式**：设置 → 关于本机 → 软件版本连点 7 次 → 开发者选项 → USB 调试。

---

## 三、环境检查

运行以下命令一次性检查所有依赖：

```bash
flutter doctor -v
```

理想输出应全部为 `[✓]`：
```
[✓] Flutter (Channel stable, 3.27.0, on Microsoft Windows)
[✓] Windows Version (Windows 10 or higher)
[✓] Android toolchain (Android SDK 34.0.0)
[✓] Chrome - develop for the web
[✓] Android Studio (version 2024.1)
[✓] Connected device (1 available)
```

HarmonyOS 端额外检查（使用鸿蒙 Flutter 分支时）：
```bash
flutter doctor -v  # 应多出 [✓] HarmonyOS SDK 一项
```

---

## 四、常见问题

### Q: `flutter build apk` 报 `Could not resolve all files for configuration ':classpath'`
A: Gradle 下载失败，修改 `android/build.gradle` 的 repositories 为中国镜像：
```gradle
maven { url 'https://maven.aliyun.com/repository/google' }
maven { url 'https://maven.aliyun.com/repository/public' }
maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
```

### Q: 下载 Flutter SDK 太慢
A: 使用中国镜像 `https://storage.flutter-io.cn/` 替代 `https://storage.googleapis.com/`。

### Q: HarmonyOS 打包报 `No signed hap found`
A: 未配置签名。用 DevEco Studio 打开 `ohos/` 目录，在 Project Structure 中配置 Signing Configs。

### Q: `flutter create --platforms ohos .` 报 `Platform "ohos" is not a valid platform`
A: 你用的是官方 Flutter，需要切换到华为鸿蒙分支 `flutter_flutter_ohos`。
