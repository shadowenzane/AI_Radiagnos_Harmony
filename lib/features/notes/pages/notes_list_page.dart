import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_data.dart';
import '../repositories/notes_repo.dart';
import 'pdf_viewer_page.dart';

/// 已保存笔记列表页
///
/// 展示已保存的 PDF 笔记，支持打开（应用内置 PDF 查看器）、分享、删除。
class NotesListPage extends StatelessWidget {
  const NotesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<NotesRepo>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('我的笔记')),
      body: repo.notes.isEmpty
          ? _buildEmpty(scheme)
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: repo.notes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final note = repo.notes[i];
                return _NoteTile(note: note);
              },
            ),
    );
  }

  Widget _buildEmpty(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_alt_outlined, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            const Text('暂无已保存的笔记',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('在检索结果页点击「保存为笔记」按钮\n可将诊断结果与知识库引用导出为 PDF',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final NoteMeta note;
  const _NoteTile({required this.note});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.picture_as_pdf, color: scheme.error, size: 22),
      ),
      title: Text(note.diseaseName,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(_formatTime(note.savedAt),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Row(
            children: [
              if (note.examType.isNotEmpty)
                _tag(context, note.examType),
              if (note.description.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(note.description,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                ),
              ],
              const SizedBox(width: 6),
              Text(_formatSize(note.fileSize),
                  style: TextStyle(fontSize: 11, color: scheme.outline)),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (v) async => _handleAction(context, v),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'open', child: Text('打开')),
          PopupMenuItem(value: 'share', child: Text('分享')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
      onTap: () => _handleAction(context, 'open'),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final repo = context.read<NotesRepo>();
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text('确认删除笔记「${note.diseaseName}」？\nPDF 文件将一并删除。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
          ],
        ),
      );
      if (ok == true) {
        await repo.deleteNote(note.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
        }
      }
      return;
    }
    if (action == 'share') {
      await repo.shareNote(note.id);
      return;
    }
    // open：使用应用内置 PDF 查看器打开
    final path = await repo.getNoteFilePath(note.id);
    if (path == null) return;
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          filePath: path,
          title: note.diseaseName,
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: scheme.onPrimaryContainer)),
    );
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
