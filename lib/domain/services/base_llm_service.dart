import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_config.dart';

class BaseLlmService {
  Future<String> generateText(String prompt) async {
    final buffer = StringBuffer();
    await for (final chunk in generateTextStream(prompt)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  Stream<String> generateTextStream(String prompt) async* {
    switch (LlmConfig.provider) {
      case LlmProvider.openRouter:
        yield* _generateOpenRouterStream(prompt);
      case LlmProvider.gemini:
        yield* _generateGeminiStream(prompt);
      case LlmProvider.ollama:
        yield* _generateOllamaStream(prompt);
    }
  }

  // ── OpenRouter (OpenAI-compatible SSE) ────────────────────────────────────
  Stream<String> _generateOpenRouterStream(String prompt) async* {
    final url = Uri.parse('${LlmConfig.openRouterBaseUrl}/chat/completions');

    final client = http.Client();
    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ${LlmConfig.openRouterApiKey}';
    // Recommended OpenRouter headers
    request.headers['HTTP-Referer'] = 'https://goalapp.dev';
    request.headers['X-Title'] = 'GoalApp';
    request.body = jsonEncode({
      'model': LlmConfig.openRouterModel,
      'stream': true,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
    });

    final response =
        await client.send(request).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      client.close();
      throw Exception('OpenRouter Error ${response.statusCode}: $body');
    }

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      // SSE format: lines are prefixed with "data: "
      if (!line.startsWith('data: ')) continue;
      final payload = line.substring(6).trim();
      if (payload == '[DONE]') break;
      try {
        final Map<String, dynamic> data = jsonDecode(payload);
        final String? text =
            data['choices']?[0]?['delta']?['content'] as String?;
        if (text != null && text.isNotEmpty) yield text;
      } catch (_) {
        // Skip malformed SSE chunks
      }
    }
    client.close();
  }

  // ── Gemini (legacy) ───────────────────────────────────────────────────────
  Stream<String> _generateGeminiStream(String prompt) async* {
    final url = Uri.parse(
        '${LlmConfig.geminiBaseUrl}/models/${LlmConfig.geminiModel}:streamGenerateContent?key=${LlmConfig.geminiApiKey}');

    final client = http.Client();
    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'generationConfig': {
        'responseMimeType': 'application/json',
      },
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
    });

    final response =
        await client.send(request).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      client.close();
      throw Exception('Gemini Stream Error ${response.statusCode}: $body');
    }

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.isEmpty) continue;
      try {
        final data = jsonDecode(line.replaceFirst(RegExp(r'^\[|,$'), ''));
        final String? text =
            data['candidates']?[0]['content']?['parts']?[0]['text'];
        if (text != null) yield text;
      } catch (_) {
        // Skip partial JSON chunks
      }
    }
    client.close();
  }

  // ── Ollama (local) ────────────────────────────────────────────────────────
  Stream<String> _generateOllamaStream(String prompt) async* {
    final url = Uri.parse('${LlmConfig.ollamaBaseUrl}/api/chat');

    final client = http.Client();
    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'model': LlmConfig.ollamaModel,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'stream': true,
      'format': 'json',
    });

    final response =
        await client.send(request).timeout(const Duration(seconds: 300));

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      client.close();
      throw Exception('Ollama API Error ${response.statusCode}: $body');
    }

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      try {
        final Map<String, dynamic> data = jsonDecode(line);
        final String? text = data['message']?['content'];
        if (text != null) yield text;
        if (data['done'] == true) break;
      } catch (e) {
        // Skip parse errors
      }
    }
    client.close();
  }
}
