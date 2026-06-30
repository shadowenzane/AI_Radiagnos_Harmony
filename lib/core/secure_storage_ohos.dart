import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_interface.dart';

/// HarmonyOS 平台实现：基于 shared_preferences 后备
///
/// flutter_secure_storage 鸿蒙分支的 SDK 约束 <3.0.0，与 Dart 3.6 不兼容。
/// 鸿蒙端暂用 SharedPreferences 存储 API Key 等凭证。
///
/// 安全性说明：
/// - 鸿蒙 SharedPreferences 数据存储在应用沙箱内，其它应用无法直接访问
/// - root 设备或调试模式下仍可被读取，敏感数据建议未来迁移到 HUKS
class SecureStorageOhos implements SecureStorageBackend {
  static const _prefix = 'secstore_';

  Future<SharedPreferences> _getSp() => SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async {
    final sp = await _getSp();
    return sp.getString('$_prefix$key');
  }

  @override
  Future<void> write(String key, String value) async {
    final sp = await _getSp();
    await sp.setString('$_prefix$key', value);
  }

  @override
  Future<void> delete(String key) async {
    final sp = await _getSp();
    await sp.remove('$_prefix$key');
  }
}
