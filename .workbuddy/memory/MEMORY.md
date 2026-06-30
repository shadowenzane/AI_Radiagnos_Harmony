# AI_Radigno 项目长期记忆

## 项目定位
RadAtlas 移动端 — 跨平台（Android / iOS / HarmonyOS）AI 影像辅助诊断 App。
基于桌面版 `D:\codes\RadAtlas_Desktop-master\ai_helper.py` 原型重构，下沉到移动端。

## 技术栈
- **框架**：Flutter (Dart)，选择理由是鸿蒙有华为官方 `flutter_flutter_ohos` 分支
- **状态管理**：Provider
- **存储**：shared_preferences（非敏感）+ flutter_secure_storage（API Key 加密）
- **架构**：feature-first + 三层（pages / services / repositories）

## 关键约束
- 工作目录：`D:\codes\Buddy\AI_Radigno`
- 桌面版原型参考路径：`D:\codes\RadAtlas_Desktop-master\ai_helper.py`
- API Key 必须走 SecureStorage，不能明文存储或日志输出
- LLM 三种 API 协议并存：chat_completions（OpenAI 兼容）/ responses（豆包）/ gemini（generateContent）

## 已交付内容（2026-06-22）
- ADR-001 架构决策记录
- 完整 Flutter 项目骨架（pubspec.yaml + main.dart + app.dart + theme + errors）
- core 层：constants / config_storage / secure_storage
- features/ai_config：ProviderConfig 模型 + AiConfigRepo + AiConfigPage
- features/kb_config：KnowledgeConfig 模型 + KbConfigRepo + KbConfigPage
- features/diagnosis：DiagnosisItem / KbDocSnapshot 模型 + LlmService / KnowledgeBaseService / DiagnosisService 服务层 + HomePage / DiagnosisResultPage / DiseaseDetailPage
- README.md + overview.md + .gitignore

## v1.1 界面优化（2026-06-22）
- 新增 core/theme_prefs.dart：ThemePrefs（ChangeNotifier）持久化主题/字体/字号偏好
- 重构 core/theme.dart：5 种主题色 + 3 种字体族 + 4 档字号缩放
- 新增 features/settings/pages/settings_page.dart：主题色板 + SegmentedButton 模式/字体 + 字号滑块（带预览）
- 主页改为卡片分组（欢迎区/查询条件/AI模型/知识库），统一 colorScheme 用色
- app.dart 用 Consumer<ThemePrefs> 动态切换；builder 包 MediaQuery 应用 textScaler
- 主题/字体偏好持久化键统一走 ConfigStorage，避免散落

## 待办与已知限制
- 诊断历史未持久化（需引入 sqflite）
- LLM 未走 SSE 流式
- HarmonyOS 端未实机测试（需在 DevEco Studio 完成签名）
- 报告模板暂未支持 PDF / Word 导出
