import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// 应用内置 PDF 查看器
///
/// 使用 printing 包的 raster 方法将 PDF 每页栅格化为图片，在应用内展示。
/// 解决 url_launcher 在 Android 11+ 无法直接打开 file:// URI 的问题。
class PdfViewerPage extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfViewerPage({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final List<Uint8List> _pages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _error = '文件不存在';
            _loading = false;
          });
        }
        return;
      }
      final bytes = await file.readAsBytes();
      // 使用较高 DPI 渲染，保证清晰度
      final pages = <Uint8List>[];
      await for (final raster in Printing.raster(bytes, dpi: 150)) {
        pages.add(await raster.toPng());
      }
      if (mounted) {
        setState(() {
          _pages.addAll(pages);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      // PDF 查看器始终使用白色背景，不随 App 主题变化
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在加载 PDF…', style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 12),
              Text('加载失败', style: TextStyle(color: scheme.error, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    if (_pages.isEmpty) {
      return Center(
        child: Text('PDF 为空', style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _pages.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Image.memory(
            _pages[i],
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}
