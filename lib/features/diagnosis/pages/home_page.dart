import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config_storage.dart';
import '../../../core/constants.dart';
import '../../../core/errors.dart';
import '../../../core/exam_prefs.dart';
import '../../ai_config/repositories/ai_config_repo.dart';
import '../../kb_config/repositories/kb_config_repo.dart';
import '../../notes/repositories/notes_repo.dart';
import '../services/diagnosis_service.dart';
import 'diagnosis_result_page.dart';

/// 主页：检查方法选择 + 关键字 + 多选 AI 模型 + 多选知识库
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _examType = kExamTypes.first;
  bool _examTypeInited = false;
  final _keywordCtrl = TextEditingController();
  final Set<String> _selectedProviderIds = {};
  bool _loading = false;
  int _completedModels = 0;
  int _totalModels = 0;

  // 关键字输入历史（最多 10 条，去重，新条目置顶）
  static const int _kMaxHistory = 10;
  List<String> _keywordHistory = [];
  final _keywordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadKeywordHistory();
    // 输入框获得/失去焦点时刷新，以便显示/隐藏历史下拉
    _keywordFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadKeywordHistory() async {
    final list = await ConfigStorage.loadKeywordHistory();
    if (mounted) setState(() => _keywordHistory = list);
  }

  Future<void> _addKeywordToHistory(String keyword) async {
    if (keyword.isEmpty) return;
    final updated = <String>[keyword];
    for (final item in _keywordHistory) {
      if (item.trim() == keyword.trim()) continue; // 去重
      updated.add(item);
      if (updated.length >= _kMaxHistory) break;
    }
    _keywordHistory = updated.take(_kMaxHistory).toList();
    await ConfigStorage.saveKeywordHistory(_keywordHistory);
  }

  Future<void> _removeKeywordFromHistory(String keyword) async {
    _keywordHistory =
        _keywordHistory.where((e) => e != keyword).toList();
    await ConfigStorage.saveKeywordHistory(_keywordHistory);
    if (mounted) setState(() {});
  }

  Future<void> _clearKeywordHistory() async {
    _keywordHistory = [];
    await ConfigStorage.saveKeywordHistory(_keywordHistory);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    _keywordFocus.dispose();
    super.dispose();
  }

  /// 用 ExamPrefs 的默认检查方法初始化一次
  void _ensureExamTypeInited(ExamPrefs prefs) {
    if (_examTypeInited) return;
    _examTypeInited = true;
    if (kExamTypes.contains(prefs.defaultExamType)) {
      _examType = prefs.defaultExamType;
    }
  }

  Future<void> _startDiagnosis() async {
    final keywords = _keywordCtrl.text.trim();
    if (keywords.isEmpty) {
      _toast('请输入关键征象/关键字');
      return;
    }

    // 记录关键字到历史（最多 10 条）
    await _addKeywordToHistory(keywords);

    final aiRepo = context.read<AiConfigRepo>();
    final kbRepo = context.read<KbConfigRepo>();
    final selectedKbIds = kbRepo.selectedIds.toList();

    // 至少选一个 LLM 或知识库
    if (_selectedProviderIds.isEmpty && selectedKbIds.isEmpty) {
      _toast('请至少选择一个 AI 模型或知识库');
      return;
    }
    if (_selectedProviderIds.length > 3) {
      _toast('最多同时选择 3 个 AI 模型');
      return;
    }
    if (selectedKbIds.length > 3) {
      _toast('最多同时选择 3 个知识库');
      return;
    }

    // 校验所选模型都已配置 API Key
    for (final id in _selectedProviderIds) {
      final p = aiRepo.providers.where((x) => x.id == id).firstOrNull;
      if (p == null) continue;
      final key = await aiRepo.getApiKey(id);
      if (key == null || key.isEmpty) {
        _toast('模型「${p.displayName}」未配置 API Key');
        return;
      }
    }

    setState(() {
      _loading = true;
      _completedModels = 0;
      _totalModels = _selectedProviderIds.length;
    });

    // 收起键盘
    FocusScope.of(context).unfocus();

    try {
      final service = DiagnosisService(aiRepo, kbRepo);
      final result = await service.diagnose(
        examType: _examType,
        keywords: keywords,
        selectedProviderIds: _selectedProviderIds.toList(),
        selectedKbIds: selectedKbIds,
        onModelComplete: (_) {
          if (mounted) setState(() => _completedModels++);
        },
      );

      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DiagnosisResultPage(
          examType: _examType,
          keywords: keywords,
          result: result,
        ),
      ));
    } on AppError catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('诊断失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _cancelDiagnosis() {
    setState(() => _loading = false);
    _toast('已取消（后台请求仍会完成，结果将被忽略）');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final aiRepo = context.watch<AiConfigRepo>();
    final kbRepo = context.watch<KbConfigRepo>();
    final examPrefs = context.watch<ExamPrefs>();
    _ensureExamTypeInited(examPrefs);
    final scheme = Theme.of(context).colorScheme;
    final providers = aiRepo.providers;
    final kbConfigs = kbRepo.configs;

    return Scaffold(
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (ctx, constraints) => const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('AI_Radiagnos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_alt_outlined),
            tooltip: '我的笔记',
            onPressed: () => Navigator.pushNamed(context, '/notes'),
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'AI 模型配置',
            onPressed: () => Navigator.pushNamed(context, '/ai-config'),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: '知识库配置',
            onPressed: () => Navigator.pushNamed(context, '/kb-config'),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '帮助文档',
            onPressed: () => Navigator.pushNamed(context, '/help'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? _buildLoading(scheme)
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 欢迎区
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.psychology,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI_Radiagnos',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('AI 影像辅助诊断',
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 查询条件卡片
                    _Card(
                      icon: Icons.search,
                      title: '查询条件',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildExamTypeSelector(),
                          const SizedBox(height: 12),
                          _buildKeywordInput(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // AI 模型选择卡片
                    _Card(
                      icon: Icons.smart_toy_outlined,
                      title: 'AI 模型（可选 0-3 个）',
                      action: TextButton.icon(
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('配置', style: TextStyle(fontSize: 12)),
                        onPressed: () => Navigator.pushNamed(context, '/ai-config'),
                      ),
                      child: providers.isEmpty
                          ? _buildEmptyProviders(scheme)
                          : _buildProviderSelector(providers, scheme),
                    ),
                    const SizedBox(height: 14),

                    // 知识库选择卡片
                    _Card(
                      icon: Icons.menu_book_outlined,
                      title: '知识库（可选 0-3 个）',
                      action: TextButton.icon(
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('配置', style: TextStyle(fontSize: 12)),
                        onPressed: () => Navigator.pushNamed(context, '/kb-config'),
                      ),
                      child: kbConfigs.isEmpty
                          ? _buildEmptyKb(scheme)
                          : _buildKbSelector(kbRepo, kbConfigs, scheme),
                    ),
                    const SizedBox(height: 14),

                    // 已保存笔记快捷入口
                    _buildNotesEntry(scheme),
                    const SizedBox(height: 14),

                    // 检索模式提示
                    _buildModeHint(scheme),
                    const SizedBox(height: 14),

                    // 诊断按钮
                    FilledButton.icon(
                      onPressed: _startDiagnosis,
                      icon: const Icon(Icons.search),
                      label: const Text('开始检索'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  /// 已保存笔记快捷入口卡片
  Widget _buildNotesEntry(ColorScheme scheme) {
    final notesRepo = context.watch<NotesRepo>();
    final count = notesRepo.count;
    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/notes'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.note_alt_outlined, size: 20, color: scheme.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('我的笔记',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      count > 0 ? '已保存 $count 篇笔记' : '查看已导出的 PDF 笔记',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  /// 检索模式提示
  Widget _buildModeHint(ColorScheme scheme) {
    final hasLlm = _selectedProviderIds.isNotEmpty;
    final kbRepo = context.watch<KbConfigRepo>();
    final hasKb = kbRepo.selectedIds.isNotEmpty;
    String mode;
    IconData icon;
    Color color;
    if (hasLlm && hasKb) {
      mode = 'LLM + 知识库联合检索';
      icon = Icons.sync_alt;
      color = scheme.primary;
    } else if (hasLlm) {
      mode = '仅 LLM 检索';
      icon = Icons.smart_toy_outlined;
      color = scheme.tertiary;
    } else if (hasKb) {
      mode = '仅知识库检索';
      icon = Icons.menu_book_outlined;
      color = scheme.secondary;
    } else {
      mode = '请选择 AI 模型或知识库';
      icon = Icons.info_outline;
      color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(mode, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildExamTypeSelector() {
    return DropdownButtonFormField<String>(
      value: kExamTypes.contains(_examType) ? _examType : kExamTypes.first,
      decoration: const InputDecoration(
        isDense: true,
        labelText: '检查方法',
        prefixIcon: Icon(Icons.medical_services_outlined),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: kExamTypes
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(t, style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _examType = v);
      },
    );
  }

  Widget _buildKeywordInput() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _keywordCtrl,
          focusNode: _keywordFocus,
          maxLines: 2,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _startDiagnosis(),
          decoration: InputDecoration(
            hintText: '输入关键征象/关键字，如"肺结节 边缘毛刺"',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key),
            suffixIcon: _keywordCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: '清空',
                    onPressed: () {
                      _keywordCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_keywordHistory.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.history, size: 14, color: scheme.onSurfaceVariant),
                ..._keywordHistory.map((kw) => InputChip(
                      label: Text(kw,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _keywordCtrl.text = kw;
                        _keywordCtrl.selection =
                            TextSelection.collapsed(offset: kw.length);
                        setState(() {});
                      },
                      onDeleted: () => _removeKeywordFromHistory(kw),
                      deleteIcon: const Icon(Icons.close, size: 14),
                    )),
                if (_keywordHistory.length > 1)
                  TextButton.icon(
                    onPressed: _clearKeywordHistory,
                    icon: const Icon(Icons.delete_sweep, size: 14),
                    label: const Text('清空', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyProviders(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: scheme.primary, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('未配置 AI 模型也能用知识库检索', style: TextStyle(fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/ai-config'),
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelector(List providers, ColorScheme scheme) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: providers.map((p) {
        final selected = _selectedProviderIds.contains(p.id);
        return FilterChip(
          label: Text('${p.displayName} (${p.model})',
              style: const TextStyle(fontSize: 11)),
          selected: selected,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (v) {
            setState(() {
              if (v) {
                if (_selectedProviderIds.length >= 3) {
                  _toast('最多选择 3 个模型');
                  return;
                }
                _selectedProviderIds.add(p.id);
              } else {
                _selectedProviderIds.remove(p.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildEmptyKb(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: scheme.primary, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('未配置知识库也能用 AI 诊断', style: TextStyle(fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/kb-config'),
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  Widget _buildKbSelector(KbConfigRepo kbRepo, List kbConfigs, ColorScheme scheme) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: kbConfigs.map((c) {
        final selected = kbRepo.selectedIds.contains(c.id);
        return FilterChip(
          label: Text(c.displayName, style: const TextStyle(fontSize: 11)),
          selected: selected,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (v) async {
            if (v && kbRepo.selectedIds.length >= 3) {
              _toast('最多选择 3 个知识库');
              return;
            }
            await kbRepo.toggleSelection(c.id);
          },
        );
      }).toList(),
    );
  }

  Widget _buildLoading(ColorScheme scheme) {
    final progress = _totalModels > 0 ? _completedModels / _totalModels : 0.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 4,
                    color: scheme.primary,
                    value: _totalModels > 0 ? progress : null,
                  ),
                  if (_totalModels > 0)
                    Text(
                      '$_completedModels/$_totalModels',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _totalModels > 0 ? '正在查询 AI 模型…' : '正在检索知识库…',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _cancelDiagnosis,
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? action;

  const _Card({required this.icon, required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary)),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
