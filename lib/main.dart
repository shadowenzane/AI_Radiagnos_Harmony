import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/exam_prefs.dart';
import 'core/theme_prefs.dart';
import 'features/ai_config/repositories/ai_config_repo.dart';
import 'features/kb_config/repositories/kb_config_repo.dart';
import 'features/notes/repositories/notes_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 启用 edge-to-edge 布局：让 App 内容延伸到系统导航栏后方，
  // 消除底部不随主题变化的白边
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );

  // 初始化配置仓库（内部会读取本地存储）
  final aiConfigRepo = AiConfigRepo();
  final kbConfigRepo = KbConfigRepo();
  final themePrefs = ThemePrefs();
  final examPrefs = ExamPrefs();
  final notesRepo = NotesRepo();
  await aiConfigRepo.initialize();
  await kbConfigRepo.initialize();
  await themePrefs.initialize();
  await examPrefs.initialize();
  await notesRepo.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AiConfigRepo>.value(value: aiConfigRepo),
        ChangeNotifierProvider<KbConfigRepo>.value(value: kbConfigRepo),
        ChangeNotifierProvider<ThemePrefs>.value(value: themePrefs),
        ChangeNotifierProvider<ExamPrefs>.value(value: examPrefs),
        ChangeNotifierProvider<NotesRepo>.value(value: notesRepo),
      ],
      child: const AIRadiagnosApp(),
    ),
  );
}
