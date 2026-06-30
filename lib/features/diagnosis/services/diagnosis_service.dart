import 'dart:async';
import '../../../core/constants.dart';
import '../../../core/disease_name_sanitizer.dart';
import '../../../core/errors.dart';
import '../../ai_config/models/provider_config.dart';
import '../../ai_config/repositories/ai_config_repo.dart';
import '../../kb_config/models/knowledge_config.dart';
import '../../kb_config/repositories/kb_config_repo.dart';
import '../models/diagnosis_item.dart';
import '../models/kb_doc_snapshot.dart';
import 'knowledge_base_service.dart';
import 'llm_service.dart';

/// 诊断服务
///
/// 支持三种检索模式：
/// 1. LLM + 知识库：并行调 LLM 获取诊断 → 取 top 1-3 疾病 → 清洗疾病名 → 查知识库
/// 2. 仅 LLM：并行调 LLM 获取诊断
/// 3. 仅知识库：直接用关键字查知识库
class DiagnosisService {
  final AiConfigRepo _aiRepo;
  final KbConfigRepo _kbRepo;

  DiagnosisService(this._aiRepo, this._kbRepo);

  /// 诊断主入口
  ///
  /// [selectedProviderIds] 选中的 LLM ID 列表（0-3 个）
  /// [selectedKbIds] 选中的知识库 ID 列表（0-3 个）
  /// [onModelComplete] 每个模型完成时的回调
  Future<DiagnosisResult> diagnose({
    required String examType,
    required String keywords,
    required List<String> selectedProviderIds,
    required List<String> selectedKbIds,
    void Function(ModelDiagnosisResult)? onModelComplete,
  }) async {
    // 准备选中的 LLM 配置
    final providers = _aiRepo.providers
        .where((p) => selectedProviderIds.contains(p.id) && p.enabled)
        .toList();

    // 准备选中的知识库配置 + 凭证（按类型校验凭证完整性，火山方舟仅需 AK/SK）
    final kbConfigs = <KnowledgeConfig>[];
    final kbCredentials = <String, Map<String, String>>{};
    for (final kb in _kbRepo.configs.where((c) => selectedKbIds.contains(c.id) && c.enabled)) {
      final creds = await _kbRepo.getCredentials(kb.id);
      if (KnowledgeBaseService.validateCredentials(kb.type, creds) == null) {
        kbConfigs.add(kb);
        kbCredentials[kb.id] = creds;
      }
    }

    final hasLlm = providers.isNotEmpty;
    final hasKb = kbConfigs.isNotEmpty;

    if (!hasLlm && !hasKb) {
      throw Exception('请至少选择一个大模型或知识库');
    }

    // ========== 模式3：仅知识库 ==========
    if (!hasLlm && hasKb) {
      return _diagnoseKbOnly(
        examType: examType,
        keywords: keywords,
        kbConfigs: kbConfigs,
        kbCredentials: kbCredentials,
      );
    }

    // ========== 模式1+2：有 LLM ==========
    return _diagnoseWithLlm(
      examType: examType,
      keywords: keywords,
      providers: providers,
      kbConfigs: kbConfigs,
      kbCredentials: kbCredentials,
      onModelComplete: onModelComplete,
    );
  }

  // ==================== 模式1+2：有 LLM ====================

  Future<DiagnosisResult> _diagnoseWithLlm({
    required String examType,
    required String keywords,
    required List<ProviderConfig> providers,
    required List<KnowledgeConfig> kbConfigs,
    required Map<String, Map<String, String>> kbCredentials,
    void Function(ModelDiagnosisResult)? onModelComplete,
  }) async {
    // 第一步：并行调 LLM（不使用知识库上下文，与桌面版一致）
    final results = <ModelDiagnosisResult>[];
    final futures = providers.map((p) async {
      final result = await _queryOneModel(
        provider: p,
        examType: examType,
        keywords: keywords,
      );
      if (onModelComplete != null) onModelComplete(result);
      return result;
    });
    results.addAll(await Future.wait(futures));

    // 第二步：如果有知识库，取 top 1-3 疾病清洗后查知识库
    List<KbGroupResult> kbGroups = [];
    if (kbConfigs.isNotEmpty) {
      kbGroups = await _enrichWithKbSnapshots(
        results: results,
        examType: examType,
        keywords: keywords,
        kbConfigs: kbConfigs,
        kbCredentials: kbCredentials,
      );
    }

    return DiagnosisResult(
      modelResults: results,
      kbGroups: kbGroups,
      mode: kbConfigs.isNotEmpty ? DiagnosisMode.llmAndKb : DiagnosisMode.llmOnly,
    );
  }

  /// 单个模型的完整查询
  Future<ModelDiagnosisResult> _queryOneModel({
    required ProviderConfig provider,
    required String examType,
    required String keywords,
  }) async {
    final info = kProviders[provider.provider];
    final modelName = provider.displayName.isNotEmpty
        ? provider.displayName
        : (info?.name ?? provider.provider);

    try {
      final apiKey = await _aiRepo.getApiKey(provider.id);
      if (apiKey == null || apiKey.isEmpty) {
        return ModelDiagnosisResult(
          modelName: modelName,
          providerKey: provider.provider,
          success: false,
          errorMessage: '该模型未配置 API Key',
        );
      }

      // 根据检查类型选择 Prompt
      final isEcg = examType.contains('ECG') || examType.contains('心电图');
      final promptTemplate = isEcg ? kEcgDiagnosisPrompt : kDiagnosisPrompt;
      final prompt = isEcg
          ? promptTemplate.replaceAll('{keywords}', keywords)
          : promptTemplate
              .replaceAll('{exam_type}', examType)
              .replaceAll('{keywords}', keywords);

      final messages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content': isEcg
              ? '你是一个资深心电诊断专家。请始终以纯JSON数组格式回复，不要包含markdown代码块标记。'
              : '你是一个资深医学影像诊断专家。请始终以纯JSON数组格式回复，不要包含markdown代码块标记。',
        },
        {'role': 'user', 'content': prompt},
      ];

      final content = await LlmService.call(
        providerConfig: provider,
        apiKey: apiKey,
        messages: messages,
      );

      final jsonList = LlmService.parseJsonArray(content);
      final items = jsonList.map((j) => DiagnosisItem.fromJson(j)).toList();
      final trimmed = items.length > 3 ? items.sublist(0, 3) : items;

      return ModelDiagnosisResult(
        modelName: modelName,
        providerKey: provider.provider,
        success: true,
        items: trimmed,
      );
    } catch (e) {
      return ModelDiagnosisResult(
        modelName: modelName,
        providerKey: provider.provider,
        success: false,
        errorMessage: e is AppError ? e.message : e.toString(),
      );
    }
  }

  /// 取匹配度最高的 1-3 个疾病，清洗后查知识库
  ///
  /// 疾病名清洗逻辑（对齐桌面版 _sanitize_disease_name）：
  /// - 含英文/特殊字符的疾病名 → 仅保留中文名查知识库
  ///
  /// QPS 限流：知识库查询之间强制间隔 >1s，规避火山方舟 HTTP 429
  Future<List<KbGroupResult>> _enrichWithKbSnapshots({
    required List<ModelDiagnosisResult> results,
    required String examType,
    required String keywords,
    required List<KnowledgeConfig> kbConfigs,
    required Map<String, Map<String, String>> kbCredentials,
  }) async {
    // 收集所有成功结果中的疾病，按 confidence 排序
    final allDiseases = <_DiseaseRef>[];
    for (final r in results) {
      if (!r.success) continue;
      for (final item in r.items) {
        allDiseases.add(_DiseaseRef(
          diseaseName: item.diseaseName,
          confidence: item.confidence,
        ));
      }
    }
    if (allDiseases.isEmpty) return <KbGroupResult>[];

    // 去重 + 排序（高 > 中 > 低）
    final seen = <String>{};
    final unique = <_DiseaseRef>[];
    for (final d in allDiseases) {
      // 清洗疾病名用于去重
      final cleanName = DiseaseNameSanitizer.sanitize(d.diseaseName);
      if (seen.add(cleanName)) {
        unique.add(d);
      }
    }
    unique.sort((a, b) => _confidenceWeight(b.confidence)
        .compareTo(_confidenceWeight(a.confidence)));

    // 取 Top 3，对每个疾病清洗后查知识库
    final topDiseases = unique.take(3).toList();

    final kbGroups = <KbGroupResult>[];
    // QPS 限流：记录上次知识库查询完成时间，确保两次查询间隔 >1s
    DateTime? lastKbQueryTime;

    for (final d in topDiseases) {
      // 清洗疾病名：去除英文和特殊字符，仅用中文名检索
      final searchName = DiseaseNameSanitizer.sanitize(d.diseaseName);

      final allDocs = <KbDocSnapshot>[];
      final warnings = <String>[];

      // 对每个选中的知识库分别查询
      for (final kbConfig in kbConfigs) {
        final creds = kbCredentials[kbConfig.id];
        if (creds == null) continue;

        // QPS 限流：两次查询间至少间隔 1.1s（>1s，规避 429）
        await _waitKbQpsInterval(lastKbQueryTime);

        final result = await KnowledgeBaseService.query(
          kbConfig: kbConfig,
          credentials: creds,
          diseaseName: searchName,
          examType: examType,
          keywords: keywords,
        );
        lastKbQueryTime = DateTime.now();

        allDocs.addAll(result.docs);
        if (result.warning != null && result.warning!.isNotEmpty) {
          warnings.add('${kbConfig.displayName}: ${result.warning}');
        }
      }

      // 去重
      final docSeen = <String>{};
      final dedupedDocs = <KbDocSnapshot>[];
      for (final doc in allDocs) {
        final snippetPart = doc.snippet.length > 50
            ? doc.snippet.substring(0, 50)
            : doc.snippet;
        final key = '${doc.docName}|${doc.page}|$snippetPart';
        if (docSeen.add(key)) {
          dedupedDocs.add(doc);
        }
      }

      kbGroups.add(KbGroupResult(
        diseaseName: d.diseaseName,
        searchName: searchName,
        docs: dedupedDocs,
        warning: warnings.isNotEmpty ? warnings.join('\n') : null,
      ));
    }

    return kbGroups;
  }

  /// 知识库 QPS 限流：确保两次查询间隔 >= 1.1s（>1s）
  /// [lastQueryTime] 上次查询完成时间；为 null 表示首次查询，无需等待
  static Future<void> _waitKbQpsInterval(DateTime? lastQueryTime) async {
    if (lastQueryTime == null) return;
    const minInterval = Duration(milliseconds: 1100);
    final elapsed = DateTime.now().difference(lastQueryTime);
    if (elapsed < minInterval) {
      await Future.delayed(minInterval - elapsed);
    }
  }

  // ==================== 模式3：仅知识库 ====================

  Future<DiagnosisResult> _diagnoseKbOnly({
    required String examType,
    required String keywords,
    required List<KnowledgeConfig> kbConfigs,
    required Map<String, Map<String, String>> kbCredentials,
  }) async {
    // 仅知识库模式：直接用关键字查每个知识库
    final kbGroups = <KbGroupResult>[];
    DateTime? lastKbQueryTime;

    for (final kbConfig in kbConfigs) {
      final creds = kbCredentials[kbConfig.id];
      if (creds == null) continue;

      // QPS 限流：两次查询间至少间隔 1.1s（>1s，规避 429）
      await _waitKbQpsInterval(lastKbQueryTime);

      final result = await KnowledgeBaseService.query(
        kbConfig: kbConfig,
        credentials: creds,
        diseaseName: '', // 不用疾病名，直接用关键字
        examType: examType,
        keywords: keywords,
      );
      lastKbQueryTime = DateTime.now();

      kbGroups.add(KbGroupResult(
        diseaseName: keywords,
        searchName: keywords,
        docs: result.docs,
        warning: result.warning,
        kbDisplayName: kbConfig.displayName,
      ));
    }

    return DiagnosisResult(
      modelResults: [],
      kbGroups: kbGroups,
      mode: DiagnosisMode.kbOnly,
    );
  }

  int _confidenceWeight(String confidence) {
    switch (confidence) {
      case '高':
        return 3;
      case '中':
        return 2;
      default:
        return 1;
    }
  }
}

// ==================== 数据模型 ====================

/// 诊断结果（含 LLM 结果和知识库分组）
class DiagnosisResult {
  final List<ModelDiagnosisResult> modelResults;
  final List<KbGroupResult> kbGroups;
  final DiagnosisMode mode;

  const DiagnosisResult({
    required this.modelResults,
    required this.kbGroups,
    required this.mode,
  });
}

/// 诊断模式
enum DiagnosisMode {
  llmOnly,    // 仅 LLM
  kbOnly,     // 仅知识库
  llmAndKb,   // LLM + 知识库
}

/// 知识库分组结果（按疾病分组）
class KbGroupResult {
  /// 原始疾病名（LLM 返回的）
  final String diseaseName;

  /// 清洗后的检索名（去英文/特殊字符）
  final String searchName;

  /// 知识库返回的文档快照
  final List<KbDocSnapshot> docs;

  /// 查询过程中的警告
  final String? warning;

  /// 知识库显示名（仅知识库模式用）
  final String? kbDisplayName;

  const KbGroupResult({
    required this.diseaseName,
    required this.searchName,
    required this.docs,
    this.warning,
    this.kbDisplayName,
  });
}

class _DiseaseRef {
  final String diseaseName;
  final String confidence;
  const _DiseaseRef({required this.diseaseName, required this.confidence});
}
