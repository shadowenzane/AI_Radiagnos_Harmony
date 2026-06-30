import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import '../../../core/connectivity_test_result.dart';
import '../../../core/constants.dart';
import '../../../core/errors.dart';
import '../../ai_config/models/provider_config.dart';

/// 单个 LLM 调用服务
///
/// 兼容三种 API 协议：
/// - `chat_completions`：OpenAI 兼容（DeepSeek/OpenAI/智谱/通义/Kimi/MiMo）
/// - `responses`：豆包 Responses API
/// - `gemini`：Google Gemini generateContent
class LlmService {
  static const Duration _defaultTimeout = Duration(seconds: 90);

  /// 调用单个 LLM，返回原始文本响应
  ///
  /// [providerConfig] 含 provider / model / customApiUrl
  /// [apiKey] 从 SecureStorage 取出后传入
  /// [messages] OpenAI 风格消息列表
  static Future<String> call({
    required ProviderConfig providerConfig,
    required String apiKey,
    required List<Map<String, dynamic>> messages,
    Duration timeout = _defaultTimeout,
  }) async {
    if (apiKey.isEmpty) {
      throw const ConfigError('未配置 API Key，请在 AI 配置中设置');
    }

    final String apiUrl;
    final String apiType;
    if (providerConfig.customApiUrl != null &&
        providerConfig.customApiUrl!.isNotEmpty) {
      apiUrl = providerConfig.customApiUrl!;
      apiType = 'chat_completions';
    } else {
      final info = kProviders[providerConfig.provider];
      if (info == null) {
        throw ProviderNotSupportedError(providerConfig.provider);
      }
      apiUrl = info.apiUrl;
      apiType = info.apiType;
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    http.Response resp;
    try {
      if (apiType == 'gemini') {
        // Gemini 使用 generateContent 接口 + key 作为 query 参数
        final model = providerConfig.model;
        final url = '$apiUrl/$model:generateContent?key=$apiKey';
        final body = _buildGeminiPayload(messages);
        resp = await http
            .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
            .timeout(timeout);
      } else {
        headers['Authorization'] = 'Bearer $apiKey';
        final body = apiType == 'responses'
            ? _buildResponsesPayload(messages, providerConfig.model)
            : _buildChatCompletionsPayload(messages, providerConfig.model);
        resp = await http
            .post(Uri.parse(apiUrl), headers: headers, body: jsonEncode(body))
            .timeout(timeout);
      }
    } on SocketException catch (e) {
      // DNS 解析失败 / 网络不可达
      final msg = e.message.toLowerCase();
      if (msg.contains('failed host lookup') ||
          msg.contains('no address associated') ||
          msg.contains('nodata') ||
          e.osError?.errorCode == 7) {
        throw NetworkError(
          '无法连接到服务器（DNS 解析失败）。请检查：\n'
          '1. 网络是否正常\n'
          '2. App 是否有网络权限\n'
          '3. 目标域名是否可达: $apiUrl\n'
          '原始错误: ${e.message}',
        );
      }
      throw NetworkError('网络连接失败: ${e.message}');
    } catch (e) {
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('HandshakeException')) {
        throw NetworkError('请求超时或连接被拒绝: $e');
      }
      rethrow;
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw NetworkError(
        'LLM 请求失败: ${resp.statusCode} ${resp.body.substring(0, resp.body.length.clamp(0, 200))}',
        statusCode: resp.statusCode,
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return _extractText(data, apiType);
  }

  /// 测试 LLM 连通性
  ///
  /// 发送一个最简短请求，验证 API Key + URL + 模型名是否有效。
  /// 返回 [ConnectivityTestResult]，包含 success / statusCode / message。
  static Future<ConnectivityTestResult> testConnectivity({
    required ProviderConfig providerConfig,
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      return const ConnectivityTestResult(
        success: false,
        statusCode: -1,
        message: 'API Key 为空，请先填写',
      );
    }

    final String apiUrl;
    final String apiType;
    if (providerConfig.customApiUrl != null &&
        providerConfig.customApiUrl!.isNotEmpty) {
      apiUrl = providerConfig.customApiUrl!;
      apiType = 'chat_completions';
    } else {
      final info = kProviders[providerConfig.provider];
      if (info == null) {
        return ConnectivityTestResult(
          success: false,
          statusCode: -1,
          message: '不支持的 AI 提供商: ${providerConfig.provider}',
        );
      }
      apiUrl = info.apiUrl;
      apiType = info.apiType;
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // 对齐桌面版 test_llm_connection：用正常测试请求，不强制压低 max_tokens
    // （DeepSeek 等模型在 max_tokens 过小时会返回 400 insufficient_token，导致误判连接不通）
    final testMessages = [
      {'role': 'user', 'content': '请回复"连接成功"四个字'},
    ];

    http.Response resp;
    try {
      if (apiType == 'gemini') {
        final model = providerConfig.model;
        final url = '$apiUrl/$model:generateContent?key=$apiKey';
        final body = _buildGeminiPayload(testMessages);
        body['generationConfig'] = {
          'temperature': 0.3,
          'maxOutputTokens': 100,
        };
        resp = await http
            .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 30));
      } else {
        headers['Authorization'] = 'Bearer $apiKey';
        final body = apiType == 'responses'
            ? _buildResponsesPayload(testMessages, providerConfig.model)
            : _buildChatCompletionsPayload(testMessages, providerConfig.model);
        // 测试请求给一个合理的 max_tokens，避免过小触发 400
        if (body['max_tokens'] != null) body['max_tokens'] = 100;
        resp = await http
            .post(Uri.parse(apiUrl), headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 30));
      }
    } on SocketException catch (e) {
      return ConnectivityTestResult(
        success: false,
        statusCode: -1,
        message: '网络连接失败 (DNS 解析失败): ${e.message}\n'
            '请检查网络连接和 App 网络权限。',
      );
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return const ConnectivityTestResult(
          success: false,
          statusCode: -1,
          message: '请求超时（30 秒内未收到响应）',
        );
      }
      return ConnectivityTestResult(
        success: false,
        statusCode: -1,
        message: '网络异常: $e',
      );
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return ConnectivityTestResult(
        success: true,
        statusCode: resp.statusCode,
        message: '连接成功！API Key 和模型配置有效',
      );
    }

    final bodyPreview = resp.body.length > 400
        ? '${resp.body.substring(0, 400)}...'
        : resp.body;
    return ConnectivityTestResult(
      success: false,
      statusCode: resp.statusCode,
      message: 'HTTP ${resp.statusCode}: $bodyPreview',
    );
  }

  // ---------- Payload 构造 ----------

  static Map<String, dynamic> _buildChatCompletionsPayload(
    List<Map<String, dynamic>> messages,
    String model,
  ) {
    return {
      'model': model,
      'messages': messages,
      'temperature': 0.3,
      'max_tokens': 4000,
    };
  }

  static Map<String, dynamic> _buildResponsesPayload(
    List<Map<String, dynamic>> messages,
    String model,
  ) {
    // 豆包 Responses API：system 走 instructions，其余走 input
    final inputItems = <Map<String, dynamic>>[];
    String instructions = '';
    for (final msg in messages) {
      if (msg['role'] == 'system') {
        instructions = msg['content'] as String;
        continue;
      }
      inputItems.add({
        'role': msg['role'],
        'content': [
          {'type': 'input_text', 'text': msg['content']},
        ],
      });
    }
    final payload = <String, dynamic>{
      'model': model,
      'input': inputItems,
    };
    if (instructions.isNotEmpty) {
      payload['instructions'] = instructions;
    }
    // 对齐桌面版：推理模型降低推理强度，加速响应
    payload['reasoning'] = {'effort': 'low'};
    return payload;
  }

  static Map<String, dynamic> _buildGeminiPayload(
    List<Map<String, dynamic>> messages,
  ) {
    // Gemini: contents 数组；system 提示用 systemInstruction
    final contents = <Map<String, dynamic>>[];
    String? systemText;
    for (final msg in messages) {
      if (msg['role'] == 'system') {
        systemText = msg['content'] as String;
        continue;
      }
      final role = msg['role'] == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [
          {'text': msg['content']},
        ],
      });
    }
    final payload = <String, dynamic>{
      'contents': contents,
      'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 4000},
    };
    if (systemText != null) {
      payload['systemInstruction'] = {
        'parts': [
          {'text': systemText},
        ],
      };
    }
    return payload;
  }

  // ---------- 响应解析 ----------

  static String _extractText(Map<String, dynamic> data, String apiType) {
    if (apiType == 'responses') {
      // 豆包 Responses API: {"output": [...{"type":"message","content":[...{"type":"output_text","text":"..."}]}]}
      final outputList = data['output'] as List? ?? [];
      final parts = <String>[];
      for (final item in outputList) {
        if (item is Map && item['type'] == 'message') {
          for (final c in (item['content'] as List? ?? [])) {
            if (c is Map && c['type'] == 'output_text') {
              parts.add(c['text'] as String? ?? '');
            }
          }
        }
      }
      return parts.join('\n').trim();
    }
    if (apiType == 'gemini') {
      final candidates = data['candidates'] as List? ?? [];
      final parts = <String>[];
      for (final cand in candidates) {
        if (cand is Map) {
          final content = cand['content'] as Map?;
          if (content != null) {
            for (final p in (content['parts'] as List? ?? [])) {
              if (p is Map && p['text'] != null) {
                parts.add(p['text'] as String);
              }
            }
          }
        }
      }
      return parts.join('\n').trim();
    }
    // OpenAI 兼容
    final choices = data['choices'] as List? ?? [];
    if (choices.isEmpty) {
      throw const ParseError('LLM 返回 choices 为空');
    }
    final message = (choices[0] as Map)['message'] as Map? ?? {};
    return (message['content'] as String? ?? '').trim();
  }

  /// 解析 LLM 返回的 JSON 数组（清理 markdown 代码块标记）
  static List<Map<String, dynamic>> parseJsonArray(String content) {
    var c = content.trim();
    // 去除 ``` 代码块
    if (c.startsWith('```')) {
      final lines = c.split('\n');
      // 去掉首行（``` 或 ```json）
      lines.removeAt(0);
      c = lines.join('\n');
      if (c.endsWith('```')) {
        c = c.substring(0, c.length - 3).trim();
      }
    }
    final decoded = jsonDecode(c);
    if (decoded is Map) {
      return [decoded.cast<String, dynamic>()];
    }
    if (decoded is List) {
      return decoded
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    }
    throw const ParseError('LLM 返回格式不是 JSON 数组或对象');
  }
}
