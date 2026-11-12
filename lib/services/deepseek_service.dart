import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

/// DeepSeek Chat API 客户端（OpenAI 兼容 + SSE 流式）
///
/// 端点: POST {baseUrl}/chat/completions
/// 鉴权: Authorization: Bearer <apiKey>
/// 流式: stream=true，返回 text/event-stream
class DeepSeekService {
  final http.Client _client;

  DeepSeekService({http.Client? client}) : _client = client ?? http.Client();

  /// 发起流式对话。
  ///
  /// [onDelta] 收到增量正文；[onReasoning] 收到思考链增量（可能为空）。
  /// 返回完整的 assistant 消息。
  Future<ChatMessage> streamChat({
    required String apiKey,
    required String baseUrl,
    required String model,
    required List<ChatMessage> history,
    String? systemPrompt,
    void Function(String delta)? onDelta,
    void Function(String reasoningDelta)? onReasoning,
  }) async {
    final messages = <Map<String, dynamic>>[
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      ...history.map((m) => m.toApiJson()),
    ];

    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'model': model,
        'messages': messages,
        'stream': true,
      });

    final streamed = await _client.send(request);

    if (streamed.statusCode != 200) {
      final errBody = await streamed.stream.bytesToString();
      throw ApiException(
        '请求失败 (HTTP ${streamed.statusCode}): $errBody',
        statusCode: streamed.statusCode,
      );
    }

    final contentBuf = StringBuffer();
    final reasoningBuf = StringBuffer();

    await for (final line in streamed.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload == '[DONE]') break;

      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;
        final delta = choices.first['delta'] as Map<String, dynamic>?;
        if (delta == null) continue;

        final rc = delta['reasoning_content'] as String?;
        if (rc != null && rc.isNotEmpty) {
          reasoningBuf.write(rc);
          onReasoning?.call(rc);
        }
        final c = delta['content'] as String?;
        if (c != null && c.isNotEmpty) {
          contentBuf.write(c);
          onDelta?.call(c);
        }
      } catch (_) {
        // 忽略无法解析的心跳/注释行
      }
    }

    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: 'assistant',
      content: contentBuf.toString(),
      reasoningContent:
          reasoningBuf.isEmpty ? null : reasoningBuf.toString(),
      createdAt: DateTime.now(),
      isStreaming: false,
    );
  }

  /// 简单连通性测试（非流式，校验 apiKey/model 是否可用）
  Future<bool> testConnection({
    required String apiKey,
    required String baseUrl,
    required String model,
  }) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions');
    final resp = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'ping'},
        ],
        'max_tokens': 1,
        'stream': false,
      }),
    );
    return resp.statusCode == 200;
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}
