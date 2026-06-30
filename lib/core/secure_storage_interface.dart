/// 跨平台安全存储抽象接口
///
/// 用于解耦 SecureStorage 与具体平台实现：
/// - Android/iOS: flutter_secure_storage（Keychain/Keystore）
/// - HarmonyOS: shared_preferences（鸿蒙端无兼容的 secure_storage，用 SP 后备）
abstract class SecureStorageBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
