import 'package:flutter/material.dart';

/// 主题预设
///
/// 分两类：
/// - 普通主题：由 [seed] 通过 ColorScheme.fromSeed 生成，背景由 M3 自动决定
/// - 阅读主题（[isReading]）：用 [lightSurface]/[darkSurface] 覆盖背景与卡片色，
///   营造纸面/护眼阅读体验（如羊皮纸、护眼暗黑）
class ThemePreset {
  final String key;
  final String name;
  final Color seed;
  /// 是否为阅读主题（覆盖背景/卡片色）
  final bool isReading;
  /// 阅读主题亮色背景（纸面色）
  final Color? lightSurface;
  /// 阅读主题亮色卡片色
  final Color? lightCard;
  /// 阅读主题暗色背景
  final Color? darkSurface;
  /// 阅读主题暗色卡片色
  final Color? darkCard;

  const ThemePreset({
    required this.key,
    required this.name,
    required this.seed,
    this.isReading = false,
    this.lightSurface,
    this.lightCard,
    this.darkSurface,
    this.darkCard,
  });
}

class ThemePresets {
  const ThemePresets._();

  static const medicalBlue =
      ThemePreset(key: 'medical_blue', name: '医学蓝', seed: Color(0xFF1565C0));
  static const eyeCareGreen =
      ThemePreset(key: 'eye_care_green', name: '护眼绿', seed: Color(0xFF2E7D32));
  static const warmOrange =
      ThemePreset(key: 'warm_orange', name: '暖橙', seed: Color(0xFFE65100));
  static const elegantPurple =
      ThemePreset(key: 'elegant_purple', name: '典雅紫', seed: Color(0xFF6A1B9A));
  static const freshCyan =
      ThemePreset(key: 'fresh_cyan', name: '清新青', seed: Color(0xFF00838F));

  // ---- 阅读主题 ----
  /// 羊皮纸：暖米色纸面，模拟古籍纸张，长时间阅读不刺眼
  static const parchment = ThemePreset(
    key: 'parchment',
    name: '羊皮纸',
    seed: Color(0xFF6D5B3D),
    isReading: true,
    lightSurface: Color(0xFFF3E9D2), // 羊皮纸主背景
    lightCard: Color(0xFFFBF5E6),    // 卡片比背景略亮
    darkSurface: Color(0xFF2A2419),
    darkCard: Color(0xFF332C1F),
  );
  /// 米白纸：纯净的米白阅读底，接近Kindle
  static const paperWhite = ThemePreset(
    key: 'paper_white',
    name: '米白纸',
    seed: Color(0xFF455A64),
    isReading: true,
    lightSurface: Color(0xFFF7F4EE),
    lightCard: Color(0xFFFFFBF5),
    darkSurface: Color(0xFF202020),
    darkCard: Color(0xFF2A2A2A),
  );
  /// 墨韵黑：暖调暗色，护眼夜读
  static const inkBlack = ThemePreset(
    key: 'ink_black',
    name: '墨韵黑',
    seed: Color(0xFF5C6BC0),
    isReading: true,
    lightSurface: Color(0xFFEDE7DC),
    lightCard: Color(0xFFF5F0E6),
    darkSurface: Color(0xFF1C1A17),
    darkCard: Color(0xFF26231E),
  );

  /// 暮光卷：暖棕纸面，仿古书卷，长时间阅读柔和
  static const twilightScroll = ThemePreset(
    key: 'twilight_scroll',
    name: '暮光卷',
    seed: Color(0xFF795548),
    isReading: true,
    lightSurface: Color(0xFFEFE4D2),
    lightCard: Color(0xFFF7EFE0),
    darkSurface: Color(0xFF241D17),
    darkCard: Color(0xFF2E251D),
  );
  /// 青瓷：冷青纸面，清雅护眼
  static const celadon = ThemePreset(
    key: 'celadon',
    name: '青瓷',
    seed: Color(0xFF4A6B6B),
    isReading: true,
    lightSurface: Color(0xFFE8EFE9),
    lightCard: Color(0xFFF1F5F1),
    darkSurface: Color(0xFF1A1F1E),
    darkCard: Color(0xFF232A28),
  );
  /// 暖砂：浅褐纸面，温润不刺眼
  static const warmSand = ThemePreset(
    key: 'warm_sand',
    name: '暖砂',
    seed: Color(0xFF8D6E63),
    isReading: true,
    lightSurface: Color(0xFFF2E9DD),
    lightCard: Color(0xFFFAF3E8),
    darkSurface: Color(0xFF211C18),
    darkCard: Color(0xFF2B241F),
  );

  static const List<ThemePreset> all = [
    medicalBlue,
    eyeCareGreen,
    warmOrange,
    elegantPurple,
    freshCyan,
    parchment,
    paperWhite,
    inkBlack,
    twilightScroll,
    celadon,
    warmSand,
  ];

  static ThemePreset byKey(String key) =>
      all.firstWhere((p) => p.key == key, orElse: () => medicalBlue);
}

/// 字体族预设
class FontFamilyPreset {
  final String key;
  final String name;
  /// 传给 ThemeData 的 fontFamily（null 表示系统默认）
  final String? fontFamily;
  const FontFamilyPreset({required this.key, required this.name, this.fontFamily});
}

class FontFamilyPresets {
  const FontFamilyPresets._();

  static const system =
      FontFamilyPreset(key: 'system', name: '系统默认', fontFamily: null);
  static const serif =
      FontFamilyPreset(key: 'serif', name: '衬线体', fontFamily: 'serif');
  static const mono =
      FontFamilyPreset(key: 'mono', name: '等宽体', fontFamily: 'monospace');

  static const List<FontFamilyPreset> all = [system, serif, mono];

  static FontFamilyPreset byKey(String key) =>
      all.firstWhere((p) => p.key == key, orElse: () => system);
}

/// 字号缩放预设（4 档）
class TextScalePreset {
  final double value;
  final String name;
  const TextScalePreset(this.value, this.name);
}

class TextScalePresets {
  const TextScalePresets._();

  static const small = TextScalePreset(0.85, '小');
  static const medium = TextScalePreset(1.0, '中');
  static const large = TextScalePreset(1.15, '大');
  static const xLarge = TextScalePreset(1.3, '超大');

  static const List<TextScalePreset> all = [small, medium, large, xLarge];

  static TextScalePreset nearest(double v) {
    TextScalePreset best = medium;
    double bestDist = (medium.value - v).abs();
    for (final p in all) {
      final d = (p.value - v).abs();
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    return best;
  }
}

/// 应用主题统一构造器
class AppTheme {
  AppTheme._();

  /// 构建 ThemeData
  /// [seedKey] 主题色预设 key（见 ThemePresets）
  /// [brightness] 亮 / 暗
  /// [fontFamilyKey] 字体族 key（见 FontFamilyPresets）
  static ThemeData build({
    required String seedKey,
    required Brightness brightness,
    required String fontFamilyKey,
  }) {
    final preset = ThemePresets.byKey(seedKey);
    final fontPreset = FontFamilyPresets.byKey(fontFamilyKey);
    final scheme = ColorScheme.fromSeed(
      seedColor: preset.seed,
      brightness: brightness,
    );

    // 阅读主题：覆盖背景与卡片色为纸面色
    final isLight = brightness == Brightness.light;
    final Color scaffoldBg = preset.isReading
        ? (isLight
            ? (preset.lightSurface ?? scheme.surface)
            : (preset.darkSurface ?? scheme.surface))
        : scheme.surface;
    final Color cardColor = preset.isReading
        ? (isLight
            ? (preset.lightCard ?? scheme.surfaceContainerHighest)
            : (preset.darkCard ?? scheme.surfaceContainerHighest))
        : (isLight
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : scheme.surfaceContainerHighest);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontPreset.fontFamily,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: scaffoldBg,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: _inputDecoration(scheme),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
          width: 0.6,
        ),
      ),
      dividerTheme: DividerThemeData(
        thickness: 0.6,
        space: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    return base;
  }

  static InputDecorationTheme _inputDecoration(ColorScheme scheme) =>
      InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.outlineVariant,
            width: 0.8,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.outlineVariant,
            width: 0.8,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 1.5,
          ),
        ),
      );

  /// 便捷 getter：基于当前 ThemePrefs 构建 light / dark
  static ThemeData lightFor({
    required String seedKey,
    required String fontFamilyKey,
  }) =>
      build(
        seedKey: seedKey,
        brightness: Brightness.light,
        fontFamilyKey: fontFamilyKey,
      );

  static ThemeData darkFor({
    required String seedKey,
    required String fontFamilyKey,
  }) =>
      build(
        seedKey: seedKey,
        brightness: Brightness.dark,
        fontFamilyKey: fontFamilyKey,
      );
}
