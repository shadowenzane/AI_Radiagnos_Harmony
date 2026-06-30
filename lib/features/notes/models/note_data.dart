import '../../../core/disease_name_sanitizer.dart';
import '../../diagnosis/models/diagnosis_item.dart';
import '../../diagnosis/models/kb_doc_snapshot.dart';
import '../../diagnosis/services/diagnosis_service.dart';

/// 笔记数据：聚合一次检索结果，用于导出 PDF
///
/// 内容包括：
/// - 元信息：检查方法、关键字、检索时间、主疾病名
/// - LLM 诊断条目（临床表现/影像表现/报告模板/鉴别诊断/病理生理/治疗/参考来源）
/// - 知识库文档（完整文本 + 图片 + 规范引用信息）
class NoteData {
  /// 主疾病名（用于文件名和标题）
  /// LLM 模式取 top1 疾病名；仅知识库模式取关键字
  final String diseaseName;

  /// 检查方法
  final String examType;

  /// 关键字
  final String keywords;

  /// 检索时间
  final DateTime searchTime;

  /// 诊断模式
  final DiagnosisMode mode;

  /// LLM 诊断条目（可能多个模型，扁平合并）
  final List<DiagnosisItem> diagnosisItems;

  /// 模型显示名列表（标注来源）
  final List<String> modelNames;

  /// 知识库文档（扁平合并所有分组的文档）
  final List<KbDocSnapshot> kbDocs;

  /// 知识库分组（保留疾病分组信息，用于引用组织）
  final List<KbGroupResult> kbGroups;

  const NoteData({
    required this.diseaseName,
    required this.examType,
    required this.keywords,
    required this.searchTime,
    required this.mode,
    required this.diagnosisItems,
    required this.modelNames,
    required this.kbDocs,
    required this.kbGroups,
  });

  /// 从诊断结果组装笔记数据
  factory NoteData.fromDiagnosisResult({
    required DiagnosisResult result,
    required String examType,
    required String keywords,
    DateTime? searchTime,
  }) {
    // 主疾病名：LLM 模式取第一个成功结果的第一个疾病名；仅知识库取关键字
    String diseaseName = keywords;
    final diagnosisItems = <DiagnosisItem>[];
    final modelNames = <String>[];

    if (result.modelResults.isNotEmpty) {
      for (final mr in result.modelResults) {
        if (mr.success && mr.items.isNotEmpty) {
          modelNames.add(mr.modelName);
          diagnosisItems.addAll(mr.items);
        }
      }
      if (diagnosisItems.isNotEmpty) {
        diseaseName = diagnosisItems.first.diseaseName;
      }
    }

    // 扁平合并所有知识库文档
    final kbDocs = <KbDocSnapshot>[];
    final seen = <String>{};
    for (final g in result.kbGroups) {
      for (final doc in g.docs) {
        final key = '${doc.docName}|${doc.page}|${doc.snippet}';
        if (seen.add(key)) {
          kbDocs.add(doc);
        }
      }
    }

    return NoteData(
      diseaseName: diseaseName,
      examType: examType,
      keywords: keywords,
      searchTime: searchTime ?? DateTime.now(),
      mode: result.mode,
      diagnosisItems: diagnosisItems,
      modelNames: modelNames,
      kbDocs: kbDocs,
      kbGroups: result.kbGroups,
    );
  }

  /// 从诊断结果中按单个疾病拆分出笔记数据
  ///
  /// 用于"每条疾病分别保存为 PDF"场景：
  /// - 仅保留该疾病对应的 LLM 诊断条目（按清洗后的疾病名匹配）
  /// - 仅保留该疾病对应的知识库分组及文档
  /// - 文件名/标题使用该疾病名
  factory NoteData.forDisease({
    required String diseaseName,
    required DiagnosisResult result,
    required String examType,
    required String keywords,
    DateTime? searchTime,
  }) {
    final cleanTarget = DiseaseNameSanitizer.sanitize(diseaseName);

    // 筛选该疾病的 LLM 诊断条目
    final diagnosisItems = <DiagnosisItem>[];
    final modelNames = <String>{};
    for (final mr in result.modelResults) {
      if (!mr.success) continue;
      final matching = mr.items.where((item) =>
          DiseaseNameSanitizer.sanitize(item.diseaseName) == cleanTarget).toList();
      if (matching.isNotEmpty) {
        diagnosisItems.addAll(matching);
        modelNames.add(mr.modelName);
      }
    }

    // 筛选该疾病的知识库分组
    final matchingKbGroups = result.kbGroups.where((g) =>
        DiseaseNameSanitizer.sanitize(g.diseaseName) == cleanTarget).toList();

    // 扁平合并文档（去重）
    final kbDocs = <KbDocSnapshot>[];
    final seen = <String>{};
    for (final g in matchingKbGroups) {
      for (final doc in g.docs) {
        final key = '${doc.docName}|${doc.page}|${doc.snippet}';
        if (seen.add(key)) {
          kbDocs.add(doc);
        }
      }
    }

    return NoteData(
      diseaseName: diseaseName,
      examType: examType,
      keywords: keywords,
      searchTime: searchTime ?? DateTime.now(),
      mode: result.mode,
      diagnosisItems: diagnosisItems,
      modelNames: modelNames.toList(),
      kbDocs: kbDocs,
      kbGroups: matchingKbGroups,
    );
  }

  /// 从诊断结果中收集所有可拆分保存的疾病名（去重，保留出现顺序）
  ///
  /// 优先使用知识库分组中的疾病名（用户需求：知识库搜索的每条疾病分别保存）；
  /// 若无知识库分组（仅 LLM 模式），则使用 LLM 返回的疾病名。
  static List<String> collectDiseaseNames(DiagnosisResult result) {
    final seen = <String>{};
    final names = <String>[];

    void add(String name) {
      final clean = DiseaseNameSanitizer.sanitize(name);
      if (seen.add(clean)) {
        names.add(name);
      }
    }

    // 优先：知识库分组中的疾病名
    for (final g in result.kbGroups) {
      add(g.diseaseName);
    }

    // 补充：LLM 返回的疾病名（仅当没有知识库分组时使用）
    if (names.isEmpty) {
      for (final mr in result.modelResults) {
        if (!mr.success) continue;
        for (final item in mr.items) {
          add(item.diseaseName);
        }
      }
    }

    return names;
  }

  /// 笔记简要描述（用于列表展示）
  String get description {
    final parts = <String>[];
    parts.add(examType);
    if (diagnosisItems.isNotEmpty) parts.add('${diagnosisItems.length} 条诊断');
    if (kbDocs.isNotEmpty) parts.add('${kbDocs.length} 篇引用');
    return parts.join(' · ');
  }
}

/// 已保存笔记的元信息（持久化用，不含 PDF 内容）
class NoteMeta {
  final String id;
  final String diseaseName;
  final String examType;
  final String keywords;
  final DateTime savedAt;
  final String description;
  final String fileName;
  final int fileSize;

  const NoteMeta({
    required this.id,
    required this.diseaseName,
    required this.examType,
    required this.keywords,
    required this.savedAt,
    required this.description,
    required this.fileName,
    required this.fileSize,
  });

  factory NoteMeta.fromJson(Map<String, dynamic> json) {
    return NoteMeta(
      id: json['id'] as String,
      diseaseName: json['disease_name'] as String,
      examType: json['exam_type'] as String,
      keywords: json['keywords'] as String,
      savedAt: DateTime.tryParse(json['saved_at'] as String? ?? '') ?? DateTime.now(),
      description: json['description'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      fileSize: json['file_size'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'disease_name': diseaseName,
        'exam_type': examType,
        'keywords': keywords,
        'saved_at': savedAt.toIso8601String(),
        'description': description,
        'file_name': fileName,
        'file_size': fileSize,
      };
}
