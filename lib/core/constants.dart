/// AI 提供商与知识库提供商常量定义
/// 移植自桌面版 ai_helper.py 的 PROVIDERS / KNOWLEDGE_PROVIDERS。
/// 新增 mimo（小米 MiMo）以匹配需求清单。

class ProviderInfo {
  final String key;
  final String name;
  final String apiUrl;
  final String apiType; // 'chat_completions' | 'responses'
  final List<String> models;
  final String? note;

  const ProviderInfo({
    required this.key,
    required this.name,
    required this.apiUrl,
    required this.apiType,
    required this.models,
    this.note,
  });
}

class KnowledgeProviderInfo {
  final String key;
  final String name;
  final String apiUrl;
  final String description;

  const KnowledgeProviderInfo({
    required this.key,
    required this.name,
    required this.apiUrl,
    required this.description,
  });
}

/// 支持的大模型提供商
const Map<String, ProviderInfo> kProviders = {
  'deepseek': ProviderInfo(
    key: 'deepseek',
    name: 'DeepSeek',
    apiUrl: 'https://api.deepseek.com/v1/chat/completions',
    apiType: 'chat_completions',
    models: ['deepseek-chat', 'deepseek-reasoner', 'deepseek-v4-flash', 'deepseek-v4-pro'],
  ),
  'doubao': ProviderInfo(
    key: 'doubao',
    name: '豆包(火山引擎)',
    apiUrl: 'https://ark.cn-beijing.volces.com/api/v3/responses',
    apiType: 'responses',
    models: [
      'doubao-seed-2-0-pro-260215',
      'doubao-seed-2-0-lite-260215',
      'doubao-seed-2-0-mini-260215',
      'doubao-seed-2-0-code-preview-260215',
      'doubao-seed-character',
      'doubao-seed-1-6-250715',
      'doubao-seed-1-6-lite-250715',
      'doubao-seed-1-6-flash-250715',
      'doubao-1-5-pro-32k',
      'doubao-1-5-lite-32k',
    ],
    note: '也可填入火山方舟的 Endpoint ID（如 ep-xxxxxxxx）',
  ),
  'openai': ProviderInfo(
    key: 'openai',
    name: 'OpenAI',
    apiUrl: 'https://api.openai.com/v1/chat/completions',
    apiType: 'chat_completions',
    models: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'],
  ),
  'zhipu': ProviderInfo(
    key: 'zhipu',
    name: '智谱AI (GLM)',
    apiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    apiType: 'chat_completions',
    models: ['glm-4-plus', 'glm-4', 'glm-4-air', 'glm-4-flash', 'glm-4-long', 'glm-4-flashx'],
  ),
  'qwen': ProviderInfo(
    key: 'qwen',
    name: '通义千问',
    apiUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
    apiType: 'chat_completions',
    models: ['qwen-max', 'qwen-plus', 'qwen-turbo', 'qwen-long'],
  ),
  'kimi': ProviderInfo(
    key: 'kimi',
    name: 'Kimi (Moonshot)',
    apiUrl: 'https://api.moonshot.cn/v1/chat/completions',
    apiType: 'chat_completions',
    models: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'],
  ),
  'mimo': ProviderInfo(
    key: 'mimo',
    name: '小米 MiMo',
    apiUrl: 'https://api.mimo.xiaomi.com/v1/chat/completions',
    apiType: 'chat_completions',
    models: ['mimo-7b-rl'],
  ),
  'gemini': ProviderInfo(
    key: 'gemini',
    name: 'Google Gemini',
    apiUrl: 'https://generativelanguage.googleapis.com/v1beta/models',
    apiType: 'gemini',
    models: ['gemini-2.0-flash', 'gemini-2.5-flash', 'gemini-1.5-pro', 'gemini-1.5-flash'],
    note: 'Gemini 使用独立的 generateContent 接口',
  ),
};

/// 知识库提供商
const Map<String, KnowledgeProviderInfo> kKnowledgeProviders = {
  'bailian': KnowledgeProviderInfo(
    key: 'bailian',
    name: '阿里百炼知识库',
    apiUrl: 'https://bailian.cn-beijing.aliyuncs.com',
    description: '阿里云百炼 RAG 知识库（Retrieve 接口，需 AccessKey ID/Secret + 业务空间 ID + 知识库 ID）',
  ),
  'volcengine': KnowledgeProviderInfo(
    key: 'volcengine',
    name: '火山方舟知识库',
    apiUrl: 'https://api-knowledgebase.mlp.cn-beijing.volces.com/api/knowledge/collection/search_knowledge',
    description: '火山方舟标准知识库（search_knowledge 接口，需 Access Key/Secret Key + Resource ID/集合名）',
  ),
  'notebooklm': KnowledgeProviderInfo(
    key: 'notebooklm',
    name: 'Google NotebookLM',
    apiUrl: 'https://generativelanguage.googleapis.com/v1beta',
    description: 'Google Gemini File Search 知识库',
  ),
};

/// 检查类型枚举
const List<String> kExamTypes = ['CT', 'X-Ray', 'MRI', 'PET-CT', '超声', 'DSA', 'ECG'];

/// 诊断 LLM 使用的 Prompt（无知识库）
const String kDiagnosisPrompt = '''你是一个资深医学影像诊断专家。根据以下信息，给出最有可能的1-3条影像诊断。

检查类型：{exam_type}
关键征象/关键字：{keywords}

注意：ECG为心电图检查，请结合心电波形特征给出心律失常、心肌缺血、心肌梗死等诊断。

请严格按照以下JSON格式返回，不要包含任何其他文字说明：
[
  {
    "disease_name": "疾病名称",
    "confidence": "高/中/低",
    "imaging_findings": "影像学表现/心电图表现（详细描述该疾病在此检查类型下的典型表现）",
    "report_template": "标准报告模板（完整的诊断报告格式）",
    "differential_diagnosis": "鉴别诊断（需鉴别的疾病及鉴别要点）",
    "clinical_manifestation": "临床表现（症状、体征等）",
    "pathophysiology": "病理生理及症状学特征",
    "treatment": "临床治疗方法",
    "references": "参考来源（如有，注明教材/指南名称、作者、章节等）"
  }
]

请返回纯JSON数组，不要有markdown代码块标记：
''';

/// 心电图诊断 Prompt（对齐桌面版 ECG_DIAGNOSIS_PROMPT）
const String kEcgDiagnosisPrompt = '''你是一个资深心电诊断专家。根据以下心电图信息，给出最有可能的1-3条心电图诊断。

检查类型：心电图(ECG)
心电图特征/关键字：{keywords}

请严格按照以下JSON格式返回，不要包含任何其他文字说明：
[
  {
    "disease_name": "疾病名称",
    "confidence": "高/中/低",
    "imaging_findings": "心电图特征（详细描述该疾病的心电图表现：心率、心律、P波、PR间期、QRS波群、ST段、T波、QT间期等）",
    "report_template": "标准心电图报告模板（完整的心电图诊断报告格式）",
    "differential_diagnosis": "鉴别诊断（需鉴别的心律失常或心脏疾病及鉴别要点）",
    "clinical_manifestation": "临床表现（症状、体征等）",
    "pathophysiology": "病理生理及电生理机制",
    "treatment": "临床治疗方法",
    "references": "参考来源（如有，注明教材/指南名称、作者、章节等）"
  }
]

请返回纯JSON数组，不要有markdown代码块标记：
''';

/// 知识库检索提示词模板（对齐桌面版 KB_QUERY_TEMPLATE）
const String kKbQueryTemplate = '''检查类型：{exam_type}
关键征象：{keywords}
疑似疾病：{diseases}

请从知识库中检索以下内容：
1. 上述疾病的影像学表现和诊断标准
2. 鉴别诊断要点
3. 相关病理生理特征
4. 临床治疗方案
5. 标准影像报告模板''';

/// 结合知识库的诊断 Prompt
const String kKbDiagnosisPrompt = '''你是一个资深医学影像诊断专家，请结合知识库中的信息，根据以下检查类型和关键征象给出最有可能的1-3条影像诊断。

检查类型：{exam_type}
关键征象/关键字：{keywords}

注意：ECG为心电图检查，请结合心电波形特征给出心律失常、心肌缺血、心肌梗死等诊断。

请严格按照以下JSON格式返回，不要包含任何其他文字说明：
[
  {
    "disease_name": "疾病名称",
    "confidence": "高/中/低",
    "imaging_findings": "影像学表现/心电图表现",
    "report_template": "标准报告模板",
    "differential_diagnosis": "鉴别诊断",
    "clinical_manifestation": "临床表现",
    "pathophysiology": "病理生理及症状学特征",
    "treatment": "临床治疗方法",
    "references": "参考来源（注明教材/指南名称、作者、章节、页码等引用信息）"
  }
]

请返回纯JSON数组，不要有markdown代码块标记：
''';
