import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 非敏感配置持久化（基于 SharedPreferences）
/// 用于存储：AI 提供商列表（不含 API Key）、知识库配置（不含 API Key）
/// API Key 走 SecureStorage。
class ConfigStorage {
  static const String _kAiProvidersKey = 'ai_providers_v1';
  static const String _kKbConfigsKey = 'kb_configs_v1';
  static const String _kSelectedProvidersKey = 'selected_providers_v1';
  static const String _kSelectedKbKey = 'selected_kb_v1';
  static const String _kSelectedKbIdsKey = 'selected_kb_ids_v1';
  static const String _kThemeModeKey = 'theme_mode_v1';
  static const String _kThemeSeedKey = 'theme_seed_v1';
  static const String _kFontFamilyKey = 'font_family_v1';
  static const String _kTextScaleKey = 'text_scale_v1';
  static const String _kDefaultExamTypeKey = 'default_exam_type_v1';
  static const String _kKeywordHistoryKey = 'keyword_history_v1';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _instance() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ---------- AI 提供商列表 ----------
  /// 返回不含 API Key 的提供商列表（Key 在 SecureStorage 中）
  static Future<List<Map<String, dynamic>>> loadAiProviders() async {
    final prefs = await _instance();
    final raw = prefs.getString(_kAiProvidersKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAiProviders(List<Map<String, dynamic>> providers) async {
    final prefs = await _instance();
    await prefs.setString(_kAiProvidersKey, jsonEncode(providers));
  }

  // ---------- 知识库配置列表 ----------
  static Future<List<Map<String, dynamic>>> loadKbConfigs() async {
    final prefs = await _instance();
    final raw = prefs.getString(_kKbConfigsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveKbConfigs(List<Map<String, dynamic>> configs) async {
    final prefs = await _instance();
    await prefs.setString(_kKbConfigsKey, jsonEncode(configs));
  }

  // ---------- 选中状态 ----------
  /// 当前启用的 AI 提供商 ID 列表（用于主页快速选择）
  static Future<List<String>> loadSelectedProviderIds() async {
    final prefs = await _instance();
    return prefs.getStringList(_kSelectedProvidersKey) ?? [];
  }

  static Future<void> saveSelectedProviderIds(List<String> ids) async {
    final prefs = await _instance();
    await prefs.setStringList(_kSelectedProvidersKey, ids);
  }

  /// 当前选中的知识库 ID（单选，兼容旧版）
  static Future<String?> loadSelectedKbId() async {
    final prefs = await _instance();
    return prefs.getString(_kSelectedKbKey);
  }

  static Future<void> saveSelectedKbId(String? id) async {
    final prefs = await _instance();
    if (id == null) {
      await prefs.remove(_kSelectedKbKey);
    } else {
      await prefs.setString(_kSelectedKbKey, id);
    }
  }

  /// 当前选中的知识库 ID 列表（多选，1-3 个）
  static Future<List<String>> loadSelectedKbIds() async {
    final prefs = await _instance();
    return prefs.getStringList(_kSelectedKbIdsKey) ?? [];
  }

  static Future<void> saveSelectedKbIds(List<String> ids) async {
    final prefs = await _instance();
    await prefs.setStringList(_kSelectedKbIdsKey, ids);
  }

  // ---------- 主题与字体偏好 ----------
  /// 主题模式：'system' | 'light' | 'dark'
  static Future<String> loadThemeMode() async {
    final prefs = await _instance();
    return prefs.getString(_kThemeModeKey) ?? 'system';
  }

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await _instance();
    await prefs.setString(_kThemeModeKey, mode);
  }

  /// 主题色种子（主题预设的 key，如 'medical_blue'）
  static Future<String> loadThemeSeed() async {
    final prefs = await _instance();
    return prefs.getString(_kThemeSeedKey) ?? 'medical_blue';
  }

  static Future<void> saveThemeSeed(String seed) async {
    final prefs = await _instance();
    await prefs.setString(_kThemeSeedKey, seed);
  }

  /// 字体族：'system' | 'serif' | 'mono'
  static Future<String> loadFontFamily() async {
    final prefs = await _instance();
    return prefs.getString(_kFontFamilyKey) ?? 'system';
  }

  static Future<void> saveFontFamily(String family) async {
    final prefs = await _instance();
    await prefs.setString(_kFontFamilyKey, family);
  }

  /// 字号缩放系数：0.85 / 1.0 / 1.15 / 1.3
  static Future<double> loadTextScale() async {
    final prefs = await _instance();
    return prefs.getDouble(_kTextScaleKey) ?? 1.0;
  }

  static Future<void> saveTextScale(double scale) async {
    final prefs = await _instance();
    await prefs.setDouble(_kTextScaleKey, scale);
  }

  // ---------- 默认检查方法 ----------
  /// 默认检查方法（如 CT/X-Ray/MRI...），主页启动时默认选中
  static Future<String> loadDefaultExamType() async {
    final prefs = await _instance();
    return prefs.getString(_kDefaultExamTypeKey) ?? '';
  }

  static Future<void> saveDefaultExamType(String examType) async {
    final prefs = await _instance();
    await prefs.setString(_kDefaultExamTypeKey, examType);
  }

  // ---------- 关键字输入历史 ----------
  /// 关键字输入历史（最近 10 条，去重，新条目置顶）
  static Future<List<String>> loadKeywordHistory() async {
    final prefs = await _instance();
    return prefs.getStringList(_kKeywordHistoryKey) ?? [];
  }

  static Future<void> saveKeywordHistory(List<String> history) async {
    final prefs = await _instance();
    await prefs.setStringList(_kKeywordHistoryKey, history);
  }
}
