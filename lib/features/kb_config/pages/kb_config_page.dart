import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../diagnosis/services/knowledge_base_service.dart';
import '../repositories/kb_config_repo.dart';
import '../models/knowledge_config.dart';

class KbConfigPage extends StatefulWidget {
  const KbConfigPage({super.key});

  @override
  State<KbConfigPage> createState() => _KbConfigPageState();
}

class _KbConfigPageState extends State<KbConfigPage> {
  @override
  Widget build(BuildContext context) {
    final repo = context.watch<KbConfigRepo>();
    return Scaffold(
      appBar: AppBar(title: const Text('知识库配置')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('添加知识库'),
        onPressed: () => _showEditDialog(context, repo, null),
      ),
      body: repo.configs.isEmpty
          ? const Center(
              child: Text('暂无知识库配置\n\n知识库为可选：用于在 AI 诊断后\n检索文档快照附在结果中',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: repo.configs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final c = repo.configs[i];
                final info = kKnowledgeProviders[c.type];
                final isSelected = repo.selectedIds.contains(c.id);
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                  ),
                  title: Text(c.displayName),
                  subtitle: Text(
                    '${info?.name ?? c.type}'
                    '${c.workspaceId != null && c.workspaceId!.isNotEmpty ? " · ws=${_maskKey(c.workspaceId!)}" : ""}'
                    '${c.indexId != null && c.indexId!.isNotEmpty ? " · idx=${c.indexId}" : ""}'
                    '${c.collectionName != null && c.collectionName!.isNotEmpty ? " · col=${c.collectionName}" : ""}'
                    '${c.resourceId != null && c.resourceId!.isNotEmpty ? " · res=${_maskKey(c.resourceId!)}" : ""}'
                    '${c.fileSearchStore != null && c.fileSearchStore!.isNotEmpty ? " · store=${_maskKey(c.fileSearchStore!)}" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        _showEditDialog(context, repo, c);
                      } else if (v == 'select') {
                        await repo.toggleSelection(c.id);
                      } else if (v == 'toggle') {
                        await repo.toggleEnabled(c.id);
                      } else if (v == 'delete') {
                        final ok = await _confirm(context, '确认删除「${c.displayName}」？');
                        if (ok == true) await repo.remove(c.id);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'select',
                        child: Text(isSelected ? '取消选用' : '选用此知识库'),
                      ),
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(c.enabled ? '禁用' : '启用'),
                      ),
                      const PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                  onTap: () => _showEditDialog(context, repo, c),
                );
              },
            ),
    );
  }

  /// 遮掩 Key 中间部分
  String _maskKey(String key) {
    if (key.length <= 8) return '${key.substring(0, 2)}***';
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }

  Future<void> _showEditDialog(
    BuildContext context,
    KbConfigRepo repo,
    KnowledgeConfig? existing,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _KbEditDialog(repo: repo, existing: existing),
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

class _KbEditDialog extends StatefulWidget {
  final KbConfigRepo repo;
  final KnowledgeConfig? existing;
  const _KbEditDialog({required this.repo, this.existing});

  @override
  State<_KbEditDialog> createState() => _KbEditDialogState();
}

class _KbEditDialogState extends State<_KbEditDialog> {
  late String _type;
  late TextEditingController _displayCtrl;
  // 阿里百炼
  late TextEditingController _workspaceIdCtrl;
  late TextEditingController _indexIdCtrl;
  late TextEditingController _bailianAkCtrl;
  late TextEditingController _bailianSkCtrl;
  // 火山方舟（标准知识库：search_knowledge 模式）
  late TextEditingController _collectionCtrl;
  late TextEditingController _resourceIdCtrl;
  late TextEditingController _accessKeyCtrl;
  late TextEditingController _secretKeyCtrl;
  // NotebookLM
  late TextEditingController _fileStoreCtrl;
  late TextEditingController _geminiApiKeyCtrl;

  bool _obscureKey = true;
  bool _saving = false;
  bool _testing = false;
  String? _testMessage;
  bool? _testSuccess;
  bool _hasExistingKey = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? kKnowledgeProviders.keys.first;
    _displayCtrl = TextEditingController(text: e?.displayName ?? '');
    // 阿里百炼
    _workspaceIdCtrl = TextEditingController(text: e?.workspaceId ?? '');
    _indexIdCtrl = TextEditingController(text: e?.indexId ?? '');
    _bailianAkCtrl = TextEditingController();
    _bailianSkCtrl = TextEditingController();
    // 火山方舟
    _collectionCtrl = TextEditingController(text: e?.collectionName ?? '');
    _resourceIdCtrl = TextEditingController(text: e?.resourceId ?? '');
    _accessKeyCtrl = TextEditingController();
    _secretKeyCtrl = TextEditingController();
    // NotebookLM
    _fileStoreCtrl = TextEditingController(text: e?.fileSearchStore ?? '');
    _geminiApiKeyCtrl = TextEditingController();

    if (e != null) {
      _checkExistingKey(e.id);
      _loadExistingCreds(e.id);
    }
  }

  void _checkExistingKey(String id) async {
    final hasKey = await widget.repo.hasApiKey(id);
    if (mounted) {
      setState(() => _hasExistingKey = hasKey);
    }
  }

  /// 编辑模式：预加载已保存的凭证填入输入框
  void _loadExistingCreds(String id) async {
    final creds = await widget.repo.getCredentials(id);
    if (!mounted) return;
    // 阿里百炼: access_key / secret_key
    if (creds['access_key'] != null) _bailianAkCtrl.text = creds['access_key']!;
    if (creds['secret_key'] != null) _bailianSkCtrl.text = creds['secret_key']!;
    // 火山方舟: access_key / secret_key
    if (creds['access_key'] != null) _accessKeyCtrl.text = creds['access_key']!;
    if (creds['secret_key'] != null) _secretKeyCtrl.text = creds['secret_key']!;
    // NotebookLM: api_key
    if (creds['api_key'] != null) _geminiApiKeyCtrl.text = creds['api_key']!;
    if (creds.values.any((v) => v.isNotEmpty)) {
      setState(() => _hasExistingKey = true);
    }
  }

  @override
  void dispose() {
    _displayCtrl.dispose();
    _workspaceIdCtrl.dispose();
    _indexIdCtrl.dispose();
    _bailianAkCtrl.dispose();
    _bailianSkCtrl.dispose();
    _collectionCtrl.dispose();
    _resourceIdCtrl.dispose();
    _accessKeyCtrl.dispose();
    _secretKeyCtrl.dispose();
    _fileStoreCtrl.dispose();
    _geminiApiKeyCtrl.dispose();
    super.dispose();
  }

  /// 构建凭证 Map（直接用输入框值，编辑模式已预加载）
  Future<Map<String, String>> _buildCredentials() async {
    final creds = <String, String>{};

    if (_type == 'bailian') {
      // 阿里百炼: access_key + secret_key
      if (_bailianAkCtrl.text.trim().isNotEmpty) {
        creds['access_key'] = _bailianAkCtrl.text.trim();
      }
      if (_bailianSkCtrl.text.trim().isNotEmpty) {
        creds['secret_key'] = _bailianSkCtrl.text.trim();
      }
    } else if (_type == 'volcengine') {
      // 火山方舟标准知识库：仅需 access_key + secret_key
      if (_accessKeyCtrl.text.trim().isNotEmpty) {
        creds['access_key'] = _accessKeyCtrl.text.trim();
      }
      if (_secretKeyCtrl.text.trim().isNotEmpty) {
        creds['secret_key'] = _secretKeyCtrl.text.trim();
      }
    } else if (_type == 'notebooklm') {
      final apiKey = _geminiApiKeyCtrl.text.trim();
      if (apiKey.isNotEmpty) creds['api_key'] = apiKey;
    }
    return creds;
  }

  /// 测试知识库连通性
  Future<void> _testConnectivity() async {
    final creds = await _buildCredentials();

    // 各类型必填字段校验
    if (_type == 'bailian') {
      if (_workspaceIdCtrl.text.trim().isEmpty) {
        _toast('请先填写业务空间 ID');
        return;
      }
      if (_indexIdCtrl.text.trim().isEmpty) {
        _toast('请先填写知识库 ID');
        return;
      }
      if (_bailianAkCtrl.text.trim().isEmpty || _bailianSkCtrl.text.trim().isEmpty) {
        _toast('请先填写 AccessKey ID 和 AccessKey Secret');
        return;
      }
    } else if (_type == 'volcengine') {
      if (_accessKeyCtrl.text.trim().isEmpty || _secretKeyCtrl.text.trim().isEmpty) {
        _toast('请先填写 Access Key 和 Secret Key');
        return;
      }
      if (_resourceIdCtrl.text.trim().isEmpty && _collectionCtrl.text.trim().isEmpty) {
        _toast('请填写 Resource ID 或 集合名称');
        return;
      }
    } else if (_type == 'notebooklm') {
      if (creds['api_key'] == null || creds['api_key']!.isEmpty) {
        _toast('请先填写 Gemini API Key');
        return;
      }
    }

    setState(() {
      _testing = true;
      _testMessage = null;
      _testSuccess = null;
    });

    try {
      final kbConfig = KnowledgeConfig(
        id: widget.existing?.id ?? 'test',
        type: _type,
        displayName: _displayCtrl.text.trim().isEmpty ? '测试' : _displayCtrl.text.trim(),
        workspaceId: _workspaceIdCtrl.text.trim().isEmpty ? null : _workspaceIdCtrl.text.trim(),
        indexId: _indexIdCtrl.text.trim().isEmpty ? null : _indexIdCtrl.text.trim(),
        collectionName: _collectionCtrl.text.trim().isEmpty ? null : _collectionCtrl.text.trim(),
        resourceId: _resourceIdCtrl.text.trim().isEmpty ? null : _resourceIdCtrl.text.trim(),
        fileSearchStore: _fileStoreCtrl.text.trim().isEmpty ? null : _fileStoreCtrl.text.trim(),
        enabled: true,
        createdAt: DateTime.now(),
      );
      final result = await KnowledgeBaseService.testConnectivity(
        kbConfig: kbConfig,
        credentials: creds,
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
    if (displayName.isEmpty) {
      _toast('请填写显示名');
      return;
    }

    setState(() => _saving = true);
    try {
      final creds = await _buildCredentials();

      if (widget.existing == null) {
        await widget.repo.add(
          type: _type,
          displayName: displayName,
          workspaceId: _workspaceIdCtrl.text.trim().isEmpty ? null : _workspaceIdCtrl.text.trim(),
          indexId: _indexIdCtrl.text.trim().isEmpty ? null : _indexIdCtrl.text.trim(),
          collectionName: _collectionCtrl.text.trim().isEmpty ? null : _collectionCtrl.text.trim(),
          resourceId: _resourceIdCtrl.text.trim().isEmpty ? null : _resourceIdCtrl.text.trim(),
          fileSearchStore: _fileStoreCtrl.text.trim().isEmpty ? null : _fileStoreCtrl.text.trim(),
          credentials: creds,
        );
      } else {
        await widget.repo.update(
          id: widget.existing!.id,
          displayName: displayName,
          workspaceId: _workspaceIdCtrl.text.trim().isEmpty ? null : _workspaceIdCtrl.text.trim(),
          indexId: _indexIdCtrl.text.trim().isEmpty ? null : _indexIdCtrl.text.trim(),
          collectionName: _collectionCtrl.text.trim().isEmpty ? null : _collectionCtrl.text.trim(),
          resourceId: _resourceIdCtrl.text.trim().isEmpty ? null : _resourceIdCtrl.text.trim(),
          fileSearchStore: _fileStoreCtrl.text.trim().isEmpty ? null : _fileStoreCtrl.text.trim(),
          credentials: creds,
          clearWorkspaceId: _workspaceIdCtrl.text.trim().isEmpty,
          clearIndexId: _indexIdCtrl.text.trim().isEmpty,
          clearCollectionName: _collectionCtrl.text.trim().isEmpty,
          clearResourceId: _resourceIdCtrl.text.trim().isEmpty,
          clearFileSearchStore: _fileStoreCtrl.text.trim().isEmpty,
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

  /// 普通输入框装饰（缩小文字 + 收紧间距）
  InputDecoration _fieldDeco(
    BuildContext context, {
    required String labelText,
    String? hintText,
  }) =>
      InputDecoration(
        isDense: true,
        labelText: labelText,
        hintText: hintText,
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: const TextStyle(fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  /// 密钥输入框装饰（带显示/隐藏按钮 + 编辑模式已保存提示）
  InputDecoration _secretFieldDeco(
    BuildContext context, {
    required String labelText,
    String? hintText,
  }) =>
      InputDecoration(
        isDense: true,
        labelText: labelText,
        hintText: hintText,
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: const TextStyle(fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        helperText: (widget.existing != null && _hasExistingKey)
            ? '✓ 已保存（编辑可覆盖）'
            : null,
        helperStyle: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.primary,
        ),
        suffixIcon: IconButton(
          icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscureKey = !_obscureKey),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final info = kKnowledgeProviders[_type]!;
    return AlertDialog(
      title: Text(widget.existing == null ? '添加知识库' : '编辑知识库'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 类型选择
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: '知识库类型',
                  labelStyle: TextStyle(fontSize: 13),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: kKnowledgeProviders.values
                    .map((p) => DropdownMenuItem(
                          value: p.key,
                          child: Text(p.name,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: widget.existing == null
                    ? (v) => setState(() => _type = v ?? _type)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(info.description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: _displayCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDeco(context, labelText: '显示名'),
              ),
              const SizedBox(height: 12),

              // ---- 阿里百炼字段 ----
              if (_type == 'bailian') ...[
                TextField(
                  controller: _workspaceIdCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _fieldDeco(
                    context,
                    labelText: '业务空间 ID（Workspace ID）',
                    hintText: '百炼控制台 → 业务空间 → 查看 ID',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _indexIdCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _fieldDeco(
                    context,
                    labelText: '知识库 ID（Index ID）',
                    hintText: '百炼控制台 → 知识库 → 查看 ID',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bailianAkCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _fieldDeco(
                    context,
                    labelText: 'AccessKey ID',
                    hintText: '阿里云 RAM 访问密钥 ID',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bailianSkCtrl,
                  obscureText: _obscureKey,
                  style: const TextStyle(fontSize: 13),
                  decoration: _secretFieldDeco(
                    context,
                    labelText: 'AccessKey Secret',
                    hintText: '阿里云 RAM 访问密钥 Secret',
                  ),
                ),
              ],

              // ---- 火山方舟字段（标准知识库：search_knowledge 模式）----
              if (_type == 'volcengine') ...[
                TextField(
                  controller: _resourceIdCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _fieldDeco(
                    context,
                    labelText: 'Resource ID',
                    hintText: '知识库资源 ID',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _collectionCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _fieldDeco(
                    context,
                    labelText: 'Collection Name（集合名，可选）',
                    hintText: '与 Resource ID 二选一',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _accessKeyCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _fieldDeco(
                    context,
                    labelText: 'Access Key（HMAC 签名）',
                    hintText: '火山引擎 IAM 访问密钥 AK',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _secretKeyCtrl,
                  obscureText: _obscureKey,
                  style: const TextStyle(fontSize: 13),
                  decoration: _secretFieldDeco(
                    context,
                    labelText: 'Secret Key（HMAC 签名）',
                    hintText: '火山引擎 IAM 访问密钥 SK',
                  ),
                ),
              ],

              // ---- NotebookLM 字段 ----
              if (_type == 'notebooklm') ...[
                TextField(
                  controller: _fileStoreCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _fieldDeco(
                    context,
                    labelText: 'File Search Store ID（可选）',
                    hintText: '留空则用 Google Search 兜底',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _geminiApiKeyCtrl,
                  obscureText: _obscureKey,
                  style: const TextStyle(fontSize: 13),
                  decoration: _secretFieldDeco(
                    context,
                    labelText: 'Gemini API Key',
                  ),
                ),
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
                        (_testSuccess ?? false) ? Icons.check_circle : Icons.error_outline,
                        size: 16,
                        color: (_testSuccess ?? false) ? Colors.green : Colors.red,
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
