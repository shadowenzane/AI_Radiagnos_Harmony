/// 当前平台标识（Web 端后备）
///
/// Web 端无法访问 dart:io，固定返回 'web'
String get currentPlatform => 'web';
