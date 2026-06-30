import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config_storage.dart';
import '../../../core/secure_storage.dart';
import '../models/knowledge_config.dart';

/// 知识库配置仓库（ChangeNotifier）
class KbConfigRepo extends ChangeNotifier {
  final _uuid = const Uuid();

  List<KnowledgeConfig> _configs = [];
  List<KnowledgeConfig> get configs => List.unmodifiable(_configs);

  List<KnowledgeConfig> get activeConfigs =>
      _configs.where((c) => c.enabled).toList();

  /// 当前选中的知识库 ID 列表（支持多选，1-3 个）
  final Set<String> _selectedIds = {};
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  /// 选中的知识库配置列表
  List<KnowledgeConfig> get selectedConfigs =>
      _configs.where((c) => _selectedIds.contains(c.id)).toList();

  /// 初始化
  Future<void> initialize() async {
    final jsonList = await ConfigStorage.loadKbConfigs();
    _configs = jsonList.map((j) => KnowledgeConfig.fromJson(j)).toList();
    // 加载选中的知识库 ID 列表
    final savedSelected = await ConfigStorage.loadSelectedKbIds();
    _selectedIds.clear();
    for (final id in savedSelected) {
      if (_configs.any((c) => c.id == id)) {
        _selectedIds.add(id);
      }
    }
    // 限制最多 3 个
    if (_selectedIds.length > 3) {
      _selectedIds.clear();
      _selectedIds.addAll(_configs.take(3).map((c) => c.id));
      await ConfigStorage.saveSelectedKbIds(_selectedIds.toList());
    }
    notifyListeners();
  }

  Future<KnowledgeConfig> add({
    required String type,
    required String displayName,
    String? workspaceId,
    String? indexId,
    String? collectionName,
    String? resourceId,
    String? fileSearchStore,
    required Map<String, String> credentials,
    bool enabled = true,
  }) async {
    final config = KnowledgeConfig(
      id: _uuid.v4(),
      type: type,
      displayName: displayName,
      workspaceId: workspaceId,
      indexId: indexId,
      collectionName: collectionName,
      resourceId: resourceId,
      fileSearchStore: fileSearchStore,
      enabled: enabled,
      createdAt: DateTime.now(),
    );
    _configs = [..._configs, config];
    await SecureStorage.setKbCredentials(config.id, credentials);
    await _persist();
    notifyListeners();
    return config;
  }

  Future<void> update({
    required String id,
    String? displayName,
    String? workspaceId,
    String? indexId,
    String? collectionName,
    String? resourceId,
    String? fileSearchStore,
    bool? enabled,
    Map<String, String>? credentials,
    bool clearWorkspaceId = false,
    bool clearIndexId = false,
    bool clearCollectionName = false,
    bool clearResourceId = false,
    bool clearFileSearchStore = false,
  }) async {
    _configs = _configs.map((c) {
      if (c.id != id) return c;
      return c.copyWith(
        displayName: displayName,
        workspaceId: workspaceId,
        indexId: indexId,
        collectionName: collectionName,
        resourceId: resourceId,
        fileSearchStore: fileSearchStore,
        enabled: enabled,
        clearWorkspaceId: clearWorkspaceId,
        clearIndexId: clearIndexId,
        clearCollectionName: clearCollectionName,
        clearResourceId: clearResourceId,
        clearFileSearchStore: clearFileSearchStore,
      );
    }).toList();
    if (credentials != null) {
      await SecureStorage.setKbCredentials(id, credentials);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> toggleEnabled(String id) async {
    _configs = _configs.map((c) {
      if (c.id == id) return c.copyWith(enabled: !c.enabled);
      return c;
    }).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _configs = _configs.where((c) => c.id != id).toList();
    _selectedIds.remove(id);
    await SecureStorage.deleteKbApiKey(id);
    await _persistSelection();
    await _persist();
    notifyListeners();
  }

  // ============ 多选逻辑 ============

  /// 切换选中状态（最多 3 个）
  Future<void> toggleSelection(String id) async {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      if (_selectedIds.length >= 3) return; // 最多 3 个
      _selectedIds.add(id);
    }
    await _persistSelection();
    notifyListeners();
  }

  /// 设置选中的知识库 ID 列表（0-3 个）
  Future<void> setSelectedIds(List<String> ids) async {
    _selectedIds.clear();
    _selectedIds.addAll(ids.take(3));
    await _persistSelection();
    notifyListeners();
  }

  /// 读取知识库凭证
  Future<Map<String, String>> getCredentials(String id) =>
      SecureStorage.getKbCredentials(id);

  /// 读取主 API Key（兼容旧代码）
  Future<String?> getApiKey(String id) => SecureStorage.getKbApiKey(id);

  /// 检查是否已设置 API Key
  Future<bool> hasApiKey(String id) => SecureStorage.hasKbApiKey(id);

  Future<void> _persist() async {
    final jsonList = _configs.map((c) => c.toJson()).toList();
    await ConfigStorage.saveKbConfigs(jsonList);
  }

  Future<void> _persistSelection() async {
    await ConfigStorage.saveSelectedKbIds(_selectedIds.toList());
  }
}
