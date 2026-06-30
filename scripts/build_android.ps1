# =============================================================================
# AI_Radiagnos — Android 一键打包脚本（PowerShell 版）
# =============================================================================
# 功能：
#   1. 检查 / 自动准备 Flutter SDK
#   2. 检查 / 自动准备 JDK 17
#   3. 检查 / 自动准备 Android SDK（cmdline-tools + platform-tools + build-tools）
#   4. 生成 android/ 平台工程
#   5. 编译 release APK
#
# 用法：
#  powershell -ExecutionPolicy Bypass -File scripts\build_android.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\build_android.ps1 -BuildMode debug
# =============================================================================
param(
    [ValidateSet('release','debug')]
    [string]$BuildMode = 'release',

    [string]$FlutterDir = "$env:USERPROFILE\flutter-sdk",

    [string]$JdkDir = "$env:USERPROFILE\jdk17",

    [string]$AndroidSdkDir = "$env:USERPROFILE\android-sdk"
)

$ErrorActionPreference = 'Stop'
$ProjectDir = (Resolve-Path "$PSScriptRoot\..").Path

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  AI_Radiagnos · Android 打包" -ForegroundColor Cyan
Write-Host "  模式: $BuildMode" -ForegroundColor Cyan
Write-Host "  项目: $ProjectDir" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# ---------- 1. Flutter SDK ----------
$FlutterBin = Join-Path $FlutterDir "flutter\bin\flutter.bat"
if (-not (Test-Path $FlutterBin)) {
    Write-Host "[1/5] 未找到 Flutter SDK，开始下载到 $FlutterDir ..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $FlutterDir | Out-Null
    $zipUrl = "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.27.0-stable.zip"
    $zipPath = "$env:TEMP\flutter.zip"
    Write-Host "  下载: $zipUrl"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "  解压..."
    Expand-Archive -Path $zipPath -DestinationPath $FlutterDir -Force
    # 解压后 flutter/ 在 $FlutterDir\flutter\，移到 $FlutterDir 根
    $inner = Join-Path $FlutterDir "flutter"
    if (Test-Path $inner) {
        Get-ChildItem $inner | Move-Item -Destination $FlutterDir -Force
        Remove-Item $inner -Force -Recurse
    }
    Remove-Item $zipPath -Force
    Write-Host "  Flutter SDK 安装完成" -ForegroundColor Green
} else {
    Write-Host "[1/5] Flutter SDK 已存在: $FlutterDir" -ForegroundColor Green
}

$env:PATH = "$FlutterDir\flutter\bin;$env:PATH"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:GIT_SSL_NO_REVOKE = "1"

Write-Host "  Flutter 版本:"
& flutter --version 2>&1 | Select-Object -First 1

# ---------- 2. JDK 17 ----------
$JavaExe = Join-Path $JdkDir "bin\java.exe"
if (-not (Test-Path $JavaExe)) {
    # 先看系统是否已装
    $sysJava = Get-Command java -ErrorAction SilentlyContinue
    if ($sysJava -and (& java -version 2>&1 | Select-String 'version "17')) {
        $env:JAVA_HOME = Split-Path (Split-Path $sysJava.Source)
        Write-Host "[2/5] 使用系统 Java: $($sysJava.Source)" -ForegroundColor Green
    } else {
        Write-Host "[2/5] 未找到 JDK 17，开始下载到 $JdkDir ..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Force -Path $JdkDir | Out-Null
        $zipUrl = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.13%2B11/OpenJDK17U-jdk_x64_windows_hotspot_17.0.13_11.zip"
        $zipPath = "$env:TEMP\jdk17.zip"
        Write-Host "  下载: $zipUrl（约 180MB）"
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        } catch {
            # SSL 吊销检查失败时降级
            Write-Host "  SSL 校验失败，重试（跳过吊销检查）..."
            [Net.ServicePointManager]::ServerCertificateValidationCallback = $null
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -SkipCertificateCheck
        }
        Write-Host "  解压..."
        Expand-Archive -Path $zipPath -DestinationPath $JdkDir -Force
        # 解压后是 jdk-17.0.13+11\ 目录，把内容提到 $JdkDir 根
        $inner = Get-ChildItem $JdkDir -Directory | Where-Object { $_.Name -like 'jdk-17*' } | Select-Object -First 1
        if ($inner) {
            Get-ChildItem $inner.FullName | Move-Item -Destination $JdkDir -Force
            Remove-Item $inner.FullName -Force -Recurse
        }
        Remove-Item $zipPath -Force
        $env:JAVA_HOME = $JdkDir
        Write-Host "  JDK 17 安装完成" -ForegroundColor Green
    }
} else {
    $env:JAVA_HOME = $JdkDir
    Write-Host "[2/5] JDK 17 已存在: $JdkDir" -ForegroundColor Green
}

$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Write-Host "  Java 版本:"
& java -version 2>&1 | Select-Object -First 1

# ---------- 3. Android SDK ----------
$env:ANDROID_HOME = $AndroidSdkDir
$env:ANDROID_SDK_ROOT = $AndroidSdkDir

$SdkManager = Join-Path $AndroidSdkDir "cmdline-tools\latest\bin\sdkmanager.bat"
if (-not (Test-Path $SdkManager)) {
    Write-Host "[3/5] 未找到 Android cmdline-tools，开始下载..." -ForegroundColor Yellow
    $cmdlineDir = Join-Path $AndroidSdkDir "cmdline-tools"
    New-Item -ItemType Directory -Force -Path $cmdlineDir | Out-Null
    $zipUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    $zipPath = "$env:TEMP\android-cmdline.zip"
    Write-Host "  下载: $zipUrl（约 147MB）"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "  解压..."
    Expand-Archive -Path $zipPath -DestinationPath $cmdlineDir -Force
    # 重命名为 latest
    $inner = Join-Path $cmdlineDir "cmdline-tools"
    if (Test-Path $inner) {
        Move-Item $inner (Join-Path $cmdlineDir "latest")
    }
    Remove-Item $zipPath -Force
    Write-Host "  cmdline-tools 安装完成" -ForegroundColor Green
} else {
    Write-Host "[3/5] Android cmdline-tools 已存在" -ForegroundColor Green
}

# 接受许可 + 安装平台-tools、build-tools、platforms
Write-Host "  检查/安装 platform-tools、build-tools;34.0.0、platforms;android-34..."
$acceptLicenses = "y`n" * 20
$packages = @("platform-tools", "build-tools;34.0.0", "platforms;android-34")
$acceptLicenses | & $SdkManager --licenses 2>&1 | Out-Null
foreach ($pkg in $packages) {
    Write-Host "    检查 $pkg ..."
    $acceptLicenses | & $SdkManager $pkg 2>&1 | Select-Object -Last 2
}

# ---------- 4. 生成 android/ 平台目录 ----------
Set-Location $ProjectDir
if (-not (Test-Path "android")) {
    Write-Host "[4/5] 生成 android/ 平台工程..." -ForegroundColor Yellow
    & flutter create --platforms android --org com.radatlas . 2>&1 | Select-Object -Last 3
} else {
    Write-Host "[4/5] android/ 目录已存在" -ForegroundColor Green
}

# ---------- 4.1 配置国内镜像（避免 Gradle/Maven 下载失败）----------
Write-Host "  配置国内镜像（Gradle/Maven）..." -ForegroundColor Yellow

# gradle-wrapper.properties → 腾讯云 Gradle 镜像
$gradleWrapperProps = "android\gradle\wrapper\gradle-wrapper.properties"
if (Test-Path $gradleWrapperProps) {
    $content = Get-Content $gradleWrapperProps -Raw
    if ($content -match 'services\.gradle\.org') {
        $content = $content -replace 'https\\://services\.gradle\.org/distributions/', 'https\://mirrors.cloud.tencent.com/gradle/'
        Set-Content -Path $gradleWrapperProps -Value $content -NoNewline
        Write-Host "    ✓ gradle-wrapper.properties → 腾讯云镜像" -ForegroundColor Green
    }
}

# settings.gradle / build.gradle → 阿里云 Maven 镜像
$mirrorSnippet = "        maven { url 'https://maven.aliyun.com/repository/google' }`n        maven { url 'https://maven.aliyun.com/repository/public' }`n        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }`n"

foreach ($gradleFile in @("android\settings.gradle", "android\build.gradle")) {
    if (Test-Path $gradleFile) {
        $content = Get-Content $gradleFile -Raw
        if ($content -notmatch 'maven\.aliyun\.com') {
            $content = $content -replace 'repositories \{', "repositories {`n$mirrorSnippet"
            Set-Content -Path $gradleFile -Value $content -NoNewline
            Write-Host "    ✓ $gradleFile → 阿里云 Maven 镜像" -ForegroundColor Green
        }
    }
}

# ---------- 5. 编译 ----------
Write-Host "[5/5] 开始编译 $BuildMode APK..." -ForegroundColor Yellow
& flutter pub get
if ($BuildMode -eq 'debug') {
    & flutter build apk --debug
} else {
    & flutter build apk --release
}

$ApkPath = "build\app\outputs\flutter-apk\app-$BuildMode.apk"
$ApkFull = Join-Path $ProjectDir $ApkPath
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  ✅ 打包成功" -ForegroundColor Green
Write-Host "  APK: $ApkFull" -ForegroundColor Green
if (Test-Path $ApkFull) {
    $size = [math]::Round((Get-Item $ApkFull).Length / 1MB, 1)
    Write-Host "  大小: ${size} MB" -ForegroundColor Green
}
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "安装到设备: adb install `"$ApkPath`""
