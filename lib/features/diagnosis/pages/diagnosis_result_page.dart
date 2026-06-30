import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/diagnosis_item.dart';
import '../models/kb_doc_snapshot.dart';
import '../services/diagnosis_service.dart';
import '../../notes/models/note_data.dart';
import '../../notes/repositories/notes_repo.dart';
import 'disease_detail_page.dart';
import 'kb_doc_detail_page.dart';

/// 诊断结果页
///
/// 支持三种模式：
/// - LLM + 知识库：上方显示 LLM 诊断结果，下方显示知识库分组引用
/// - 仅 LLM：只显示 LLM 诊断结果
/// - 仅知识库：只显示知识库检索结果
class DiagnosisResultPage extends StatelessWidget {
  final String examType;
  final String keywords;
  final DiagnosisResult result;

  const DiagnosisResultPage({
    super.key,
    required this.examType,
    required this.keywords,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final hasLlm = result.modelResults.isNotEmpty;
    final hasKb = result.kbGroups.isNotEmpty;

    // 决定 Tab 数量
    final tabs = <Tab>[];
    final views = <Widget>[];

    if (hasLlm) {
      tabs.add(const Tab(text: 'AI 诊断', icon: Icon(Icons.smart_toy)));
      views.add(_buildLlmTab(context));
    }
    if (hasKb) {
      tabs.add(const Tab(text: '知识库引用', icon: Icon(Icons.menu_book)));
      views.add(_buildKbTab(context));
    }

    // 如果都没有
    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('检索结果')),
        body: const Center(
          child: Text('无结果', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('检索结果'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: '保存为笔记',
              onPressed: () => _saveAsNote(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重新检索',
              onPressed: () => Navigator.pop(context),
            ),
          ],
          bottom: TabBar(tabs: tabs),
        ),
        body: TabBarView(children: views),
      ),
    );
  }

  // ==================== 保存为笔记 ====================

  /// 将当前检索结果导出为 PDF 笔记
  ///
  /// 按疾病分别保存：弹出勾选对话框，用户选择要保存的疾病，
  /// 每个被选中的疾病导出为一份独立的 PDF（文件名：疾病名_生成时间.pdf）
  Future<void> _saveAsNote(BuildContext context) async {
    final notesRepo = context.read<NotesRepo>();
    final messenger = ScaffoldMessenger.of(context);

    // 收集可拆分保存的疾病列表
    final diseaseNames = NoteData.collectDiseaseNames(result);

    // 没有任何疾病可保存时，回退为以关键字命名的单份 PDF
    if (diseaseNames.isEmpty) {
      final noteData = NoteData.fromDiagnosisResult(
        result: result,
        examType: examType,
        keywords: keywords,
      );
      await _saveSingleNote(context, notesRepo, messenger, noteData);
      return;
    }

    // 弹出勾选对话框
    final selected = await showDialog<List<String>?>(
      context: context,
      builder: (ctx) => _DiseaseSelectDialog(
        diseaseNames: diseaseNames,
        result: result,
      ),
    );
    if (selected == null || selected.isEmpty) return;

    // 逐个生成 PDF
    await _saveMultipleNotes(context, notesRepo, messenger, selected);
  }

  /// 保存单个笔记（无疾病拆分场景的兜底）
  Future<void> _saveSingleNote(
    BuildContext context,
    NotesRepo notesRepo,
    ScaffoldMessengerState messenger,
    NoteData noteData,
  ) async {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text('正在生成 PDF…'),
          ],
        ),
      ),
    );

    try {
      final meta = await notesRepo.saveNote(noteData);
      if (context.mounted) {
        Navigator.of(context).pop(); // 关闭进度框
        messenger.showSnackBar(SnackBar(
          content: Text('已保存笔记：${meta.diseaseName}'),
          action: SnackBarAction(
            label: '查看',
            onPressed: () => Navigator.pushNamed(context, '/notes'),
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // 关闭进度框
        messenger.showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
  }

  /// 按选中的疾病列表逐个生成 PDF
  Future<void> _saveMultipleNotes(
    BuildContext context,
    NotesRepo notesRepo,
    ScaffoldMessengerState messenger,
    List<String> selectedDiseases,
  ) async {
    final total = selectedDiseases.length;
    final savedNames = <String>[];
    final errors = <String>[];

    // 显示进度对话框
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 16),
            Expanded(child: Text('正在生成 $total 份 PDF…')),
          ],
        ),
      ),
    );

    try {
      for (var i = 0; i < total; i++) {
        final diseaseName = selectedDiseases[i];
        // 每个疾病独立一份 NoteData，文件名 = 疾病名_生成时间.pdf
        final noteData = NoteData.forDisease(
          diseaseName: diseaseName,
          result: result,
          examType: examType,
          keywords: keywords,
        );
        try {
          await notesRepo.saveNote(noteData);
          savedNames.add(diseaseName);
        } catch (e) {
          errors.add('$diseaseName: $e');
        }
      }
    } finally {
      if (context.mounted) Navigator.of(context).pop(); // 关闭进度框
    }

    if (!context.mounted) return;
    final okCount = savedNames.length;
    if (okCount == 0) {
      messenger.showSnackBar(SnackBar(content: Text('保存失败：${errors.join("; ")}')));
    } else if (errors.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text('已保存 $okCount 份笔记：${savedNames.join("、")}'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => Navigator.pushNamed(context, '/notes'),
        ),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text('已保存 $okCount 份，失败 ${errors.length} 份'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => Navigator.pushNamed(context, '/notes'),
        ),
      ));
    }
  }

  // ==================== LLM 诊断结果 Tab ====================

  Widget _buildLlmTab(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: result.modelResults.length,
      itemBuilder: (ctx, i) {
        final r = result.modelResults[i];
        return _ModelResultCard(
          result: r,
          examType: examType,
          keywords: keywords,
        );
      },
    );
  }

  // ==================== 知识库引用 Tab ====================

  Widget _buildKbTab(BuildContext context) {
    final groups = result.kbGroups;
    if (groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '该疾病暂无关联的知识库引用\n\n'
            '可能的原因：\n'
            '• 未选择知识库\n'
            '• 该疾病在知识库中无对应文档\n'
            '• 知识库查询失败（网络/权限）',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.6),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: groups.length,
      itemBuilder: (ctx, i) {
        final group = groups[i];
        return _KbGroupCard(group: group);
      },
    );
  }
}

// ==================== LLM 模型结果卡片 ====================

class _ModelResultCard extends StatelessWidget {
  final ModelDiagnosisResult result;
  final String examType;
  final String keywords;

  const _ModelResultCard({
    required this.result,
    required this.examType,
    required this.keywords,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!result.success) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: scheme.errorContainer.withValues(alpha: 0.3),
        child: ListTile(
          leading: Icon(Icons.error_outline, color: scheme.error),
          title: Text(result.modelName),
          subtitle: Text(result.errorMessage, style: const TextStyle(fontSize: 12)),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Row(
          children: [
            Icon(Icons.smart_toy_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(result.modelName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${result.items.length} 条诊断',
                  style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer)),
            ),
          ],
        ),
        children: result.items.map((item) => _DiagnosisItemTile(
          item: item,
          examType: examType,
          keywords: keywords,
        )).toList(),
      ),
    );
  }
}

class _DiagnosisItemTile extends StatelessWidget {
  final DiagnosisItem item;
  final String examType;
  final String keywords;

  const _DiagnosisItemTile({
    required this.item,
    required this.examType,
    required this.keywords,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cColor = _confidenceColor(item.confidence, scheme);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DiseaseDetailPage(
            item: item,
            examType: examType,
            keywords: keywords,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.diseaseName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cColor.withValues(alpha: 0.3), width: 0.6),
                  ),
                  child: Text('匹配度 ${item.confidence}',
                      style: TextStyle(fontSize: 11, color: cColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (item.imagingFindings.isNotEmpty)
              Text(item.imagingFindings,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Color _confidenceColor(String confidence, ColorScheme scheme) {
    switch (confidence) {
      case '高':
        return Colors.green;
      case '中':
        return scheme.primary;
      default:
        return Colors.orange;
    }
  }
}

// ==================== 知识库分组卡片 ====================

class _KbGroupCard extends StatelessWidget {
  final KbGroupResult group;

  const _KbGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(Icons.menu_book, color: scheme.tertiary),
        title: Text(group.diseaseName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: group.searchName != group.diseaseName
            ? Text('检索词: ${group.searchName}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic))
            : (group.kbDisplayName != null
                ? Text('来源: ${group.kbDisplayName}',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant))
                : null),
        children: [
          if (group.warning != null && group.warning!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(group.warning!,
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade800, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ),
          if (group.docs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('该疾病在知识库中未找到相关文档',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ...group.docs.map((doc) => _KbDocTile(doc: doc)),
        ],
      ),
    );
  }
}

class _KbDocTile extends StatelessWidget {
  final KbDocSnapshot doc;

  const _KbDocTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final citeParts = <String>[];
    if (doc.bookName.isNotEmpty) citeParts.add('《${doc.bookName}》');
    if (doc.author.isNotEmpty) citeParts.add(doc.author);
    if (doc.chapter.isNotEmpty) citeParts.add('第${doc.chapter}章');
    if (doc.page.isNotEmpty) citeParts.add('第${doc.page}页');
    final citeText = citeParts.isNotEmpty
        ? citeParts.join(' · ')
        : '来源：${doc.source}${doc.page.isNotEmpty ? ' · 页 ${doc.page}' : ''}';

    return ListTile(
      leading: Icon(Icons.article_outlined, color: scheme.tertiary),
      title: Row(
        children: [
          Expanded(
            child: Text(doc.docName, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (doc.hasImages)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.image_outlined, size: 15, color: scheme.tertiary),
            ),
          if (doc.hasFullContent)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.read_more, size: 16, color: scheme.tertiary),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (doc.hasFullCitation)
            Row(
              children: [
                Icon(Icons.format_quote, size: 12, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(citeText,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            )
          else
            Text(doc.source, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          if (doc.snippet.isNotEmpty)
            Text(doc.snippet,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        ],
      ),
      trailing: doc.url.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: '打开链接',
              onPressed: () async {
                final uri = Uri.tryParse(doc.url);
                if (uri != null) await launchUrl(uri);
              },
            )
          : null,
      isThreeLine: true,
      onTap: () {
        // 跳转文档详情查看完整文本及图片
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => KbDocDetailPage(doc: doc)),
        );
      },
    );
  }
}

// ==================== 保存为笔记：疾病勾选对话框 ====================

/// 疾病勾选对话框
///
/// 列出本次检索涉及的所有疾病（来自知识库分组或 LLM 结果），
/// 用户可勾选需要单独保存为 PDF 的疾病（支持多选）。
class _DiseaseSelectDialog extends StatefulWidget {
  final List<String> diseaseNames;
  final DiagnosisResult result;

  const _DiseaseSelectDialog({
    required this.diseaseNames,
    required this.result,
  });

  @override
  State<_DiseaseSelectDialog> createState() => _DiseaseSelectDialogState();
}

class _DiseaseSelectDialogState extends State<_DiseaseSelectDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // 默认全部勾选
    _selected = widget.diseaseNames.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('选择要保存的疾病'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '勾选的每条疾病将分别导出为独立 PDF\n文件名：疾病名_生成时间.pdf',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.diseaseNames.length,
                itemBuilder: (ctx, i) {
                  final name = widget.diseaseNames[i];
                  final checked = _selected.contains(name);
                  // 统计该疾病的诊断条数和知识库文档数
                  final noteData = NoteData.forDisease(
                    diseaseName: name,
                    result: widget.result,
                    examType: '',
                    keywords: '',
                  );
                  final diagCount = noteData.diagnosisItems.length;
                  final kbCount = noteData.kbDocs.length;

                  return CheckboxListTile(
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(name);
                        } else {
                          _selected.remove(name);
                        }
                      });
                    },
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'AI 诊断 $diagCount 条 · 知识库 $kbCount 篇',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  );
                },
              ),
            ),
            const Divider(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() => _selected.clear());
                  },
                  child: const Text('全不选'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() => _selected.addAll(widget.diseaseNames));
                  },
                  child: const Text('全选'),
                ),
                const Spacer(),
                Text('已选 ${_selected.length} 项',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()),
          child: Text('保存 ${_selected.isEmpty ? "" : "(${_selected.length})"}'),
        ),
      ],
    );
  }
}
