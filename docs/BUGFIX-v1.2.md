# AI_Radiagnos — v1.2 Bug 修复与操作流程优化

## 修复的 Bug

### Bug-1: 编辑对话框点击外部消失导致输入丢失
- **文件**: `ai_config_page.dart` / `kb_config_page.dart`
- **问题**: `showDialog` 默认 `barrierDismissible: true`，误触遮罩会关闭对话框丢失已输入内容
- **修复**: 设置 `barrierDismissible: false`，必须点取消/保存按钮才能关闭

### Bug-2: 保存按钮无 loading 状态，可重复点击
- **文件**: `ai_config_page.dart` / `kb_config_page.dart`
- **问题**: 保存 API 配置时按钮无反馈，用户可能多次点击触发多次写入
- **修复**: 加 `_saving` 状态，保存期间按钮禁用并显示转圈

### Bug-3: 死代码 `_originalApiKey`
- **文件**: `ai_config_page.dart`
- **问题**: 字段定义并赋值 null，但从未使用
- **修复**: 删除该字段

### Bug-4: 直接修改 `r.items[i]` 存在 const list 隐患
- **文件**: `diagnosis_service.dart`
- **问题**: `ModelDiagnosisResult.items` 默认值是 `const []`，直接 `r.items[i] = ...` 在边界情况下会抛 `UnsupportedError: List is immutable`
- **修复**: 改为重建 `ModelDiagnosisResult`（用新列表替换），不再原地修改

## 操作流程优化

### Opt-1: 关键字输入框支持键盘"搜索"键
- **文件**: `home_page.dart`
- **改动**: 加 `textInputAction: TextInputAction.search` + `onSubmitted`，用户在键盘上直接按"搜索"即可触发诊断，无需点按钮

### Opt-2: Loading 状态显示已完成模型数
- **文件**: `home_page.dart` / `diagnosis_service.dart`
- **改动**:
  - `DiagnosisService.diagnose` 的 `onModelComplete` 回调对接 UI
  - Loading 圈改为带进度（`CircularProgressIndicator(value: progress)`）
  - 中间显示 `已完成 X / N 个模型`

### Opt-3: Loading 状态可取消
- **文件**: `home_page.dart`
- **改动**:
  - 加"取消"按钮（OutlinedButton，error 色调）
  - `PopScope(canPop: !_loading)` 拦截返回键，避免 loading 时误退出
  - 取消后隐藏 loading UI，后台请求结果会被 `mounted` 检查忽略

### Opt-4: 诊断结果页加"重新诊断"和"返回主页"按钮
- **文件**: `diagnosis_result_page.dart`
- **改动**: AppBar 加两个图标按钮
  - 刷新图标 → 返回主页（保留输入）
  - 主页图标 → 返回到根

### Opt-5: 无 AI 模型时的空状态更友好
- **文件**: `home_page.dart`
- **改动**: 从简单的"去配置"文字链接，升级为带图标 + 说明 + 主按钮的引导卡片

### Opt-6: 启动诊断时自动收起键盘
- **文件**: `home_page.dart`
- **改动**: `FocusScope.of(context).unfocus()`，避免键盘遮挡 loading UI

## 测试建议

1. **空状态测试**: 首次安装不配置任何模型，主页应显示引导卡片
2. **键盘搜索**: 输入关键字后按键盘"搜索"键应直接触发诊断
3. **取消测试**: 诊断中点"取消"按钮，UI 应回到可输入状态
4. **返回键拦截**: 诊断中按返回键不应退出 App
5. **重复保存**: 编辑配置时连续点保存，应只触发一次
6. **遮罩点击**: 编辑配置时点击对话框外部，不应关闭
7. **知识库快照**: 多模型返回相同疾病时，快照去重后正确分派
