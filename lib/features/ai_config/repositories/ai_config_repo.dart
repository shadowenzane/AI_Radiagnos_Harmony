import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config_storage.dart';
import '../../../core/secure_storage.dart';
import '../models/provider_config.dart';

/// AI 提供商配置仓库（ChangeNotifier）
///
/// 负责多模型配置的 CRUD，并同步 API Key 到 SecureStorage。
class AiConfigRepo extends ChangeNotifier {
  final _uuid = const Uuid();

  List<ProviderConfig> _providers = [];
  List<ProviderConfig> get providers => List.unmodifiable(_providers);

  /// 已启用且配置了 API Key 的提供商
  List<ProviderConfig> get activeProviders =>
      _providers.where((p) => p.enabled).toList();

  /// 初始化：从本地存储加载
  Future<void> initialize() async {
    final jsonList = await ConfigStorage.loadAiProviders();
    _providers = jsonList.map((j) => ProviderConfig.fromJson(j)).toList();
    notifyListeners();
  }

  /// 新增配置；apiKey 单独写入 SecureStorage
  Future<ProviderConfig> add({
    required String provider,
    required String displayName,
    required String model,
    String? customApiUrl,
    required String apiKey,
    bool enabled = true,
  }) async {
    final config = ProviderConfig(
      id: _uuid.v4(),
      provider: provider,
      displayName: displayName,
      model: model,
      customApiUrl: customApiUrl,
      enabled: enabled,
      createdAt: DateTime.now(),
    );
    _providers = [..._providers, config];
    await SecureStorage.setApiKey(config.id, apiKey);
    await _persist();
    notifyListeners();
    return config;
  }

  /// 更新配置（含 API Key）
  Future<void> update({
    required String id,
    String? displayName,
    String? model,
    String? customApiUrl,
    bool? enabled,
    String? apiKey,
  }) async {
    _providers = _providers.map((p) {
      if (p.id != id) return p;
      return p.copyWith(
        displayName: displayName,
        model: model,
        customApiUrl: customApiUrl,
        enabled: enabled,
      );
    }).toList();
    if (apiKey != null) {
      await SecureStorage.setApiKey(id, apiKey);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> toggleEnabled(String id) async {
    _providers = _providers.map((p) {
      if (p.id == id) return p.copyWith(enabled: !p.enabled);
      return p;
    }).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _providers = _providers.where((p) => p.id != id).toList();
    await SecureStorage.deleteApiKey(id);
    await _persist();
    notifyListeners();
  }

  /// 读取某个配置的 API Key
  Future<String?> getApiKey(String id) => SecureStorage.getApiKey(id);

  /// 检查是否已设置 API Key
  Future<bool> hasApiKey(String id) => SecureStorage.hasApiKey(id);

  Future<void> _persist() async {
    final jsonList = _providers.map((p) => p.toJson()).toList();
    await ConfigStorage.saveAiProviders(jsonList);
  }

  // 兼容 jsonEncode（debug 用）
  String dump() => jsonEncode(_providers.map((p) => p.toJson()).toList());
}
