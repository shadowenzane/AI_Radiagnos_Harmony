import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/kb_doc_snapshot.dart';

/// 知识库文档详情查看页
///
/// 展示知识库检索返回的完整文本内容（fullContent）和原书图片（images）。
/// 对齐桌面版 RadAtlas 可查看知识库文本及图片的能力。
class KbDocDetailPage extends StatelessWidget {
  final KbDocSnapshot doc;

  const KbDocDetailPage({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 展示用完整内容：优先 fullContent，回退 snippet
    final displayContent = doc.fullContent.isNotEmpty ? doc.fullContent : doc.snippet;

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.docName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '复制全文',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: displayContent));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('文档内容已复制到剪贴板')),
                );
              }
            },
          ),
          if (doc.url.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: '打开原文链接',
              onPressed: () async {
                final uri = Uri.tryParse(doc.url);
                if (uri != null) await launchUrl(uri);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 文档元信息卡片
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.article_outlined, size: 20, color: scheme.tertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(doc.docName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _metaChip(context, Icons.source_outlined, doc.source),
                      if (doc.page.isNotEmpty)
                        _metaChip(context, Icons.bookmark_outline, '页 ${doc.page}'),
                      if (doc.bookName.isNotEmpty)
                        _metaChip(context, Icons.menu_book_outlined, '《${doc.bookName}》'),
                      if (doc.author.isNotEmpty)
                        _metaChip(context, Icons.person_outline, doc.author),
                      if (doc.hasImages)
                        _metaChip(context, Icons.image_outlined, '${doc.images.length} 张图'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 文本内容
          if (displayContent.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.text_snippet_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text('文档内容',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6), width: 0.6),
              ),
              child: SelectableText(
                displayContent,
                style: const TextStyle(fontSize: 14, height: 1.7),
              ),
            ),
          ],

          // 图片
          if (doc.hasImages) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.image_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text('原书图片',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 8),
            ...doc.images.map((img) => _KbImageView(image: img)),
          ],

          if (displayContent.isEmpty && !doc.hasImages)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('该文档无可用内容',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _metaChip(BuildContext context, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// 单张知识库图片，支持点击全屏查看
class _KbImageView extends StatelessWidget {
  final KbDocImage image;
  const _KbImageView({required this.image});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showFullScreen(context, image),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                image.url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 200,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.cumulativeBytesLoaded /
                            (progress.expectedTotalBytes ?? 1),
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stack) => Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3), width: 0.6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 32, color: Colors.red.shade400),
                      const SizedBox(height: 6),
                      Text('图片加载失败',
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade400)),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '可能是预签名链接已过期',
                          style: TextStyle(
                              fontSize: 10, color: Colors.red.shade300),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (image.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: SelectableText(
                image.caption,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullScreen(BuildContext context, KbDocImage image) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImage(image: image),
      ),
    );
  }
}

/// 全屏图片查看
class _FullScreenImage extends StatelessWidget {
  final KbDocImage image;
  const _FullScreenImage({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: Text(image.caption.isNotEmpty ? image.caption : '图片查看',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            maxScale: 4.0,
            child: Image.network(
              image.url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: progress.cumulativeBytesLoaded /
                        (progress.expectedTotalBytes ?? 1),
                    color: Colors.white,
                  ),
                );
              },
              errorBuilder: (context, error, stack) => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image, size: 48, color: Colors.white54),
                    SizedBox(height: 12),
                    Text('图片加载失败', style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
