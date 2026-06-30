import 'dart:convert';
import 'secure_storage_interface.dart';
import 'secure_storage_factory.dart';

/// API Key 等敏感信息的安全存储（跨平台抽象）
///
/// 三端实现：
/// - iOS: Keychain（SecureStorageIo → flutter_secure_storage）
/// - Android: EncryptedSharedPreferences + Keystore（SecureStorageIo → flutter_secure_storage）
/// - HarmonyOS: 应用沙箱内 SharedPreferences（SecureStorageOhos，后备方案）
/// - Web: flutter_secure_storage 的 web 实现（仅用于测试，非真正加密）
class SecureStorage {
  static final SecureStorageBackend _backend = createSecureStorageBackend();

  // ============ AI 提供商 API Key ============

  /// 按 "provider_id" 维度存储 API Key
  static Future<String?> getApiKey(String keyId) async {
    return _backend.read('apikey_$keyId');
  }

  static Future<void> setApiKey(String keyId, String apiKey) async {
    await _backend.write('apikey_$keyId', apiKey);
  }

  static Future<void> deleteApiKey(String keyId) async {
    await _backend.delete('apikey_$keyId');
  }

  /// 检查 API Key 是否已设置（不读取值，仅判断存在性）
  static Future<bool> hasApiKey(String keyId) async {
    final val = await _backend.read('apikey_$keyId');
    return val != null && val.isNotEmpty;
  }

  // ============ 知识库凭证 ============
  //
  // 知识库可能需要多组凭证（如阿里百炼需要 accessKey + secretKey，
  // 火山方舟需要 accessKey + secretKey，Gemini 需要 apiKey）。
  // 以 JSON blob 形式存储，避免 key 爆炸。

  /// 读取知识库的所有凭证
  ///
  /// 返回 Map，可能包含：
  /// - api_key: 主 API Key（Gemini apiKey 等）
  /// - secret_key: 火山方舟/阿里百炼 secretKey
  /// - access_key: 火山方舟/阿里百炼 accessKey
  static Future<Map<String, String>> getKbCredentials(String kbId) async {
    final raw = await _backend.read('kbcred_$kbId');
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      // 兼容旧格式：纯字符串即为 api_key
      return {'api_key': raw};
    }
  }

  /// 写入知识库凭证
  static Future<void> setKbCredentials(String kbId, Map<String, String> creds) async {
    await _backend.write('kbcred_$kbId', jsonEncode(creds));
  }

  /// 便捷方法：仅读写主 API Key（兼容旧代码）
  static Future<String?> getKbApiKey(String kbId) async {
    final creds = await getKbCredentials(kbId);
    return creds['api_key'];
  }

  static Future<void> setKbApiKey(String kbId, String apiKey) async {
    final creds = await getKbCredentials(kbId);
    creds['api_key'] = apiKey;
    await setKbCredentials(kbId, creds);
  }

  /// 检查知识库是否已设置主 API Key
  static Future<bool> hasKbApiKey(String kbId) async {
    final creds = await getKbCredentials(kbId);
    final key = creds['api_key'];
    return key != null && key.isNotEmpty;
  }

  static Future<void> deleteKbApiKey(String kbId) async {
    await _backend.delete('kbcred_$kbId');
  }
}
