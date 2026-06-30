# AI_Radiagnos — 编译问题排查日志

记录在 Windows 环境下编译 Flutter Android APK 时遇到的问题和解决方案。

## 问题 1: Git SSL 证书吊销检查失败

### 症状
```
fatal: unable to access 'https://github.com/flutter/flutter.git/':
schannel: next InitializeSecurityContext failed:
CRYPT_E_NO_REVOCATION_CHECK (0x80092012) - 吊销功能无法检查证书是否吊销。
```

### 原因
Windows 的 Schannel SSL 提供器在沙盒/企业网络环境中无法访问证书吊销列表（CRL）服务器。

### 解决方案
```bash
export GIT_SSL_NO_REVOKE=1
```

或对于 curl：
```bash
curl --ssl-no-revoke ...
```

---

## 问题 2: Gradle distribution 下载失败（PKIX path building failed）

### 症状
```
sun.security.validator.ValidatorException: PKIX path building failed:
sun.security.provider.certpath.SunCertPathBuilderException:
unable to find valid certification path to requested target
```

### 原因
Gradle wrapper 下载 distribution 时，Java 的 SSL 证书验证失败。`services.gradle.org` 的证书链不在 JDK 的信任库中。

### 解决方案
修改 `android/gradle/wrapper/gradle-wrapper.properties`，使用国内镜像：
```properties
# 原始
distributionUrl=https\://services.gradle.org/distributions/gradle-8.3-all.zip
# 修改为腾讯云镜像
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-8.3-all.zip
```

---

## 问题 3: Maven 依赖下载慢/失败

### 症状
Gradle 下载 Android Gradle Plugin、Kotlin 编译器等依赖时超时或极慢。

### 解决方案
修改 `android/settings.gradle` 和 `android/build.gradle`，在 `repositories` 块最前面加入阿里云镜像：

```gradle
repositories {
    maven { url 'https://maven.aliyun.com/repository/google' }
    maven { url 'https://maven.aliyun.com/repository/public' }
    maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
    google()
    mavenCentral()
    gradlePluginPortal()
}
```

---

## 问题 4: Flutter Android engine artifacts 下载慢

### 症状
`flutter build apk` 卡在下载 Flutter engine artifacts。

### 解决方案
设置中国镜像环境变量：
```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

或预下载：
```bash
flutter precache --android
```

---

## 问题 5: ANDROID_HOME 路径格式问题

### 症状
```
X ANDROID_HOME = /c/Users/34368/android-sdk
  but Android SDK not found at this location.
```

### 原因
在 Git Bash 中执行 `flutter config --android-sdk` 时，路径被转换为 Git Bash 风格（`/c/...`），Flutter 无法识别。

### 解决方案
在 PowerShell（而非 Git Bash）中配置：
```powershell
flutter config --android-sdk "C:\Users\34368\android-sdk"
```

---

## 环境变量完整配置

### PowerShell
```powershell
$env:JAVA_HOME = "C:\Users\34368\jdk17"
$env:ANDROID_HOME = "C:\Users\34368\android-sdk"
$env:ANDROID_SDK_ROOT = "C:\Users\34368\android-sdk"
$env:PATH = "C:\Users\34368\jdk17\bin;C:\Users\34368\AppData\Local\Temp\flutter-sdk\flutter\bin;$env:PATH"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:GIT_SSL_NO_REVOKE = "1"
```

### Git Bash
```bash
export JAVA_HOME="/c/Users/34368/jdk17"
export ANDROID_HOME="/c/Users/34368/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="/c/Users/34368/jdk17/bin:/c/Users/34368/AppData/Local/Temp/flutter-sdk/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export GIT_SSL_NO_REVOKE=1
```

---

## 各组件下载源对照

| 组件 | 官方源 | 中国镜像 |
|------|--------|----------|
| Flutter SDK | storage.googleapis.com | storage.flutter-io.cn |
| Flutter engine artifacts | storage.googleapis.com | storage.flutter-io.cn |
| Dart packages (pub) | pub.dev | pub.flutter-io.cn |
| Gradle distribution | services.gradle.org | mirrors.cloud.tencent.com/gradle |
| Maven 依赖 | repo1.maven.org / dl.google.com | maven.aliyun.com |
| JDK | adoptium.net | aka.ms (Microsoft CDN) |
