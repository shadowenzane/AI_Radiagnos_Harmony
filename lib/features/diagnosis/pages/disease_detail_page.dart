import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/diagnosis_item.dart';
import '../models/kb_doc_snapshot.dart';

/// 疾病详情页：分段展示 LLM 返回的各字段 + 关联的知识库快照
class DiseaseDetailPage extends StatelessWidget {
  final DiagnosisItem item;
  final String examType;
  final String keywords;

  const DiseaseDetailPage({
    super.key,
    required this.item,
    required this.examType,
    required this.keywords,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(item.diseaseName),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: '复制报告模板',
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: item.reportTemplate));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('报告模板已复制到剪贴板')),
                  );
                }
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '诊断详情', icon: Icon(Icons.description)),
              Tab(text: '知识库引用', icon: Icon(Icons.menu_book)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDetailTab(context),
            _buildKbTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 头部：疾病名 + 匹配度
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.diseaseName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('匹配度：${item.confidence}'),
                const SizedBox(height: 4),
                Text('检查类型：$examType / 关键字：$keywords',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Section(title: '临床表现', content: item.clinicalManifestation),
        _Section(title: '影像学表现', content: item.imagingFindings),
        _Section(
          title: '标准报告模板',
          content: item.reportTemplate,
          mono: true,
          copyable: true,
        ),
        _Section(title: '鉴别诊断及要点', content: item.differentialDiagnosis),
        _Section(title: '病理生理及症状学', content: item.pathophysiology),
        _Section(title: '临床治疗方法', content: item.treatment),
        // 参考来源（LLM 自行标注的引用信息）
        if (item.references.trim().isNotEmpty)
          _Section(
            title: '参考来源',
            content: item.references,
            icon: Icons.source_outlined,
          ),
        // 信息来源声明
        const SizedBox(height: 8),
        _DisclaimerCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildKbTab(BuildContext context) {
    if (item.kbDocs.isEmpty) {
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
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: item.kbDocs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final doc = item.kbDocs[i];
        return _KbDocDetailTile(doc: doc);
      },
    );
  }
}

// ---------- 免责声明卡片 ----------
class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 18, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '免责声明：以上内容由 AI 大语言模型生成，仅供参考，不能替代专业医师的临床判断。最终诊断应由具有执业资格的影像科医师确认。',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onErrorContainer,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;
  final bool mono;
  final bool copyable;
  final IconData? icon;

  const _Section({
    required this.title,
    required this.content,
    this.mono = false,
    this.copyable = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                ],
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (copyable)
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy),
                    tooltip: '复制',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: content));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已复制$title')),
                        );
                      }
                    },
                  ),
              ],
            ),
            const Divider(),
            SelectableText(
              content,
              style: mono
                  ? const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    )
                  : const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _KbDocDetailTile extends StatelessWidget {
  final KbDocSnapshot doc;
  const _KbDocDetailTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.article_outlined, color: scheme.tertiary),
        title: Text(doc.docName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: _buildCitationSubtitle(context),
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
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 完整引用信息
                if (doc.hasFullCitation) ...[
                  _InfoRow(label: '书名', value: doc.bookName),
                  _InfoRow(label: '作者', value: doc.author),
                  _InfoRow(label: '章节', value: doc.chapter),
                  _InfoRow(label: '页码', value: doc.page),
                  _InfoRow(label: '来源', value: doc.source),
                  if (doc.score > 0)
                    _InfoRow(
                        label: '匹配度',
                        value: '${(doc.score * 100).toStringAsFixed(0)}%'),
                  const Divider(),
                ],
                // 快照文本
                SelectableText(
                  doc.snippet.isEmpty ? '（无快照文本）' : doc.snippet,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                // 引用格式
                if (doc.citation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            doc.citation,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
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
        ],
      ),
    );
  }

  /// 构建引用副标题（紧凑形式）
  Widget _buildCitationSubtitle(BuildContext context) {
    final parts = <String>[];
    if (doc.bookName.isNotEmpty) parts.add('《${doc.bookName}》');
    if (doc.author.isNotEmpty) parts.add(doc.author);
    if (doc.chapter.isNotEmpty) parts.add('第${doc.chapter}章');
    if (doc.page.isNotEmpty) parts.add('第${doc.page}页');
    if (parts.isEmpty) {
      parts.add(doc.source);
      if (doc.page.isNotEmpty) parts.add('页 ${doc.page}');
    }
    return Text(
      parts.join(' · '),
      style: const TextStyle(fontSize: 12, color: Colors.grey),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 信息行：标签 + 值
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '$label：',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
