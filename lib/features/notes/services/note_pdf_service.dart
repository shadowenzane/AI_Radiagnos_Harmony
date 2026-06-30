import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../diagnosis/models/diagnosis_item.dart';
import '../../diagnosis/models/kb_doc_snapshot.dart';
import '../models/note_data.dart';

/// 笔记 PDF 生成服务
///
/// 将一次检索结果（LLM 诊断 + 知识库文档/图片）整理为 PDF：
/// - 标题：疾病名 + 检索日期时间
/// - AI 诊断分段（临床表现/影像表现/报告模板/鉴别诊断/病理生理/治疗/参考来源）
/// - 知识库引用：每条文档按规范引用规则标注书名/作者/章节/页码/出版社 + 完整文本 + 图片
/// - 文件名：{疾病名}_{yyyyMMdd_HHmm}.pdf
class NotePdfService {
  NotePdfService._();

  // 中文字体缓存（避免每次生成 PDF 都重新加载）
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  /// 加载中文字体（Noto Sans SC TrueType），支持中文显示，避免乱码
  ///
  /// 注意：必须使用 TrueType(.ttf) 字体而非 OpenType CFF(.otf)，
  /// 因为 pdf 包仅将 TrueType(sfVersion 0x00010000) 识别为 Unicode 字体，
  /// OTF(CFF, 'OTTO') 会被当作非 Unicode 字体，导致中文触发 latin1.encode 报错。
  static Future<pw.Font> _loadRegularFont() async {
    if (_regularFont != null) return _regularFont!;
    try {
      final data = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
      _regularFont = pw.Font.ttf(data);
    } catch (_) {
      // 兜底：使用内置字体（中文会乱码，但至少 PDF 能生成）
      _regularFont = pw.Font.helvetica();
    }
    return _regularFont!;
  }

  static Future<pw.Font> _loadBoldFont() async {
    if (_boldFont != null) return _boldFont!;
    // 没有独立的 Bold TTF，复用 Regular（pdf 包不支持的变体字体无法取粗体，
    // 复用 Regular 可保证中文正常渲染，粗体效果通过字号/颜色区分）
    _boldFont = await _loadRegularFont();
    return _boldFont!;
  }

  /// 生成并保存 PDF，返回文件路径
  static Future<String> generateAndSave(NoteData note) async {
    final pdf = await _buildPdf(note);

    // 文件名：疾病名_日期时间.pdf（清洗疾病名中的文件名非法字符）
    final safeName = _sanitizeFileName(note.diseaseName);
    final timeStr = _formatTimeForFile(note.searchTime);
    final fileName = '${safeName}_$timeStr.pdf';

    // 保存到 应用文档目录/notes/
    final dir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${dir.path}/notes');
    if (!await notesDir.exists()) {
      await notesDir.create(recursive: true);
    }
    final file = File('${notesDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  /// 构建 PDF 文档
  static Future<pw.Document> _buildPdf(NoteData note) async {
    final doc = pw.Document();

    // 预加载中文字体
    await _loadRegularFont();
    await _loadBoldFont();

    // 预下载知识库图片（避免在 build 过程中阻塞）
    final imageBytes = <String, Uint8List>{};
    for (final doc_ in note.kbDocs) {
      for (final img in doc_.images) {
        if (imageBytes.containsKey(img.url)) continue;
        final bytes = await _downloadImage(img.url);
        if (bytes != null) {
          imageBytes[img.url] = bytes;
        }
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        // 强制每页白色背景，不随 App 主题变化
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          buildBackground: (ctx) => pw.Container(
            color: PdfColors.white,
            width: PdfPageFormat.a4.width,
            height: PdfPageFormat.a4.height,
          ),
        ),
        header: (ctx) => _buildHeader(note),
        footer: (ctx) => _buildFooter(ctx, note),
        build: (ctx) => _buildContent(ctx, note, imageBytes),
      ),
    );

    return doc;
  }

  // ==================== 页眉页脚 ====================

  static pw.Widget _buildHeader(NoteData note) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1.5, color: PdfColors.blue700)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('AI_Radiagnos 影像辅助诊断笔记',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: _regularFont!)),
          pw.Text('检索时间：${_formatTime(note.searchTime)}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: _regularFont!)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx, NoteData note) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 0.5, color: PdfColors.grey400)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('AI_Radiagnos · 仅供医学影像辅助诊断参考',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, font: _regularFont!)),
          pw.Text('第 ${ctx.pageNumber} 页',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, font: _regularFont!)),
        ],
      ),
    );
  }

  // ==================== 正文内容 ====================

  static List<pw.Widget> _buildContent(
    pw.Context ctx,
    NoteData note,
    Map<String, Uint8List> imageBytes,
  ) {
    final widgets = <pw.Widget>[];

    // 标题
    widgets.add(pw.Center(
      child: pw.Text(note.diseaseName,
          style: pw.TextStyle(fontSize: 22, font: _boldFont!, fontWeight: pw.FontWeight.bold)),
    ));
    widgets.add(pw.SizedBox(height: 6));
    widgets.add(pw.Center(
      child: pw.Text(
        '检查方法：${note.examType}　|　关键字：${note.keywords}',
        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, font: _regularFont!),
      ),
    ));
    widgets.add(pw.SizedBox(height: 16));

    // ===== AI 诊断部分 =====
    if (note.diagnosisItems.isNotEmpty) {
      widgets.add(_sectionTitle('AI 诊断结果'));
      if (note.modelNames.isNotEmpty) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text('来源模型：${note.modelNames.join("、")}',
              style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                  font: _regularFont!)),
        ));
      }

      for (var i = 0; i < note.diagnosisItems.length; i++) {
        final item = note.diagnosisItems[i];
        widgets.add(_diagnosisItemBlock(i + 1, item));
        widgets.add(pw.SizedBox(height: 10));
      }
    }

    // ===== 知识库引用部分 =====
    if (note.kbDocs.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(_sectionTitle('知识库引用'));
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text('共 ${note.kbDocs.length} 篇文档，引用信息按规范格式标注',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, font: _regularFont!)),
      ));

      for (var i = 0; i < note.kbDocs.length; i++) {
        final kbDoc = note.kbDocs[i];
        widgets.add(_kbDocBlock(i + 1, kbDoc, imageBytes));
        widgets.add(pw.SizedBox(height: 12));
      }
    }

    // 免责声明
    widgets.add(pw.SizedBox(height: 16));
    widgets.add(pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.amber300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        '免责声明：本笔记由 AI 大语言模型生成诊断建议，知识库引用来自第三方知识库服务。'
        'AI 生成内容仅供参考，不能替代专业医师的临床判断；最终诊断应由具有执业资格的影像科医师确认。'
        '知识库引用内容版权归原作者所有。',
        style: pw.TextStyle(
            fontSize: 8, color: PdfColors.grey700, lineSpacing: 1.5, font: _regularFont!),
      ),
    ));

    return widgets;
  }

  // ==================== AI 诊断条目块 ====================

  static pw.Widget _diagnosisItemBlock(int index, DiagnosisItem item) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$index. ${item.diseaseName}',
                  style: pw.TextStyle(
                      fontSize: 13, font: _boldFont!, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: pw.BoxDecoration(
                  color: _confidenceColor(item.confidence),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text('匹配度：${item.confidence}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.white, font: _regularFont!)),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _fieldRow('临床表现', item.clinicalManifestation),
          _fieldRow('影像学表现', item.imagingFindings),
          _fieldRow('标准报告模板', item.reportTemplate),
          _fieldRow('鉴别诊断及要点', item.differentialDiagnosis),
          _fieldRow('病理生理及症状学', item.pathophysiology),
          _fieldRow('临床治疗方法', item.treatment),
          if (item.references.trim().isNotEmpty)
            _fieldRow('参考来源', item.references),
        ],
      ),
    );
  }

  static pw.Widget _fieldRow(String title, String content) {
    if (content.trim().isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('【$title】',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                  font: _boldFont!)),
          pw.SizedBox(height: 2),
          pw.Text(content,
              style: pw.TextStyle(fontSize: 10, lineSpacing: 1.4, font: _regularFont!)),
        ],
      ),
    );
  }

  static PdfColor _confidenceColor(String confidence) {
    switch (confidence) {
      case '高':
        return PdfColors.green700;
      case '中':
        return PdfColors.blue700;
      default:
        return PdfColors.orange700;
    }
  }

  // ==================== 知识库文档块 ====================

  static pw.Widget _kbDocBlock(
    int index,
    KbDocSnapshot doc,
    Map<String, Uint8List> imageBytes,
  ) {
    final children = <pw.Widget>[];

    // 规范引用标注
    children.add(_citationLine(doc, index));

    // 完整文本
    final content = doc.fullContent.isNotEmpty ? doc.fullContent : doc.snippet;
    if (content.isNotEmpty) {
      children.add(pw.SizedBox(height: 4));
      children.add(pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        child: pw.Text(content,
            style: pw.TextStyle(fontSize: 9.5, lineSpacing: 1.5, font: _regularFont!)),
      ));
    }

    // 图片
    if (doc.images.isNotEmpty) {
      children.add(pw.SizedBox(height: 6));
      for (final img in doc.images) {
        final bytes = imageBytes[img.url];
        if (bytes != null) {
          final pdfImage = _tryDecodeImage(bytes);
          if (pdfImage != null) {
            children.add(pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(pdfImage, width: 380, height: 220, fit: pw.BoxFit.contain),
                  if (img.caption.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text('图：${img.caption}',
                          style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                              fontStyle: pw.FontStyle.italic,
                              font: _regularFont!)),
                    ),
                ],
              ),
            ));
          }
        } else {
          children.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text('[图片加载失败]',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.red400, font: _regularFont!)),
          ));
        }
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.teal200, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// 规范引用标注行
  ///
  /// 规则：作者. 书名[M]. 出版社, 章节, 第X页.
  /// 缺失项跳过；无书名/作者时用 docName + source 兜底。
  static pw.Widget _citationLine(KbDocSnapshot doc, int index) {
    final parts = <String>[];
    // 作者
    if (doc.author.trim().isNotEmpty) parts.add(doc.author.trim());
    // 书名
    if (doc.bookName.trim().isNotEmpty) {
      parts.add('《${doc.bookName.trim()}》[M]');
    } else if (doc.docName.trim().isNotEmpty && doc.docName != '未知文档') {
      parts.add('《${doc.docName.trim()}》[M]');
    }
    // 章节
    if (doc.chapter.trim().isNotEmpty) parts.add('第${doc.chapter.trim()}章');
    // 页码
    if (doc.page.trim().isNotEmpty) parts.add('第${doc.page.trim()}页');
    // 来源（知识库名，作为出版/来源信息兜底）
    if (doc.source.trim().isNotEmpty) parts.add(doc.source.trim());

    String citation;
    if (parts.isEmpty) {
      citation = '[$index] 引用文档';
    } else {
      // 作者. 书名. 章节, 页码, 来源
      final authorBook = <String>[];
      if (doc.author.trim().isNotEmpty) authorBook.add(doc.author.trim());
      if (doc.bookName.trim().isNotEmpty) {
        authorBook.add('《${doc.bookName.trim()}》[M]');
      } else if (doc.docName.trim().isNotEmpty && doc.docName != '未知文档') {
        authorBook.add('《${doc.docName.trim()}》[M]');
      }
      final tail = <String>[];
      if (doc.chapter.trim().isNotEmpty) tail.add('第${doc.chapter.trim()}章');
      if (doc.page.trim().isNotEmpty) tail.add('第${doc.page.trim()}页');
      if (doc.source.trim().isNotEmpty) tail.add(doc.source.trim());

      final tailStr = tail.isNotEmpty ? ' ${tail.join(", ")}.' : '';
      citation = '[$index] ${authorBook.join(". ")}.$tailStr';
      // 清理多余的点和空格
      citation = citation.replaceAll(RegExp(r'\.{2,}'), '.').trim();
    }

    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '引用 $citation',
            style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.teal800,
                fontStyle: pw.FontStyle.italic,
                font: _regularFont!),
          ),
        ],
      ),
    );
  }

  // ==================== 辅助方法 ====================

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const pw.BoxDecoration(color: PdfColors.blue700),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: _boldFont!)),
    );
  }

  /// 下载图片字节（失败返回 null）
  static Future<Uint8List?> _downloadImage(String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (resp.statusCode >= 200 && resp.statusCode < 300 && resp.bodyBytes.isNotEmpty) {
        return resp.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  /// 尝试解码图片字节为 PDF 图片
  static pw.ImageProvider? _tryDecodeImage(Uint8List bytes) {
    try {
      // pdf 包自动识别 png/jpeg
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  /// 文件名安全化：去除文件名非法字符
  static String _sanitizeFileName(String name) {
    var safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    safe = safe.replaceAll(RegExp(r'\s+'), '_');
    safe = safe.replaceAll(RegExp(r'[（）()【】\[\]{}]'), '');
    if (safe.isEmpty) safe = 'note';
    if (safe.length > 40) safe = safe.substring(0, 40);
    return safe;
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  static String _formatTimeForFile(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}';
  }
}
