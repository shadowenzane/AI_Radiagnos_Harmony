import 'package:flutter/material.dart';
import 'config_storage.dart';

/// 主题与字体偏好仓库（ChangeNotifier）
///
/// 持久化用户选择：
/// - [themeMode]：系统跟随 / 亮色 / 暗色
/// - [themeSeedKey]：主题色预设 key（见 [ThemePresets.all]）
/// - [fontFamilyKey]：字体族（system / serif / mono）
/// - [textScale]：字号缩放系数
///
/// 修改任一字段都会自动持久化 + 通知 UI 重建。
class ThemePrefs extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _themeSeedKey = 'medical_blue';
  String _fontFamilyKey = 'system';
  double _textScale = 1.0;

  ThemeMode get themeMode => _themeMode;
  String get themeSeedKey => _themeSeedKey;
  String get fontFamilyKey => _fontFamilyKey;
  double get textScale => _textScale;

  Future<void> initialize() async {
    final modeStr = await ConfigStorage.loadThemeMode();
    _themeMode = switch (modeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _themeSeedKey = await ConfigStorage.loadThemeSeed();
    _fontFamilyKey = await ConfigStorage.loadFontFamily();
    _textScale = await ConfigStorage.loadTextScale();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final modeStr = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await ConfigStorage.saveThemeMode(modeStr);
    notifyListeners();
  }

  Future<void> setThemeSeed(String key) async {
    if (_themeSeedKey == key) return;
    _themeSeedKey = key;
    await ConfigStorage.saveThemeSeed(key);
    notifyListeners();
  }

  Future<void> setFontFamily(String key) async {
    if (_fontFamilyKey == key) return;
    _fontFamilyKey = key;
    await ConfigStorage.saveFontFamily(key);
    notifyListeners();
  }

  Future<void> setTextScale(double scale) async {
    if ((_textScale - scale).abs() < 0.001) return;
    _textScale = scale;
    await ConfigStorage.saveTextScale(scale);
    notifyListeners();
  }
}
