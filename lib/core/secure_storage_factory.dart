import 'package:flutter/foundation.dart';
import 'secure_storage_interface.dart';
import 'secure_storage_io.dart';
import 'secure_storage_ohos.dart';
import 'platform_detector_io.dart' if (dart.library.html) 'platform_detector_web.dart';

/// 根据当前平台返回对应的 SecureStorageBackend 实现
///
/// - Android / iOS / 其它: SecureStorageIo (flutter_secure_storage)
/// - HarmonyOS: SecureStorageOhos (shared_preferences 后备)
///
/// 鸿蒙判断：ohos flutter (flutter_flutter_ohos) 在 dart:io 的
/// Platform.operatingSystem 返回 'ohos'。Web 端走 platform_detector_web。
SecureStorageBackend createSecureStorageBackend() {
  if (kIsWeb || currentPlatform == 'web') {
    return SecureStorageIo();
  }
  if (currentPlatform == 'ohos') {
    return SecureStorageOhos();
  }
  return SecureStorageIo();
}
