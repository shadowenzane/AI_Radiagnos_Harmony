# AI_Radiagnos — 项目概览

## 已完成工作
基于桌面版 `D:\codes\RadAtlas_Desktop-master\ai_helper.py` 原型，规划并实现了一个跨平台（Android / iOS / HarmonyOS）的 Flutter 移动端 AI 影像辅助诊断 App。

## 技术选型决策
**采用 Flutter (Dart)** — 三端单代码库，鸿蒙有华为官方 `flutter_flutter_ohos` 分支支持。
详见 `docs/ADR-001-architecture.md`。

## 架构分层（feature-first + 三层架构）
- **core/**：跨特性的基础设施（常量、配置存储、安全存储、主题预设、主题偏好、错误类型）
- **features/ai_config/**：AI 模型配置特性（models + repositories + pages）
- **features/kb_config/**：知识库配置特性
- **features/diagnosis/**：诊断核心特性（services + models + pages）
- **features/settings/**：个性化设置特性（主题色 / 显示模式 / 字体族 / 字号缩放）
- **features/shared/widgets/**：跨特性共享组件

## 关键文件
| 文件 | 作用 |
|------|------|
| `lib/core/constants.dart` | 8 家 AI 提供商 + 3 家知识库 + Prompt 模板 |
| `lib/core/secure_storage.dart` | API Key 加密存储（iOS Keychain / Android Keystore / 鸿蒙 HUKS） |
| `lib/core/theme.dart` | 5 种主题色预设 + 3 种字体族 + 4 档字号缩放 |
| `lib/core/theme_prefs.dart` | ThemePrefs：主题/字体/字号持久化（ChangeNotifier） |
| `lib/features/diagnosis/services/llm_service.dart` | 兼容 chat_completions / responses / gemini 三种 API 协议 |
| `lib/features/diagnosis/services/knowledge_base_service.dart` | 腾讯/火山方舟/NotebookLM 三家知识库查询 |
| `lib/features/diagnosis/services/diagnosis_service.dart` | 多模型并行 + Top 1-3 疾病知识库回查编排 |
| `lib/features/diagnosis/pages/home_page.dart` | 主页（卡片分组：欢迎区/查询条件/AI 模型/知识库） |
| `lib/features/settings/pages/settings_page.dart` | 个性化设置页（主题色板/显示模式/字体族/字号滑块） |

## 已实现需求
1. ✅ 多 AI 模型 API 配置接口（DeepSeek/豆包/OpenAI/智谱/通义/Kimi/MiMo/Gemini）
2. ✅ 个人/公用知识库 API 配置接口（腾讯 IMA/火山方舟/NotebookLM）
3. ✅ 选择检查方法 + 输入关键字 → 1-3 个 AI 模型各返回 1-3 条诊断
4. ✅ 点击诊断查看临床表现、影像学表现、标准报告模板、鉴别诊断要点
5. ✅ 取匹配度最高 1-3 个疾病查知识库 → 文档快照 + 链接显示
6. ✅ **界面优化（v1.1）**：5 主题色 + 亮/暗/跟随系统 + 3 字体族 + 4 档字号缩放，全 App 实时生效并持久化

## 运行
```bash
flutter pub get
flutter run                  # 调试
flutter build apk --release  # Android 打包
```
鸿蒙打包详见 `README.md` 的"HarmonyOS 打包指引"。

## 已知限制
- 诊断历史未持久化（关闭页面即丢失）
- LLM 未走流式输出（SSE）
- HarmonyOS 端未实机测试（代码层兼容，需在 DevEco Studio 完成签名）
- 报告模板暂未支持 PDF / Word 导出

## v1.2 Bug 修复与流程优化（2026-06-22）
- 修复：编辑对话框误触遮罩丢失输入（barrierDismissible: false）
- 修复：保存按钮无 loading 可重复点击（加 _saving 状态）
- 修复：死代码 _originalApiKey 清理
- 修复：diagnosis_service 直接修改 const list 隐患（改为重建结果对象）
- 优化：关键字输入框支持键盘"搜索"键直接触发
- 优化：Loading 显示已完成模型数（X/N 进度环）
- 优化：Loading 可取消 + PopScope 拦截返回键
- 优化：诊断结果页加"重新诊断"/"返回主页"按钮
- 优化：无模型空状态升级为引导卡片
- 优化：启动诊断自动收起键盘
- 详见 `docs/BUGFIX-v1.2.md`

## v1.3 修复与增强（2026-06-23）
- 修复：**DNS 解析失败 Bug**（DeepSeek/通义/豆包报 errno=7）— 根因是 Android main/AndroidManifest.xml 缺 INTERNET 权限
- 修复：AndroidManifest 添加 INTERNET + ACCESS_NETWORK_STATE 权限
- 增强：LlmService / KnowledgeBaseService 加 SocketException 友好错误处理
- 新增：设置页"关于"区 — 开发者（楚雄州人民医院 医学影像中心 张兴文）+ 版权声明 + 信息来源声明
- 新增：疾病详情页底部免责声明卡片
- 增强：KbDocSnapshot 模型新增 bookName/author/chapter/score 字段 + citation getter
- 增强：三家知识库解析时填充引用字段（书名/作者/章节/页码/匹配度）
- 增强：LLM Prompt 新增 references 字段要求标注参考来源
- 增强：DiagnosisItem 模型新增 references 字段
- 增强：知识库快照详情页展开后显示完整引用信息（书名/作者/章节/页码/来源/匹配度）
- 增强：知识库快照列表页引用信息以斜体引号格式显示，点击可复制

## v1.4 IMA 修复 + 连通测试 + 改名换图标（2026-06-23）
- 修复：**IMA 知识库检索失败** — 根因是原 apiUrl 为臆造地址，腾讯 LKE 实际用 SSE 对话接口 `wss.lke.tencentcloud.com/v1/qbot/chat/sse`，bot_app_key 在请求体中传递
- 新增：**AI 配置连通测试** — LlmService.testConnectivity 发送 'hi'+max_tokens=10，30s 超时；编辑对话框加"测试连通性"按钮+结果卡片
- 新增：**知识库配置连通测试** — KnowledgeBaseService.testConnectivity 三家分别测试；编辑对话框加"测试连通性"按钮+结果卡片
- 新增：共享 `lib/core/connectivity_test_result.dart` 模型（success/statusCode/message）
- 改名：App 名称 radatlas_mobile → **AI_Radiagnos**（AndroidManifest / MaterialApp / 主页 AppBar / 设置页关于区）
- 换图标：使用项目根目录 `icon.png`（2048×2048）通过 flutter_launcher_icons 生成 Android mipmap + adaptive icon + Web favicon + PWA icons
- 版本：1.0.0+1 → 1.3.0+1

## 打包
- **Web**: `flutter build web --release` → `build/web/`（最快，即时预览）
- **Android**: `flutter build apk --release` 或 `powershell -File scripts/build_android.ps1`（详见 `docs/PACKAGING.md`）
- **HarmonyOS**: `OHOS_FLUTTER=路径 bash scripts/build_harmony.sh`（详见 `docs/PACKAGING.md`）
- 详见 `docs/QUICKSTART.md` 快速开始指南

## 编译验证
- `flutter analyze`: 0 error（仅 info 级 lint 提示）
- Web 版本: ✅ 已编译，可 `python -m http.server 8080` 预览
- Android APK: ✅ 环境就绪（JDK 17 + Android SDK 34 + Flutter 3.27），已编译
- 国内镜像配置: Gradle→腾讯云 / Maven→阿里云 / Flutter artifacts→flutter-io.cn
