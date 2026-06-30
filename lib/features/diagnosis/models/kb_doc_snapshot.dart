import 'package:equatable/equatable.dart';

/// 知识库文档快照
///
/// 承载一次知识库检索返回的文档引用信息。
/// 不同知识库返回的字段完整度不同：
/// - 腾讯 IMA：通常有 docName + snippet，可能有 page
/// - 火山方舟：通常有 docName + snippet + fullContent + images（原书图片）
/// - NotebookLM：Web 引用有 url + title；retrievedContext 有 title + text
///
/// v1.3.3 新增 fullContent / images 字段，支持查看知识库完整文本及原书图片。
class KbDocSnapshot extends Equatable {
  /// 文档/网页标题
  final String docName;

  /// 引用书名（如有）
  final String bookName;

  /// 作者（如有）
  final String author;

  /// 章节（如有）
  final String chapter;

  /// 页码（如有）
  final String page;

  /// 文本快照（截断，用于列表预览）
  final String snippet;

  /// 完整文本内容（不截断，用于查看器显示）
  final String fullContent;

  /// 原书图片列表（火山方舟 chunk_attachment 中的 image 类型）
  final List<KbDocImage> images;

  /// 原始链接
  final String url;

  /// 来源标识（如 "腾讯 IMA" / "火山方舟" / "Google NotebookLM"）
  final String source;

  /// 匹配度评分（0-1，部分知识库返回）
  final double score;

  const KbDocSnapshot({
    required this.docName,
    this.bookName = '',
    this.author = '',
    this.chapter = '',
    this.page = '',
    required this.snippet,
    this.fullContent = '',
    this.images = const [],
    this.url = '',
    required this.source,
    this.score = 0,
  });

  factory KbDocSnapshot.fromJson(Map<String, dynamic> json) {
    return KbDocSnapshot(
      docName: json['doc_name'] as String? ?? '未知文档',
      bookName: json['book_name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      chapter: json['chapter'] as String? ?? '',
      page: (json['page'] ?? '').toString(),
      snippet: json['snippet'] as String? ?? '',
      fullContent: json['full_content'] as String? ?? '',
      images: ((json['images'] as List?) ?? [])
          .map((e) => KbDocImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      url: json['url'] as String? ?? '',
      source: json['source'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'doc_name': docName,
        'book_name': bookName,
        'author': author,
        'chapter': chapter,
        'page': page,
        'snippet': snippet,
        'full_content': fullContent,
        'images': images.map((e) => e.toJson()).toList(),
        'url': url,
        'source': source,
        'score': score,
      };

  /// 是否有完整内容（可展开查看器）
  bool get hasFullContent => fullContent.isNotEmpty && fullContent != snippet;

  /// 是否有图片
  bool get hasImages => images.isNotEmpty;

  /// 格式化的引用字符串（用于报告模板）
  ///
  /// 示例：
  /// - 《放射学诊断》张三 主编，第3章 肺结节，第45页
  /// - 肝脏占位性病变诊断要点 · 腾讯 IMA
  /// - Web 引用 - https://example.com/article
  String get citation {
    final parts = <String>[];
    if (bookName.isNotEmpty) parts.add('《$bookName》');
    if (author.isNotEmpty) parts.add(author);
    if (chapter.isNotEmpty) parts.add('第$chapter章');
    if (page.isNotEmpty) parts.add('第$page页');
    if (parts.isEmpty) {
      // 无书名/作者/章节时，用 docName + source
      if (docName.isNotEmpty && docName != '未知文档') {
        parts.add(docName);
      }
      if (source.isNotEmpty) parts.add(source);
    }
    return parts.join(' · ');
  }

  /// 是否有完整的引用信息（书名+作者 至少一项）
  bool get hasFullCitation =>
      bookName.isNotEmpty || author.isNotEmpty || chapter.isNotEmpty;

  @override
  List<Object?> get props =>
      [docName, bookName, author, chapter, page, snippet, fullContent, images, url, source, score];
}

/// 知识库文档中的图片引用（对齐桌面版 images 列表）
class KbDocImage extends Equatable {
  /// 图片预签名 URL
  final String url;

  /// 图片说明（caption）
  final String caption;

  const KbDocImage({required this.url, this.caption = ''});

  factory KbDocImage.fromJson(Map<String, dynamic> json) {
    return KbDocImage(
      url: json['url'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'caption': caption};

  @override
  List<Object?> get props => [url, caption];
}
