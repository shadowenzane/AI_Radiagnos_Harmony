import 'dart:io' show Platform;

/// 当前平台标识（dart:io 可用平台）
///
/// 取值：'android' / 'ios' / 'ohos' / 'linux' / 'macos' / 'windows'
/// 鸿蒙 flutter (flutter_flutter_ohos) 中返回 'ohos'
String get currentPlatform => Platform.operatingSystem;
