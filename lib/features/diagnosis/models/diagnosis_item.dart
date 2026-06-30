import 'package:equatable/equatable.dart';
import 'kb_doc_snapshot.dart';

/// 单条诊断结果（对应 LLM 返回 JSON 数组中的一项）
class DiagnosisItem extends Equatable {
  final String diseaseName;
  final String confidence; // 高/中/低
  final String imagingFindings;
  final String reportTemplate;
  final String differentialDiagnosis;
  final String clinicalManifestation;
  final String pathophysiology;
  final String treatment;

  /// 参考来源（LLM 自行标注的教材/指南/作者/章节等引用信息）
  final String references;

  /// 由该诊断派生出的知识库快照（来自匹配度 Top 1-3 疾病查询）
  final List<KbDocSnapshot> kbDocs;

  const DiagnosisItem({
    required this.diseaseName,
    this.confidence = '中',
    this.imagingFindings = '',
    this.reportTemplate = '',
    this.differentialDiagnosis = '',
    this.clinicalManifestation = '',
    this.pathophysiology = '',
    this.treatment = '',
    this.references = '',
    this.kbDocs = const [],
  });

  DiagnosisItem copyWith({List<KbDocSnapshot>? kbDocs}) {
    return DiagnosisItem(
      diseaseName: diseaseName,
      confidence: confidence,
      imagingFindings: imagingFindings,
      reportTemplate: reportTemplate,
      differentialDiagnosis: differentialDiagnosis,
      clinicalManifestation: clinicalManifestation,
      pathophysiology: pathophysiology,
      treatment: treatment,
      references: references,
      kbDocs: kbDocs ?? this.kbDocs,
    );
  }

  factory DiagnosisItem.fromJson(Map<String, dynamic> json) {
    return DiagnosisItem(
      diseaseName: json['disease_name'] as String? ?? '未知',
      confidence: json['confidence'] as String? ?? '中',
      imagingFindings: json['imaging_findings'] as String? ?? '',
      reportTemplate: json['report_template'] as String? ?? '',
      differentialDiagnosis: json['differential_diagnosis'] as String? ?? '',
      clinicalManifestation: json['clinical_manifestation'] as String? ?? '',
      pathophysiology: json['pathophysiology'] as String? ?? '',
      treatment: json['treatment'] as String? ?? '',
      references: json['references'] as String? ??
          json['reference'] as String? ??
          '',
    );
  }

  @override
  List<Object?> get props => [diseaseName, confidence];
}

/// 单个 AI 模型的查询结果
class ModelDiagnosisResult extends Equatable {
  final String modelName;     // UI 显示名（如 "我的 DeepSeek"）
  final String providerKey;   // kProviders 的 key
  final bool success;
  final List<DiagnosisItem> items;
  final String errorMessage;

  const ModelDiagnosisResult({
    required this.modelName,
    required this.providerKey,
    required this.success,
    this.items = const [],
    this.errorMessage = '',
  });

  @override
  List<Object?> get props => [modelName, success];
}
