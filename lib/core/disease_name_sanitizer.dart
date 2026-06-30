/// 疾病名清洗工具（对应桌面版 ai_helper.py 的 _sanitize_disease_name，并增强）
///
/// 用于 LLM 返回疾病名后、查询知识库前的清洗，区分两种情况：
/// 1. 疾病名【含中文】（无论是否含字母/特殊字符）→ 去括号内容、去英文字母和特殊字符，
///    只保留中文用于检索。例如："肺癌（adenocarcinoma）" → "肺癌"、"COVID-19肺炎" → "肺炎"
/// 2. 疾病名【纯英文+特殊字符】（无中文）→ 去括号内容，仅去除特殊字符保留英文/数字。
///    例如："COVID-19" → "COVID19"、"Non-Hodgkin's Lymphoma" → "NonHodgkinsLymphoma"
class DiseaseNameSanitizer {
  /// 中文字符范围
  static final RegExp _chineseRe = RegExp(r'[\u4e00-\u9fa5]');

  /// 中英文括号及内容
  static final RegExp _parenRe = RegExp(r'[（(][^）)]*[）)]');

  /// 英文字母、数字、连字符、空格及常见标点（含中文时去除这些，只留中文）
  static final RegExp _nonChineseRe =
      RegExp(r'[a-zA-Z0-9\-\s\u00b7\u2014\u2013\u2018\u2019\u201c\u201d.,;:!?/\\]');

  /// 仅特殊字符（纯英文场景去除这些，保留字母数字）
  static final RegExp _specialCharRe =
      RegExp(r'[\(\)\uff08\uff09\-\s\u00b7\u2014\u2013\u2018\u2019\u201c\u201d.,;:!?/\\]');

  /// 清洗疾病名用于知识库检索
  static String sanitize(String name) {
    if (name.isEmpty) return name;

    // 1. 去除括号及括号内的内容（中英文括号）
    var cleaned = name.replaceAll(_parenRe, '');

    // 2. 根据是否含中文分支处理
    if (_chineseRe.hasMatch(cleaned)) {
      // 含中文：去除英文字母、数字、连字符、空格等，只保留中文
      cleaned = cleaned.replaceAll(_nonChineseRe, '');
    } else {
      // 纯英文+特殊字符：仅去除特殊字符，保留字母数字
      cleaned = cleaned.replaceAll(_specialCharRe, '');
    }

    // 3. 去除多余空格和首尾标点
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '').trim();
    cleaned = cleaned.replaceAll(
        RegExp(r'^[\s\u00b7\u2014\u2013\-]+|[\s\u00b7\u2014\u2013\-]+$'), '');

    // 4. 如果清理后为空，回退到原始名称（去括号后的）
    if (cleaned.isEmpty) {
      final noParen = name.replaceAll(_parenRe, '').trim();
      return noParen.isNotEmpty ? noParen : name;
    }
    return cleaned;
  }

  /// 判断疾病名是否包含英文或特殊字符（需要清洗）
  static bool needsSanitizing(String name) {
    return RegExp(r'[a-zA-Z\(（\-]').hasMatch(name);
  }
}
