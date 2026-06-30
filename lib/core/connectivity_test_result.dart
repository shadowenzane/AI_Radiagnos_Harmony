/// 连通性测试结果（AI 模型 / 知识库通用）
///
/// 用于配置页"测试连通性"按钮的返回值，包含：
/// - [success]：是否成功
/// - [statusCode]：HTTP 状态码（-1 表示网络层错误，未收到 HTTP 响应）
/// - [message]：人类可读的结果描述（成功提示 / 错误信息）
class ConnectivityTestResult {
  final bool success;
  final int statusCode;
  final String message;

  const ConnectivityTestResult({
    required this.success,
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() =>
      'ConnectivityTestResult(success=$success, statusCode=$statusCode, message=$message)';
}
