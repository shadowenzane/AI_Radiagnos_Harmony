import 'dart:convert';
import 'dart:io' show SocketException, HttpDate;
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import '../../../core/connectivity_test_result.dart';
import '../../../core/constants.dart';
import '../../kb_config/models/knowledge_config.dart';
import '../models/kb_doc_snapshot.dart';

/// 知识库查询服务（对齐桌面版 ai_helper.py）
///
/// 三种知识库的完整实现：
/// - 阿里百炼: bailian.cn-beijing.aliyuncs.com Retrieve 接口 (AccessKey/Secret ROA签名)
/// - 火山方舟: search_knowledge (AK/SK签名)
/// - Google NotebookLM: Gemini generateContent + fileSearch/google_search
class KnowledgeBaseService {
  static const Duration _timeout = Duration(seconds: 30);

  /// 查询知识库
  ///
  /// [diseaseName] 优先用疾病名查询；为空时用 keywords 直查
  /// [examType] / [keywords] 作为辅助查询上下文
  static Future<KbQueryResult> query({
    required KnowledgeConfig kbConfig,
    required Map<String, String> credentials,
    required String diseaseName,
    String examType = '',
    String keywords = '',
  }) async {
    // 凭证完整性按知识库类型校验
    final credError = _validateCredentials(kbConfig.type, credentials);
    if (credError != null) {
      return KbQueryResult(context: '', docs: [], warning: credError);
    }

    try {
      switch (kbConfig.type) {
        case 'bailian':
          return _queryBailian(kbConfig, credentials, diseaseName, examType, keywords);
        case 'volcengine':
          return _queryVolcengine(kbConfig, credentials, diseaseName, examType, keywords);
        case 'notebooklm':
          return _queryNotebooklm(kbConfig, credentials['api_key'] ?? '', diseaseName, examType, keywords);
        default:
          return const KbQueryResult(context: '', docs: []);
      }
    } on SocketException catch (e) {
      return KbQueryResult(
        context: '',
        docs: [],
        warning: '知识库网络连接失败 (DNS/网络不可达): ${e.message}',
      );
    } catch (e) {
      return KbQueryResult(
        context: '',
        docs: [],
        warning: '知识库查询异常: $e',
      );
    }
  }

  // ============================================================
  // 连通性测试
  // ============================================================

  static Future<ConnectivityTestResult> testConnectivity({
    required KnowledgeConfig kbConfig,
    required Map<String, String> credentials,
  }) async {
    // 凭证完整性按知识库类型校验
    final credError = _validateCredentials(kbConfig.type, credentials);
    if (credError != null) {
      return ConnectivityTestResult(
        success: false,
        statusCode: -1,
        message: credError,
      );
    }

    try {
      switch (kbConfig.type) {
        case 'bailian':
          return _testBailian(kbConfig, credentials);
        case 'volcengine':
          return _testVolcengine(kbConfig, credentials);
        case 'notebooklm':
          return _testNotebooklm(kbConfig, credentials['api_key'] ?? '');
        default:
          return ConnectivityTestResult(
            success: false,
            statusCode: -1,
            message: '不支持的知识库类型: ${kbConfig.type}',
          );
      }
    } on SocketException catch (e) {
      return ConnectivityTestResult(
        success: false,
        statusCode: -1,
        message: '网络连接失败 (DNS 解析失败): ${e.message}\n请检查网络连接。',
      );
    } catch (e) {
      return ConnectivityTestResult(
        success: false,
        statusCode: -1,
        message: '测试异常: $e',
      );
    }
  }

  /// 凭证完整性校验
  ///
  /// - bailian: 需要 access_key + secret_key（+ workspaceId/indexId 在 config 中校验）
  /// - volcengine: 标准知识库仅需 access_key + secret_key
  /// - notebooklm: 需要 api_key
  /// 返回非空字符串表示校验失败的提示，null 表示通过。
  static String? validateCredentials(String type, Map<String, String> creds) {
    switch (type) {
      case 'bailian':
        final accessKey = creds['access_key'] ?? '';
        final secretKey = creds['secret_key'] ?? '';
        if (accessKey.isEmpty || secretKey.isEmpty) {
          return '阿里百炼需要 AccessKey ID 和 AccessKey Secret';
        }
        return null;
      case 'volcengine':
        // 火山方舟标准知识库：仅需 AK/SK，不需要 api_key
        final accessKey = creds['access_key'] ?? '';
        final secretKey = creds['secret_key'] ?? '';
        if (accessKey.isEmpty || secretKey.isEmpty) {
          return '火山方舟标准知识库需要 Access Key 和 Secret Key';
        }
        return null;
      case 'notebooklm':
        if ((creds['api_key'] ?? '').isEmpty) {
          return 'Gemini API Key 为空，请先填写';
        }
        return null;
      default:
        return '不支持的知识库类型: $type';
    }
  }

  static String? _validateCredentials(String type, Map<String, String> creds) =>
      validateCredentials(type, creds);

  // ==================== 阿里百炼知识库 ====================
  //
  // 阿里云百炼 RAG 知识库 Retrieve 接口：
  // - Host: bailian.cn-beijing.aliyuncs.com
  // - 路径: /{WorkspaceId}/index/retrieve
  // - 认证: Aliyun ROA 签名（AccessKey ID/Secret + HMAC-SHA1）
  // - 需要: WorkspaceId(业务空间ID) + IndexId(知识库ID)
  // - 返回: Data.Nodes[] 列表，每个 node 含 Text/Score/Metadata

  static Future<KbQueryResult> _queryBailian(
    KnowledgeConfig kb,
    Map<String, String> creds,
    String diseaseName,
    String examType,
    String keywords,
  ) async {
    final accessKeyId = creds['access_key'] ?? '';
    final accessKeySecret = creds['secret_key'] ?? '';
    final workspaceId = kb.workspaceId ?? '';
    final indexId = kb.indexId ?? '';

    if (workspaceId.isEmpty || indexId.isEmpty) {
      return const KbQueryResult(
        context: '',
        docs: [],
        warning: '阿里百炼配置不完整。需要:\n'
            '1. 业务空间 ID（Workspace ID）\n'
            '2. 知识库 ID（Index ID）\n'
            '3. AccessKey ID + AccessKey Secret（阿里云访问密钥）',
      );
    }

    final searchQuery = diseaseName.isNotEmpty ? diseaseName : keywords;
    if (searchQuery.isEmpty) {
      return const KbQueryResult(context: '', docs: [], warning: '检索词为空');
    }

    try {
      return await _bailianRetrieve(
        accessKeyId, accessKeySecret, workspaceId, indexId, searchQuery,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SignatureDoesNotMatch') || msg.contains('InvalidAccessKeyId')) {
        return KbQueryResult(
          context: '',
          docs: [],
          warning: '阿里百炼签名/认证失败：$msg\n\n'
              '排查建议：\n'
              '1. 确认 AccessKey ID/Secret 正确（阿里云控制台 → RAM → 访问密钥）\n'
              '2. 确认 RAM 用户有百炼权限（AliyunBailianDataFullAccess）\n'
              '3. 确认 RAM 用户已加入对应业务空间',
        );
      }
      return KbQueryResult(context: '', docs: [], warning: '百炼 Retrieve 失败: $msg');
    }
  }

  /// 调用百炼 Retrieve 接口（Aliyun ROA 签名 V1.0）
  static Future<KbQueryResult> _bailianRetrieve(
    String accessKeyId,
    String accessKeySecret,
    String workspaceId,
    String indexId,
    String searchQuery,
  ) async {
    final host = 'bailian.cn-beijing.aliyuncs.com';
    final path = '/$workspaceId/index/retrieve';
    final url = 'https://$host$path';

    final payload = <String, dynamic>{
      'Query': searchQuery,
      'IndexId': indexId,
      'DenseSimilarityTopK': 5,
      'SparseSimilarityTopK': 5,
      'EnableReranking': true,
      'Rerank': [
        {'RerankTopN': 5},
      ],
    };
    final body = jsonEncode(payload);

    final headers = _aliyunRoaSign(
      'POST', path, accessKeyId, accessKeySecret, body, host,
    );

    final resp = await http
        .post(Uri.parse(url), headers: headers, body: utf8.encode(body))
        .timeout(_timeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final bodyPreview = resp.body.length > 400 ? resp.body.substring(0, 400) : resp.body;
      throw Exception('HTTP ${resp.statusCode}: $bodyPreview');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    // 检查 API 错误
    final success = data['Success'];
    if (success == false) {
      final code = data['Code'] ?? 'Unknown';
      final message = data['Message'] ?? '未知错误';
      throw Exception('$code: $message');
    }

    final nodes = (data['Data']?['Nodes'] as List?) ?? [];
    final docSnapshots = <KbDocSnapshot>[];
    final contextParts = <String>[];

    for (final node in nodes) {
      if (node is! Map) continue;
      final text = (node['Text'] ?? '').toString();
      if (text.isEmpty) continue;
      contextParts.add(text);

      // 解析 Metadata（可能是字符串形式的 JSON）
      Map<String, dynamic> metadata = {};
      final rawMeta = node['Metadata'];
      if (rawMeta is String) {
        try {
          metadata = jsonDecode(rawMeta) as Map<String, dynamic>;
        } catch (_) {
          metadata = {};
        }
      } else if (rawMeta is Map) {
        metadata = rawMeta.cast<String, dynamic>();
      }

      final docName = (metadata['doc_name'] ?? metadata['title'] ?? '未知文档').toString();
      final page = (metadata['page'] ?? metadata['page_num'] ?? '').toString();
      final docUrl = (metadata['file_path'] ?? metadata['url'] ?? '').toString();
      final score = node['Score'];
      final snippet = text.length > 300 ? '${text.substring(0, 300)}...' : text;

      // 提取图片（文档搜索类知识库的 image_url 字段）
      final images = <KbDocImage>[];
      final imageUrls = metadata['image_url'];
      if (imageUrls is List) {
        for (final imgLink in imageUrls) {
          if (imgLink is String && imgLink.isNotEmpty) {
            images.add(KbDocImage(url: imgLink, caption: ''));
          }
        }
      }

      docSnapshots.add(KbDocSnapshot(
        docName: docName,
        page: page,
        snippet: snippet,
        fullContent: text,
        images: images,
        url: docUrl,
        source: '阿里百炼知识库',
        score: score is num ? score.toDouble() : 0,
      ));
    }

    final context = contextParts.join('\n');
    if (context.isEmpty) {
      return KbQueryResult(
        context: '',
        docs: [],
        warning: '阿里百炼知识库返回空结果',
      );
    }
    return KbQueryResult(context: context, docs: docSnapshots);
  }

  static Future<ConnectivityTestResult> _testBailian(
    KnowledgeConfig kb,
    Map<String, String> creds,
  ) async {
    final result = await _queryBailian(kb, creds, '', '', '测试');
    return _evalQueryResultForTest(result);
  }

  /// 阿里云 ROA 签名（ACS Signature V1.0，HMAC-SHA1）
  ///
  /// 签名算法：
  /// StringToSign = Method + "\n" + Accept + "\n" + Content-MD5 + "\n"
  ///               + Content-Type + "\n" + Date + "\n"
  ///               + CanonicalizedHeaders + CanonicalizedResource
  /// Signature = Base64(HMAC-SHA1(Secret, StringToSign))
  /// Authorization = "acs " + AccessKeyId + ":" + Signature
  static Map<String, String> _aliyunRoaSign(
    String method, String path, String akId, String akSecret, String body, String host,
  ) {
    final contentType = 'application/json';
    final accept = 'application/json';

    // Content-MD5: MD5(body) 的 Base64 编码
    final bodyBytes = utf8.encode(body);
    final md5Bytes = crypto.md5.convert(bodyBytes).bytes;
    final contentMd5 = base64.encode(md5Bytes);

    // Date: RFC 1123 格式的 GMT 时间
    final now = DateTime.now().toUtc();
    final date = HttpDate.format(now);

    // CanonicalizedHeaders: 以 x-acs- 开头的自定义头，按字典序排列，每个 header 自带 \n 后缀
    // 百炼 Retrieve 不需要额外自定义头，留空（空时不贡献 \n，避免 Date 与 Path 间出现空行）
    final canonicalizedHeaders = '';

    // CanonicalizedResource: 请求路径（含 WorkspaceId）
    final canonicalizedResource = path;

    // 关键：不能用 join('\n')，否则空的 canonicalizedHeaders 会在 Date 与 Path 之间
    // 产生多余的空行，导致 StringToSign 与服务器计算不一致（SignatureDoesNotMatch）。
    // 规范：CanonicalizedHeaders 自身每个 header 已含 \n 后缀，空时直接接 CanonicalizedResource
    final stringToSign = '$method\n$accept\n$contentMd5\n$contentType\n$date\n'
        '$canonicalizedHeaders$canonicalizedResource';

    // HMAC-SHA1 签名
    final signingKey = utf8.encode(akSecret);
    final messageBytes = utf8.encode(stringToSign);
    final hmac = crypto.Hmac(crypto.sha1, signingKey);
    final digest = hmac.convert(messageBytes);
    final signature = base64.encode(digest.bytes);

    final authorization = 'acs $akId:$signature';

    return {
      'Accept': accept,
      'Content-Type': contentType,
      'Content-MD5': contentMd5,
      'Date': date,
      'Authorization': authorization,
      'Host': host,
    };
  }

  /// 把一次知识库查询结果转换为连通性测试结果
  ///
  /// - 有文档/上下文 → 成功
  /// - 网络类 warning → 失败
  /// - 配置/签名/API 类 warning → 失败（带具体提示）
  /// - 仅"无匹配内容"类 warning 或无 warning → 成功
  static ConnectivityTestResult _evalQueryResultForTest(KbQueryResult result) {
    if (result.docs.isNotEmpty || result.context.isNotEmpty) {
      return ConnectivityTestResult(
        success: true,
        statusCode: 200,
        message: '连接成功！返回 ${result.docs.length} 条文档',
      );
    }
    if (result.warning != null) {
      final w = result.warning!;
      if (w.contains('网络') || w.contains('DNS')) {
        return ConnectivityTestResult(success: false, statusCode: -1, message: w);
      }
      if (w.contains('配置不完整') || w.contains('签名失败') ||
          w.contains('需要') || w.contains('失败') || w.contains('为空') ||
          w.contains('错误')) {
        return ConnectivityTestResult(success: false, statusCode: -1, message: w);
      }
      // "未找到相关内容"等无匹配提示 → 连接本身正常
      return const ConnectivityTestResult(
        success: true,
        statusCode: 200,
        message: '连接成功！知识库响应正常（测试词无匹配内容）',
      );
    }
    return const ConnectivityTestResult(
      success: true,
      statusCode: 200,
      message: '连接成功！知识库响应正常',
    );
  }

  // ==================== 火山方舟知识库 ====================
  //
  // 对齐桌面版 _query_volcengine_search_kb（标准知识库模式）：
  // - 仅 search_knowledge API (AK/SK + HMAC-SHA256 签名)
  // - 需要 resource_id 或 collection_name 标识知识库
  // - 已移除旗舰版 Responses API 模式

  static Future<KbQueryResult> _queryVolcengine(
    KnowledgeConfig kb,
    Map<String, String> creds,
    String diseaseName,
    String examType,
    String keywords,
  ) async {
    final accessKey = creds['access_key'] ?? '';
    final secretKey = creds['secret_key'] ?? '';
    final collectionName = kb.collectionName ?? '';
    final resourceId = kb.resourceId ?? '';

    final canSearch = accessKey.isNotEmpty &&
        secretKey.isNotEmpty &&
        (resourceId.isNotEmpty || collectionName.isNotEmpty);

    if (!canSearch) {
      return const KbQueryResult(
        context: '',
        docs: [],
        warning: '火山方舟标准知识库配置不完整。需要:\n'
            '1. Access Key + Secret Key（HMAC 签名）\n'
            '2. Resource ID 或 集合名称（标识知识库）',
      );
    }

    final searchQuery = diseaseName.isNotEmpty ? diseaseName : keywords;
    if (searchQuery.isEmpty) {
      return const KbQueryResult(context: '', docs: [], warning: '检索词为空');
    }

    try {
      return await _queryVolcSearchKb(accessKey, secretKey, resourceId, collectionName, searchQuery);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('check sign error') || msg.contains('check sign not match')) {
        return KbQueryResult(
          context: '',
          docs: [],
          warning: '火山方舟签名失败：$msg\n\n'
              '排查建议：\n'
              '1. 确认 Access Key/Secret Key 正确（火山引擎控制台 → IAM → 访问密钥）\n'
              '2. 确认 AK/SK 有 ark 服务权限（建议授予 ArkMaster 或 ArkUser）\n'
              '3. 确认已开通知识库服务并创建知识库',
        );
      }
      return KbQueryResult(context: '', docs: [], warning: 'search_knowledge 失败: $msg');
    }
  }

  /// search_knowledge API (HMAC-SHA256 签名认证)
  static Future<KbQueryResult> _queryVolcSearchKb(
    String accessKey,
    String secretKey,
    String resourceId,
    String collectionName,
    String searchQuery,
  ) async {
    final host = 'api-knowledgebase.mlp.cn-beijing.volces.com';
    final path = '/api/knowledge/collection/search_knowledge';
    final url = 'https://$host$path';

    final payload = <String, dynamic>{
      'query': searchQuery,
      'limit': 5,
      'post_processing': {'get_attachment_link': true},
    };
    if (resourceId.isNotEmpty) payload['resource_id'] = resourceId;
    if (collectionName.isNotEmpty) {
      payload['name'] = collectionName;
      payload['project'] = 'default';
    }

    final body = jsonEncode(payload);
    final headers = _volcHmacSign('POST', path, accessKey, secretKey, body, host);

    final resp = await http
        .post(Uri.parse(url), headers: headers, body: utf8.encode(body))
        .timeout(_timeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final bodyPreview = resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body;
      throw Exception('HTTP ${resp.statusCode}: $bodyPreview');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    // 检查 API 错误
    final errCode = data['ResponseMetadata']?['Error']?['Code'];
    if (errCode != null) {
      throw Exception('${data['ResponseMetadata']!['Error']}');
    }

    final resultList = (data['data']?['result_list'] as List?) ??
        (data['result_list'] as List?) ??
        (data['chunks'] as List?) ??
        (data['documents'] as List?) ?? [];

    final docSnapshots = <KbDocSnapshot>[];
    final contextParts = <String>[];

    for (final c in resultList) {
      if (c is! Map) continue;
      final content = (c['content'] ?? c['text'] ?? c['chunk_content'] ?? '').toString();
      if (content.isEmpty) continue;
      contextParts.add(content);

      final docInfo = c['doc_info'] ?? {};
      final docName = (docInfo['doc_name'] ?? docInfo['title'] ?? c['chunk_title'] ?? c['doc_name'] ?? c['title'] ?? c['filename'] ?? '未知文档').toString();
      final page = (c['chunk_id'] ?? c['page'] ?? c['page_num'] ?? '').toString();
      final docUrl = (c['attachment_link'] ?? c['url'] ?? c['doc_url'] ?? '').toString();

      // 提取原书图片（chunk_attachment 中的 image 类型，对齐桌面版）
      final images = <KbDocImage>[];
      final chunkAttach = c['chunk_attachment'];
      if (chunkAttach is List) {
        for (final att in chunkAttach) {
          if (att is Map && att['type'] == 'image') {
            final imgLink = (att['link'] ?? '').toString();
            if (imgLink.isNotEmpty) {
              images.add(KbDocImage(
                url: imgLink,
                caption: (att['caption'] ?? '').toString(),
              ));
            }
          }
        }
      }

      // 完整内容（不截断）+ 截断摘要（对齐桌面版 full_content + snippet）
      final snippet = content.length > 300 ? '${content.substring(0, 300)}...' : content;

      docSnapshots.add(KbDocSnapshot(
        docName: docName,
        page: page,
        snippet: snippet,
        fullContent: content,
        images: images,
        url: docUrl,
        source: '火山方舟知识库',
      ));
    }

    final context = contextParts.join('\n');
    if (context.isEmpty) {
      return KbQueryResult(
        context: '',
        docs: [],
        warning: '火山方舟知识库返回空结果',
      );
    }
    return KbQueryResult(context: context, docs: docSnapshots);
  }

  static Future<ConnectivityTestResult> _testVolcengine(
    KnowledgeConfig kb,
    Map<String, String> creds,
  ) async {
    final result = await _queryVolcengine(kb, creds, '', '', '测试');
    return _evalQueryResultForTest(result);
  }

  /// 火山引擎 HMAC-SHA256 签名（对齐桌面版 _volc_hmac_sign）
  static Map<String, String> _volcHmacSign(
    String method, String path, String ak, String sk, String body, String host,
  ) {
    final now = DateTime.now().toUtc();
    final xDate = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        'T'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}Z';
    final shortDate = xDate.substring(0, 8);

    final bodyHash = crypto.sha256.convert(utf8.encode(body)).toString();

    final signedHeadersMap = {
      'content-type': 'application/json',
      'host': host,
      'x-content-sha256': bodyHash,
      'x-date': xDate,
    };

    final sortedKeys = signedHeadersMap.keys.toList()..sort();
    final signedStr = sortedKeys.map((k) => '$k:${signedHeadersMap[k]}\n').join();
    final signedHeaders = sortedKeys.join(';');

    final canonicalRequest = [method, path, '', signedStr, signedHeaders, bodyHash].join('\n');
    final credentialScope = '$shortDate/cn-beijing/air/request';
    final hashedCanonicalRequest = crypto.sha256.convert(utf8.encode(canonicalRequest)).toString();
    final stringToSign = ['HMAC-SHA256', xDate, credentialScope, hashedCanonicalRequest].join('\n');

    // 派生签名密钥: SK → date → region → service → 'request'
    final kDate = crypto.Hmac(crypto.sha256, utf8.encode(sk)).convert(utf8.encode(shortDate)).bytes;
    final kRegion = crypto.Hmac(crypto.sha256, kDate).convert(utf8.encode('cn-beijing')).bytes;
    final kService = crypto.Hmac(crypto.sha256, kRegion).convert(utf8.encode('air')).bytes;
    final kSigning = crypto.Hmac(crypto.sha256, kService).convert(utf8.encode('request')).bytes;
    final signature = crypto.Hmac(crypto.sha256, kSigning).convert(utf8.encode(stringToSign)).toString();

    final authorization = 'HMAC-SHA256 Credential=$ak/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    return {
      'Content-Type': 'application/json',
      'Host': host,
      'X-Content-Sha256': bodyHash,
      'X-Date': xDate,
      'Authorization': authorization,
    };
  }

  // ==================== Google NotebookLM ====================
  //
  // 对齐桌面版 _query_notebooklm_kb:
  // - 认证: x-goog-api-key 请求头（不是 query param）
  // - 模型: gemini-2.5-flash
  // - 有 fileSearchStore: fileSearch 工具
  // - 无 fileSearchStore: google_search 兜底

  static Future<KbQueryResult> _queryNotebooklm(
    KnowledgeConfig kb,
    String apiKey,
    String diseaseName,
    String examType,
    String keywords,
  ) async {
    final base = kKnowledgeProviders['notebooklm']!.apiUrl;
    final fileSearchStore = kb.fileSearchStore ?? '';
    final searchQuery = diseaseName.isNotEmpty ? diseaseName : keywords;
    if (searchQuery.isEmpty) {
      return const KbQueryResult(context: '', docs: [], warning: '检索词为空');
    }

    final queryText = '作为医学影像诊断专家，请根据知识库检索以下问题：\n$searchQuery';
    final model = 'gemini-2.5-flash';
    final endpoint = '$base/models/$model:generateContent';

    final payload = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': queryText}]
        }
      ],
      'generationConfig': {'temperature': 0.2},
    };

    if (fileSearchStore.isNotEmpty) {
      var storeName = fileSearchStore;
      if (!storeName.startsWith('fileSearchStores/')) {
        storeName = 'fileSearchStores/$fileSearchStore';
      }
      payload['tools'] = [
        {'fileSearch': {'fileSearchStores': [storeName]}}
      ];
    } else {
      payload['tools'] = [{'google_search': {}}];
    }

    final headers = {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    };

    final resp = await http
        .post(Uri.parse(endpoint), headers: headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 60));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final bodyPreview = resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body;
      return KbQueryResult(context: '', docs: [], warning: 'NotebookLM 查询失败 (HTTP ${resp.statusCode}): $bodyPreview');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = (data['candidates'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final contextParts = <String>[];
    final docs = <KbDocSnapshot>[];

    for (final candidate in candidates) {
      final content = candidate['content'] as Map?;
      if (content != null) {
        for (final p in (content['parts'] as List?) ?? []) {
          if (p is Map && p['text'] != null) {
            contextParts.add(p['text'].toString());
          }
        }
      }

      // 提取 grounding metadata
      final grounding = candidate['groundingMetadata'] as Map?;
      if (grounding != null) {
        for (final chunk in (grounding['groundingChunks'] as List?) ?? []) {
          if (chunk is! Map) continue;
          final web = chunk['web'] as Map?;
          if (web != null) {
            docs.add(KbDocSnapshot(
              docName: (web['title'] ?? web['uri'] ?? 'Web引用').toString(),
              snippet: '',
              url: (web['uri'] ?? '').toString(),
              source: 'Google NotebookLM',
            ));
          }
          final fileRef = chunk['retrievedContext'] as Map? ?? chunk['fileSearch'] as Map?;
          if (fileRef != null) {
            final text = (fileRef['text'] ?? '').toString();
            docs.add(KbDocSnapshot(
              docName: (fileRef['title'] ?? fileRef['displayName'] ?? fileRef['uri'] ?? '文档引用').toString(),
              snippet: text.length > 200 ? '${text.substring(0, 200)}...' : text,
              url: (fileRef['uri'] ?? '').toString(),
              source: 'Google NotebookLM',
            ));
          }
        }
      }
    }

    final context = contextParts.join('\n');
    if (docs.isEmpty && context.isNotEmpty) {
      docs.add(KbDocSnapshot(
        docName: 'Gemini 查询结果',
        snippet: context.length > 200 ? '${context.substring(0, 200)}...' : context,
        source: 'Google NotebookLM',
      ));
    }
    return KbQueryResult(context: context, docs: docs);
  }

  static Future<ConnectivityTestResult> _testNotebooklm(
    KnowledgeConfig kb,
    String apiKey,
  ) async {
    final base = kKnowledgeProviders['notebooklm']!.apiUrl;
    final endpoint = '$base/models/gemini-2.5-flash:generateContent';
    final headers = {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    };
    final payload = {
      'contents': [
        {'role': 'user', 'parts': [{'text': 'Hello'}]}
      ],
      'tools': [{'google_search': {}}],
      'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 5},
    };

    try {
      final resp = await http
          .post(Uri.parse(endpoint), headers: headers, body: jsonEncode(payload))
          .timeout(_timeout);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return const ConnectivityTestResult(
          success: true,
          statusCode: 200,
          message: '连接成功！Gemini API 响应正常',
        );
      }
      final bodyPreview = resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body;
      return ConnectivityTestResult(
        success: false,
        statusCode: resp.statusCode,
        message: 'HTTP ${resp.statusCode}: $bodyPreview',
      );
    } catch (e) {
      return ConnectivityTestResult(
        success: false,
        statusCode: -1,
        message: '网络异常: $e',
      );
    }
  }
}

/// 知识库查询结果
class KbQueryResult {
  final String context;
  final List<KbDocSnapshot> docs;
  final String? warning;
  const KbQueryResult({required this.context, required this.docs, this.warning});
}
