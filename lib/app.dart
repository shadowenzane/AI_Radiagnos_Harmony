import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/theme_prefs.dart';
import 'features/diagnosis/pages/home_page.dart';
import 'features/ai_config/pages/ai_config_page.dart';
import 'features/help/pages/help_page.dart';
import 'features/kb_config/pages/kb_config_page.dart';
import 'features/notes/pages/notes_list_page.dart';
import 'features/settings/pages/settings_page.dart';

class AIRadiagnosApp extends StatelessWidget {
  const AIRadiagnosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<ThemePrefs>();

    final isDark = prefs.themeMode == ThemeMode.dark ||
        (prefs.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    // 系统导航栏与状态栏样式跟随主题，消除底部白边
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ));

    return MaterialApp(
      title: 'AI_Radiagnos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightFor(
        seedKey: prefs.themeSeedKey,
        fontFamilyKey: prefs.fontFamilyKey,
      ),
      darkTheme: AppTheme.darkFor(
        seedKey: prefs.themeSeedKey,
        fontFamilyKey: prefs.fontFamilyKey,
      ),
      themeMode: prefs.themeMode,
      // 字号缩放：影响全 App 文本
      builder: (context, child) {
        final prefs = context.read<ThemePrefs>();
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(prefs.textScale),
          ),
          child: child!,
        );
      },
      home: const HomePage(),
      routes: {
        '/ai-config': (ctx) => const AiConfigPage(),
        '/kb-config': (ctx) => const KbConfigPage(),
        '/settings': (ctx) => const SettingsPage(),
        '/notes': (ctx) => const NotesListPage(),
        '/help': (ctx) => const HelpPage(),
      },
    );
  }
}
