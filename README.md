# AI_Radiagnos — AI 影像辅助诊断（三端通用）

AI_Radiagnos 移动端，将桌面版 `ai_helper.py` 的"多 AI 模型 + 多知识库"影像辅助诊断能力下沉到 **Android / iOS / HarmonyOS** 三端。

## ✨ 功能特性

### 1. AI 大模型配置
- 内置支持 8 家大模型：DeepSeek、豆包(火山引擎)、OpenAI、智谱 GLM、通义千问、Kimi、小米 MiMo、Google Gemini
- 多账号多模型并存（同一提供商可配置多个 API Key）
- API Key 通过系统安全存储加密（iOS Keychain / Android Keystore / 鸿蒙 HUKS）

### 2. 知识库配置
- 支持三类知识库：腾讯 IMA、火山方舟、Google NotebookLM
- 每类知识库支持特有的配置项（Bot ID / Endpoint ID / Collection / Corpus ID）
- 一次诊断可选一个知识库用于检索文档快照

### 3. AI 辅助诊断流程
1. 用户选择 **检查方法**（CT/X-Ray/MRI/PET-CT/超声/DSA）
2. 输入 **关键征象 / 关键字**
3. 多选 **1–3 个 AI 模型**（并行查询）
4. 每个模型返回 **1–3 条最符合的诊断**，按模型分组展示
5. 点击诊断卡片查看 **临床表现 / 影像学表现 / 标准报告模板 / 鉴别诊断要点 / 病理生理 / 治疗**
6. 取所有模型中 **匹配度最高（"高"）的 1–3 个疾病** 去查知识库
7. 知识库文档 **快照** + **链接** 在结果页和疾病详情页都可访问

### 4. 个性化外观（v1.1 新增）
- **5 种主题色**：医学蓝 / 护眼绿 / 暖橙 / 典雅紫 / 清新青
- **3 种显示模式**：跟随系统 / 亮色 / 暗色
- **3 种字体族**：系统默认 / 衬线体 / 等宽体（全 App 生效）
- **4 档字号缩放**：小 / 中 / 大 / 超大（带实时预览）
- 所有偏好通过 SharedPreferences 持久化，重启 App 自动恢复
- 入口：主页右上角 **设置**（齿轮图标）→ 主题/字体/字号

## 🏗️ 技术栈

| 维度 | 选择 | 理由 |
|------|------|------|
| 框架 | Flutter (Dart) | Android/iOS 一等支持；鸿蒙有华为官方 `flutter_flutter_ohos` 分支 |
| 状态管理 | Provider | 学习曲线低，匹配项目规模 |
| 网络 | http | 轻量、鸿蒙兼容 |
| 持久化 | shared_preferences + flutter_secure_storage | 非敏感配置 + 加密 API Key |
| 三方 | equatable / uuid / url_launcher / flutter_markdown | 不可变模型 / 唯一 ID / 跳转链接 / Markdown 渲染 |

详见 [`docs/ADR-001-architecture.md`](docs/ADR-001-architecture.md)。

## 📁 目录结构

```
AI_Radiagnos/
├── pubspec.yaml
├── README.md
├── docs/
│   └── ADR-001-architecture.md          # 架构决策记录
└── lib/
    ├── main.dart                         # 入口 + Provider 注入
    ├── app.dart                          # MaterialApp + 路由
    ├── core/                             # 跨特性基础设施
    │   ├── constants.dart                # PROVIDERS / KNOWLEDGE_PROVIDERS / Prompts
    │   ├── config_storage.dart           # SharedPreferences 非敏感配置
    │   ├── secure_storage.dart           # API Key 安全存储
    │   ├── theme.dart                    # 5 种主题色 + 字体族 + 字号预设
    │   ├── theme_prefs.dart              # ThemePrefs（主题/字体/字号持久化）
    │   └── errors.dart                   # AppError 类型层级
    └── features/                         # feature-first 组织
        ├── ai_config/                    # AI 模型配置特性
        ├── kb_config/                    # 知识库配置特性
        ├── diagnosis/                    # 诊断核心特性
        └── settings/                     # 个性化设置特性
            └── pages/settings_page.dart  # 主题/字体/字号/快捷入口
```

## 🚀 快速开始

### 环境准备
- Flutter SDK ≥ 3.13
- Dart SDK ≥ 3.0
- Android Studio（Android 构建）或 Xcode（iOS 构建）或 DevEco Studio（HarmonyOS 构建）

### 安装依赖
```bash
flutter pub get
```

### 运行
```bash
# 默认（自动选平台）
flutter run

# 指定平台
flutter run -d android   # Android
flutter run -d ios       # iOS（需 macOS + Xcode）
flutter run -d chrome    # Web（仅调试用）
```

### 打包
```bash
# Android
flutter build apk --release
flutter build appbundle --release   # 上架 Google Play 用

# iOS
flutter build ipa --release

# HarmonyOS（需先切换到华为 flutter_flutter_ohos 分支）
# 详见下方"HarmonyOS 打包"
```

## 🔧 HarmonyOS 打包指引

Flutter 鸿蒙构建需要使用华为官方维护的 `flutter_flutter_ohos` 分支。

### 1. 安装鸿蒙 Flutter SDK
```bash
# 克隆华为官方 Flutter 鸿蒙分支
git clone https://gitcode.com/openharmony-sig/flutter_flutter.git
cd flutter_flutter
git checkout ohos-dev

# 设置 FLUTTER_ROOT 并加入 PATH
export FLUTTER_ROOT=$(pwd)
export PATH=$FLUTTER_ROOT/bin:$PATH

# 验证
flutter --version   # 应能看到 "ohos" channel
```

### 2. 安装 DevEco Studio
从华为开发者官网下载并安装 DevEco Studio（鸿蒙官方 IDE），用于打包 hap/hsp。

### 3. 生成鸿蒙工程
```bash
# 在项目根目录执行
flutter create --platforms ohos .
```
该命令会在 `ohos/` 目录生成鸿蒙原生工程壳。

### 4. 打包
```bash
flutter build hap --release    # 生成 .hap 包
```
或在 DevEco Studio 中打开 `ohos/` 目录，使用 IDE 的"Build → Build Hap(s)/APP(s)"完成签名与上架包构建。

> ⚠️ 鸿蒙端首次需要配置签名证书（DevEco Studio → File → Project Structure → Signing Configs）。

## 📋 使用指南

### 首次使用
1. 启动 App，进入主页
2. 点击右上角 **齿轮图标** → 添加 AI 模型配置（至少一个）
3. （可选）点击 **书本图标** → 添加知识库配置并设为当前知识库

### 诊断流程
1. 在主页选择 **检查方法**
2. 输入 **关键征象 / 关键字**（如"肝脏占位"、"肺结节"、"脑室扩大"）
3. 多选 **1–3 个 AI 模型**（已配置的会显示为 Chip）
4. 点击 **开始 AI 辅助诊断**
5. 在结果页：
   - **AI 诊断 Tab**：按模型分组查看诊断列表，点击进入疾病详情
   - **知识库快照 Tab**：查看所有匹配度 Top 1-3 疾病的知识库引用
6. 在疾病详情页：
   - **诊断详情 Tab**：临床表现、影像学表现、标准报告模板（可一键复制）、鉴别诊断要点、病理生理、治疗
   - **知识库快照 Tab**：该疾病关联的文档快照 + 跳转链接

## 🔄 与桌面版的对应关系

| 桌面版 (`ai_helper.py`) | 移动版 |
|--------------------------|--------|
| `PROVIDERS` 常量 | `core/constants.dart` 中的 `kProviders` |
| `KNOWLEDGE_PROVIDERS` | `core/constants.dart` 中的 `kKnowledgeProviders` |
| `load_config` / `save_config` | `AiConfigRepo` + `ConfigStorage` + `SecureStorage` |
| `_call_llm` | `LlmService.call` |
| `_query_knowledge_base` 及子函数 | `KnowledgeBaseService.query` 及私有方法 |
| `call_diagnosis_multi`（ThreadPoolExecutor） | `DiagnosisService.diagnose`（`Future.wait`） |
| JSON 解析 `_parse_json_response` | `LlmService.parseJsonArray` |

新增能力：
- 多账号管理（同一提供商可配多份）
- API Key 加密存储
- 知识库快照独立 Tab 展示
- 报告模板一键复制

## ⚠️ 已知限制

1. **未实现诊断历史持久化**：当前每次诊断结果仅在内存中，关闭结果页即丢失。如需保留可引入 `sqflite`。
2. **未做流式输出**：LLM 响应为整段返回，未走 SSE/stream。长文本时会有 30–90 秒等待。
3. **HarmonyOS 端未实机测试**：代码层兼容鸿蒙，但实际打包需用户在 DevEco Studio 中完成签名。
4. **Gemini API 走 generateContent**：与桌面版（PyQt5 走 OpenAI 兼容层）不同，移动端直接调 Gemini 原生接口，避免中转。

## 📄 License
私有项目，版权所有。
