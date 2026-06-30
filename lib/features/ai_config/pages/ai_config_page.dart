import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../diagnosis/services/llm_service.dart';
import '../repositories/ai_config_repo.dart';
import '../models/provider_config.dart';

class AiConfigPage extends StatefulWidget {
  const AiConfigPage({super.key});

  @override
  State<AiConfigPage> createState() => _AiConfigPageState();
}

class _AiConfigPageState extends State<AiConfigPage> {
  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AiConfigRepo>();
    return Scaffold(
      appBar: AppBar(title: const Text('AI 模型配置')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('添加模型'),
        onPressed: () => _showEditDialog(context, repo, null),
      ),
      body: repo.providers.isEmpty
          ? const Center(
              child: Text('暂无 AI 模型配置\n点击右下角"添加模型"开始',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: repo.providers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final p = repo.providers[i];
                final info = kProviders[p.provider];
                return ListTile(
                  leading: Icon(
                    p.enabled ? Icons.check_circle : Icons.pause_circle,
                    color: p.enabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(p.displayName),
                  subtitle: Text(
                    '${info?.name ?? p.provider} · ${p.model}'
                    '${p.customApiUrl != null && p.customApiUrl!.isNotEmpty ? " · 自定义URL" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        _showEditDialog(context, repo, p);
                      } else if (v == 'toggle') {
                        await repo.toggleEnabled(p.id);
                      } else if (v == 'delete') {
                        final ok = await _confirm(context, '确认删除「${p.displayName}」？');
                        if (ok == true) await repo.remove(p.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(p.enabled ? '禁用' : '启用'),
                      ),
                      const PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                  onTap: () => _showEditDialog(context, repo, p),
                );
              },
            ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AiConfigRepo repo,
    ProviderConfig? existing,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProviderEditDialog(repo: repo, existing: existing),
    );
  }

  Future<bool?> _confirm(BuildContext context, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
  }
}

class _ProviderEditDialog extends StatefulWidget {
  final AiConfigRepo repo;
  final ProviderConfig? existing;
  const _ProviderEditDialog({required this.repo, this.existing});

  @override
  State<_ProviderEditDialog> createState() => _ProviderEditDialogState();
}

class _ProviderEditDialogState extends State<_ProviderEditDialog> {
  late String _provider;
  late TextEditingController _displayCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _apiKeyCtrl;
  bool _obscureKey = true;
  bool _saving = false;
  bool _testing = false;
  String? _testMessage;
  bool? _testSuccess;
  /// 是否已有已保存的 API Key（编辑模式下检查）
  bool _hasExistingKey = false;
  bool _loadingKey = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _provider = e?.provider ?? kProviders.keys.first;
    _displayCtrl = TextEditingController(text: e?.displayName ?? '');
    _modelCtrl = TextEditingController(text: e?.model ?? '');
    _urlCtrl = TextEditingController(text: e?.customApiUrl ?? '');
    _apiKeyCtrl = TextEditingController();
    // 编辑模式下检查是否已有 API Key，并预加载填入输入框
    if (e != null) {
      _checkAndLoadKey(e.id);
    }
  }

  void _checkAndLoadKey(String id) async {
    setState(() => _loadingKey = true);
    final hasKey = await widget.repo.hasApiKey(id);
    if (hasKey) {
      final key = await widget.repo.getApiKey(id);
      if (mounted && key != null && key.isNotEmpty) {
        _apiKeyCtrl.text = key;
      }
    }
    if (mounted) {
      setState(() {
        _hasExistingKey = hasKey;
        _loadingKey = false;
      });
    }
  }

  @override
  void dispose() {
    _displayCtrl.dispose();
    _modelCtrl.dispose();
    _urlCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  /// 测试 LLM 连通性
  Future<void> _testConnectivity() async {
    final model = _modelCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text;

    if (model.isEmpty) {
      _toast('请先填写模型名');
      return;
    }
    if (apiKey.isEmpty) {
      _toast('请先填写 API Key');
      return;
    }

    setState(() {
      _testing = true;
      _testMessage = null;
      _testSuccess = null;
    });

    try {
      final providerConfig = ProviderConfig(
        id: widget.existing?.id ?? 'test',
        provider: _provider,
        displayName: _displayCtrl.text.trim().isEmpty
            ? '测试'
            : _displayCtrl.text.trim(),
        model: model,
        customApiUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
        enabled: true,
        createdAt: DateTime.now(),
      );
      final result = await LlmService.testConnectivity(
        providerConfig: providerConfig,
        apiKey: apiKey,
      );
      if (mounted) {
        setState(() {
          _testing = false;
          _testMessage = result.message;
          _testSuccess = result.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testMessage = '测试异常: $e';
          _testSuccess = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final displayName = _displayCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final customUrl = _urlCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text;

    if (displayName.isEmpty) {
      _toast('请填写显示名');
      return;
    }
    if (model.isEmpty) {
      _toast('请填写模型名');
      return;
    }
    if (widget.existing == null && apiKey.isEmpty) {
      _toast('请填写 API Key');
      return;
    }
    if (widget.existing != null && apiKey.isEmpty) {
      _toast('请填写 API Key（已清空，需重新输入）');
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await widget.repo.add(
          provider: _provider,
          displayName: displayName,
          model: model,
          customApiUrl: customUrl.isEmpty ? null : customUrl,
          apiKey: apiKey,
        );
      } else {
        // 编辑模式：Key 已预加载，直接用输入框值覆盖
        await widget.repo.update(
          id: widget.existing!.id,
          displayName: displayName,
          model: model,
          customApiUrl: customUrl.isEmpty ? null : customUrl,
          apiKey: apiKey,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final info = kProviders[_provider]!;
    return AlertDialog(
      title: Text(widget.existing == null ? '添加 AI 模型' : '编辑 AI 模型'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _provider,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'AI 提供商',
                  labelStyle: TextStyle(fontSize: 13),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: kProviders.values
                    .map((p) => DropdownMenuItem(
                          value: p.key,
                          child: Text(p.name,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: widget.existing == null
                    ? (v) {
                        if (v == null) return;
                        setState(() {
                          _provider = v;
                          // 自动填默认模型
                          final models = kProviders[v]!.models;
                          if (models.isNotEmpty && _modelCtrl.text.isEmpty) {
                            _modelCtrl.text = models.first;
                          }
                        });
                      }
                    : null, // 编辑时不可改 provider
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _displayCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: '显示名（自定义便于区分）',
                  hintText: '例如：我的 DeepSeek 工作号',
                  labelStyle: TextStyle(fontSize: 13),
                  hintStyle: TextStyle(fontSize: 12),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: '模型名',
                  hintText: '点右侧箭头选择，或手输',
                  labelStyle: const TextStyle(fontSize: 13),
                  hintStyle: const TextStyle(fontSize: 12),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: '选择模型',
                    onSelected: (v) => setState(() => _modelCtrl.text = v),
                    itemBuilder: (_) => info.models
                        .map((m) => PopupMenuItem(
                            value: m,
                            child: Text(m,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: '自定义 API URL（可选，留空使用默认）',
                  hintText: info.apiUrl,
                  labelStyle: const TextStyle(fontSize: 13),
                  hintStyle: const TextStyle(fontSize: 12),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyCtrl,
                obscureText: _obscureKey,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'API Key',
                  hintText: _loadingKey
                      ? '加载中…'
                      : (widget.existing != null
                          ? '已加载已保存的 Key（点击眼睛可查看）'
                          : null),
                  helperText: (widget.existing != null && _hasExistingKey)
                      ? '✓ 已保存（编辑可覆盖）'
                      : null,
                  labelStyle: const TextStyle(fontSize: 13),
                  hintStyle: const TextStyle(fontSize: 12),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  helperStyle: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
              if (info.note != null) ...[
                const SizedBox(height: 8),
                Text(info.note!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
              // 连通性测试按钮
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : _testConnectivity,
                      icon: _testing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_protected_setup, size: 18),
                      label: Text(_testing ? '测试中…' : '测试连通性'),
                    ),
                  ),
                ],
              ),
              // 测试结果
              if (_testMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_testSuccess ?? false)
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_testSuccess ?? false)
                          ? Colors.green.withValues(alpha: 0.4)
                          : Colors.red.withValues(alpha: 0.4),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        (_testSuccess ?? false)
                            ? Icons.check_circle
                            : Icons.error_outline,
                        size: 16,
                        color: (_testSuccess ?? false)
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SelectableText(
                          _testMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: (_testSuccess ?? false)
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving || _testing ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving || _testing ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
