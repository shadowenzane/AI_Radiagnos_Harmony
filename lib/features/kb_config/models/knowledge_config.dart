import 'package:equatable/equatable.dart';

/// 知识库配置（不含 API Key，Key 在 SecureStorage）
///
/// 字段对齐桌面版 ai_helper.py 的知识库配置：
/// - bailian: 阿里百炼 RAG 知识库（Retrieve 接口，AccessKey/Secret 签名）
///   workspaceId(业务空间ID) + indexId(知识库ID) + accessKey/secretKey
/// - volcengine: 标准知识库（search_knowledge 模式，AK/SK 签名）
///   只保留 resource_id / collection_name + access_key / secret_key
/// - notebooklm: apiKey + fileSearchStore
class KnowledgeConfig extends Equatable {
  final String id;
  final String type;          // bailian / volcengine / notebooklm
  final String displayName;

  // ---- 阿里百炼 ----
  /// 阿里百炼业务空间 ID（Workspace ID）
  final String? workspaceId;
  /// 阿里百炼知识库 ID（Index ID）
  final String? indexId;

  // ---- 火山方舟（标准知识库：search_knowledge 模式）----
  final String? collectionName; // 知识库集合名
  final String? resourceId;   // 知识库 Resource id

  // ---- Google NotebookLM ----
  /// File Search Store ID（旧字段 corpusId 兼容）
  final String? fileSearchStore;

  final bool enabled;
  final DateTime createdAt;

  const KnowledgeConfig({
    required this.id,
    required this.type,
    required this.displayName,
    this.workspaceId,
    this.indexId,
    this.collectionName,
    this.resourceId,
    this.fileSearchStore,
    this.enabled = true,
    required this.createdAt,
  });

  KnowledgeConfig copyWith({
    String? id,
    String? type,
    String? displayName,
    String? workspaceId,
    String? indexId,
    String? collectionName,
    String? resourceId,
    String? fileSearchStore,
    bool? enabled,
    DateTime? createdAt,
    bool clearWorkspaceId = false,
    bool clearIndexId = false,
    bool clearCollectionName = false,
    bool clearResourceId = false,
    bool clearFileSearchStore = false,
  }) {
    return KnowledgeConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      workspaceId: clearWorkspaceId ? null : (workspaceId ?? this.workspaceId),
      indexId: clearIndexId ? null : (indexId ?? this.indexId),
      collectionName: clearCollectionName ? null : (collectionName ?? this.collectionName),
      resourceId: clearResourceId ? null : (resourceId ?? this.resourceId),
      fileSearchStore: clearFileSearchStore ? null : (fileSearchStore ?? this.fileSearchStore),
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory KnowledgeConfig.fromJson(Map<String, dynamic> json) {
    return KnowledgeConfig(
      id: json['id'] as String,
      type: json['type'] as String,
      displayName: json['display_name'] as String? ?? json['type'] as String,
      // 阿里百炼字段
      workspaceId: json['workspace_id'] as String?,
      indexId: json['index_id'] as String?,
      // 火山方舟字段
      collectionName: json['collection_name'] as String?,
      resourceId: json['resource_id'] as String?,
      // 兼容旧字段 corpusId → fileSearchStore
      fileSearchStore: json['file_search_store'] as String? ?? json['corpus_id'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'display_name': displayName,
        'workspace_id': workspaceId,
        'index_id': indexId,
        'collection_name': collectionName,
        'resource_id': resourceId,
        'file_search_store': fileSearchStore,
        'enabled': enabled,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id, type, displayName, workspaceId, indexId,
        collectionName, resourceId, fileSearchStore, enabled, createdAt
      ];
}
