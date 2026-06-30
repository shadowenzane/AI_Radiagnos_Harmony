/// 应用错误类型层级
/// 对应 fullstack-dev skill 推荐的"typed error hierarchy"。
sealed class AppError implements Exception {
  final String message;
  final String code;

  const AppError(this.message, {this.code = 'APP_ERROR'});

  @override
  String toString() => '[$code] $message';
}

/// 配置错误（如未配置 API Key）
class ConfigError extends AppError {
  const ConfigError(super.message, {super.code = 'CONFIG_ERROR'});
}

/// 网络错误（HTTP 请求失败、超时）
class NetworkError extends AppError {
  final int? statusCode;
  const NetworkError(super.message, {this.statusCode, super.code = 'NETWORK_ERROR'});
}

/// 解析错误（LLM 返回非 JSON 或字段缺失）
class ParseError extends AppError {
  const ParseError(super.message, {super.code = 'PARSE_ERROR'});
}

/// 提供商不支持错误
class ProviderNotSupportedError extends AppError {
  const ProviderNotSupportedError(String provider)
      : super('不支持的 AI 提供商: $provider', code: 'PROVIDER_NOT_SUPPORTED');
}
