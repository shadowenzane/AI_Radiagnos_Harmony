// AI_Radiagnos 基础冒烟测试
//
// 验证 App 能正常启动并显示主页标题

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:radatlas_mobile/app.dart';
import 'package:radatlas_mobile/core/theme_prefs.dart';
import 'package:radatlas_mobile/features/ai_config/repositories/ai_config_repo.dart';
import 'package:radatlas_mobile/features/kb_config/repositories/kb_config_repo.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App 启动并显示主页标题', (WidgetTester tester) async {
    // 初始化 SharedPreferences 测试 mock
    SharedPreferences.setMockInitialValues({});

    final aiConfigRepo = AiConfigRepo();
    final kbConfigRepo = KbConfigRepo();
    final themePrefs = ThemePrefs();
    await aiConfigRepo.initialize();
    await kbConfigRepo.initialize();
    await themePrefs.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AiConfigRepo>.value(value: aiConfigRepo),
          ChangeNotifierProvider<KbConfigRepo>.value(value: kbConfigRepo),
          ChangeNotifierProvider<ThemePrefs>.value(value: themePrefs),
        ],
        child: const AIRadiagnosApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 验证主页标题显示
    expect(find.text('AI_Radiagnos'), findsOneWidget);
    expect(find.text('AI 影像辅助诊断'), findsOneWidget);
  });
}
