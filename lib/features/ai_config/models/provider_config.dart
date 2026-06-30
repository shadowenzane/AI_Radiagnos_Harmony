import 'package:equatable/equatable.dart';

/// AI 提供商配置（不含 API Key，Key 在 SecureStorage）
class ProviderConfig extends Equatable {
  /// 唯一 ID（uuid），用于在 UI 列表中区分同一 provider 的不同账号配置
  final String id;
  final String provider;     // 对应 kProviders 的 key
  final String displayName;  // UI 显示名（如 "我的 DeepSeek"）
  final String model;        // 模型名
  final String? customApiUrl;
  final bool enabled;
  final DateTime createdAt;

  const ProviderConfig({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.model,
    this.customApiUrl,
    this.enabled = true,
    required this.createdAt,
  });

  ProviderConfig copyWith({
    String? id,
    String? provider,
    String? displayName,
    String? model,
    String? customApiUrl,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return ProviderConfig(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      displayName: displayName ?? this.displayName,
      model: model ?? this.model,
      customApiUrl: customApiUrl ?? this.customApiUrl,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    return ProviderConfig(
      id: json['id'] as String,
      provider: json['provider'] as String,
      displayName: json['display_name'] as String? ?? json['provider'] as String,
      model: json['model'] as String,
      customApiUrl: json['custom_api_url'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider,
        'display_name': displayName,
        'model': model,
        'custom_api_url': customApiUrl,
        'enabled': enabled,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, provider, displayName, model, customApiUrl, enabled, createdAt];
}
