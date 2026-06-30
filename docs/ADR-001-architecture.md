# ADR-001：跨平台移动端 AI 影像辅助诊断 App 架构决策

## Status
Accepted（2026-06-22）

## Context
RadAtlas 桌面版（PyQt5）已实现 AI_helper 模块，支持多家大模型（DeepSeek、豆包、OpenAI、智谱、通义）与三类知识库（腾讯 LKE、火山方舟、Google NotebookLM）的影像诊断辅助。

现需将"AI 辅助诊断"能力下沉到移动端，目标平台覆盖：
- **Android**
- **iOS**
- **HarmonyOS（鸿蒙）**

并需要满足以下功能性需求：
1. 提供 AI 大模型 API 配置接口（多模型并存，1–3 个并行查询）
2. 提供个人/公用知识库 API 配置接口
3. 选择检查方法 + 输入关键字 → 1–3 个 LLM 各自给出 1–3 条最符合的诊断列表
4. 点击诊断项可查看：临床表现、影像学表现、标准报告模板、鉴别诊断及要点
5. 取每个 LLM 匹配度最高的 1–3 个疾病 → 去查知识库 → 在结果区显示文档快照与详情链接

## Decision

### 1. 技术栈：Flutter (Dart)

| 候选方案 | Android | iOS | HarmonyOS | 三端一致 | 结论 |
|----------|---------|-----|-----------|----------|------|
| **Flutter** | ✅ 一等支持 | ✅ 一等支持 | ✅ 华为官方维护 `flutter_flutter_ohos` 分支 | ✅ 单代码库 | **采用** |
| React Native | ✅ | ✅ | ⚠️ 仅社区 RNOH，不成熟 | ❌ | 排除 |
| uni-app x | ✅ | ✅ | ✅ | ⚠️ JS Bridge 性能折损 | 排除 |
| Kotlin Multiplatform | ✅ | ✅ | ❌ 需大量额外工作 | ❌ | 排除 |

**理由**：
- 华为官方在 OpenHarmony 生态中维护了 `flutter_flutter_ohos`，HarmonyOS 打包路径成熟
- 单一代码库覆盖三端，UI 一致
- Dart 强类型 + AOT，性能优于 RN/uni-app
- 项目作者已熟悉桌面端 Python，Dart 语法相近，迁移成本低

### 2. 架构分层：feature-first + 三层架构

```
lib/
├── core/                          # 跨特性的基础设施（不可变）
│   ├── constants.dart             # PROVIDERS / KNOWLEDGE_PROVIDERS 常量
│   ├── config_storage.dart        # SharedPreferences 持久化（非敏感配置）
│   ├── secure_storage.dart        # flutter_secure_storage（API Key 加密存储）
│   ├── theme.dart
│   └── errors.dart                # AppError 类型层级
├── features/                      # 按业务特性组织
│   ├── ai_config/                 # AI 模型配置特性
│   │   ├── models/
│   │   ├── repositories/
│   │   └── pages/
│   ├── kb_config/                 # 知识库配置特性
│   │   ├── models/
│   │   ├── repositories/
│   │   └── pages/
│   ├── diagnosis/                 # 诊断核心特性
│   │   ├── models/
│   │   ├── services/              # LlmService / KnowledgeBaseService / DiagnosisService
│   │   └── pages/                 # HomePage / DiagnosisResultPage / DiseaseDetailPage
│   └── shared/widgets/
├── app.dart                       # MaterialApp 根 + 路由
└── main.dart                      # 入口
```

**分层规则**：
- `pages` 仅处理 UI 与用户交互，不含业务逻辑
- `services` 编排业务流程（多模型并行、知识库查询），不含 UI 类型
- `repositories` 封装数据持久化（CRUD），不含业务规则
- `models` 为不可变数据类（equatable）

### 3. 状态管理：Provider

- 选 `provider` 而非 Riverpod/Bloc，理由：
  - 项目规模中等，Provider 足够
  - 学习曲线低，作者 Python 背景，Provider 模式接近 MVC
  - 三端一致行为
- 配置数据通过 `ChangeNotifier` 在设置页修改后通知主页刷新

### 4. 配置存储策略

| 数据类型 | 存储位置 | 理由 |
|----------|----------|------|
| AI 提供商列表、模型名、enabled 标志、自定义 URL | `shared_preferences` (JSON 字符串) | 非敏感，需快速读取 |
| **API Key**（所有 AI / 知识库） | `flutter_secure_storage` | iOS Keychain / Android Keystore / 鸿蒙 HUKS |
| 知识库 bot_id / endpoint_id / corpus_id | `shared_preferences` | 非敏感标识 |
| 诊断历史（可选） | `sqflite`（后期） | 需要查询的结构化数据 |

### 5. 网络层

- 使用 `http` 包（轻量，鸿蒙兼容性好）
- 兼容两种 API 协议：
  - `chat_completions`：OpenAI 兼容（DeepSeek/OpenAI/智谱/通义）
  - `responses`：豆包 Responses API（不同的 payload 与响应解析）
- 多模型并行查询使用 `Future.wait`（对应桌面版 `ThreadPoolExecutor`）

### 6. 诊断编排流程（DiagnosisService）

```
用户输入 (exam_type, keywords)
        │
        ├─ 选中 N (1–3) 个 AI 模型配置
        │
        ▼
┌──────────────────────────────────┐
│ Future.wait([                    │  并行
│   LlmService.call(model1, ...),  │
│   LlmService.call(model2, ...),  │
│   LlmService.call(model3, ...),  │
│ ])                               │
└──────────────────────────────────┘
        │
        ▼
按模型分组结果：{DeepSeek: [disease1,2,3], GLM: [disease1,2,3], ...}
        │
        ▼
取每个模型 confidence="高" 的疾病（去重）→ 取 Top 1–3
        │
        ▼
┌──────────────────────────────────┐
│ Future.wait([                    │  并行
│   KnowledgeBaseService.query(    │
│     kbConfig, disease_name),     │
│   ...                            │
│ ])                               │
└──────────────────────────────────┘
        │
        ▼
聚合：每条诊断附 kb_docs 快照列表 → 渲染
```

### 7. 安全与隐私

- API Key 仅存储于系统安全存储，不进入日志、不进入错误上报
- 网络请求强制 HTTPS（大模型与知识库 API 本就是 HTTPS）
- 不收集任何用户隐私，不做埋点（医疗场景合规）

## Consequences

### 优势
- ✅ 单代码库三端覆盖，维护成本最低
- ✅ feature-first 结构，新增特性不破坏既有模块
- ✅ 配置分层存储，API Key 不泄漏
- ✅ 服务层与桌面版 `ai_helper.py` 一一对应，便于同步迭代

### 代价
- ⚠️ HarmonyOS 端需要使用华为官方 `flutter_flutter_ohos` 分支构建，开发者需熟悉 DevEco Studio
- ⚠️ Flutter 不支持真正的"原生 UI"，三端 UI 完全一致（这通常是优点，但对要求平台原生体验的用户是缺点）
- ⚠️ Dart 生态相比 Python 偏薄，某些高级 NLP 工具需自行实现

### 反转成本
- 若未来需替换为 RN 或 KMP，services 层与 models 层可平移（业务逻辑无 UI 依赖），仅 pages 需重写
- 若需切换状态管理（Provider → Riverpod），仅需改 `app.dart` 顶层与各 repo 的 `ChangeNotifier` 替换

## 参考
- 桌面版原型：`D:\codes\RadAtlas_Desktop-master\ai_helper.py`
- 鸿蒙 Flutter 分支：https://gitcode.com/openharmony-sig/flutter_flutter
