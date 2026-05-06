import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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
    if (LlmConfig.provider == LlmProvider.openRouter) {
      bool openRouterFailed = false;
      Exception? orException;
      bool yieldedData = false;
      
      try {
        await for (final chunk in _generateOpenRouterStream(prompt)) {
          yield chunk;
          yieldedData = true;
        }
        if (!yieldedData) {
          throw Exception('OpenRouter returned an empty response.');
        }
      } catch (e) {
        orException = e is Exception ? e : Exception(e.toString());
        openRouterFailed = true;
      }
      
      if (openRouterFailed) {
        // Cross-Provider Fallback! OpenRouter free tier exhausted. Switch to Gemini natively.
        if (LlmConfig.geminiApiKey.isNotEmpty) {
          try {
            bool geminiYielded = false;
            await for (final chunk in _generateGeminiStream(prompt)) {
              yield chunk;
              geminiYielded = true;
            }
            if (!geminiYielded) {
              throw Exception('Gemini fallback returned an empty response.');
            }
          } catch (e2) {
            throw Exception('All AI Providers exhausted.\nOpenRouter: $orException\nGemini: $e2');
          }
        } else {
          throw orException!;
        }
      }
    } else if (LlmConfig.provider == LlmProvider.gemini) {
      bool yieldedData = false;
      await for (final chunk in _generateGeminiStream(prompt)) {
        yield chunk;
        yieldedData = true;
      }
      if (!yieldedData) {
        throw Exception('Gemini returned an empty response. Check if API Key is valid or if safety filters blocked it.');
      }
    } else if (LlmConfig.provider == LlmProvider.ollama) {
      yield* _generateOllamaStream(prompt);
    }
  }

  // ── OpenRouter (OpenAI-compatible SSE) ────────────────────────────────────
  Stream<String> _generateOpenRouterStream(String prompt) async* {
    final url = Uri.parse('${LlmConfig.openRouterBaseUrl}/chat/completions');
    Exception? lastException;

    for (final model in LlmConfig.openRouterModels) {
      final client = http.Client();
      try {
        final request = http.Request('POST', url);
        request.headers['Content-Type'] = 'application/json';
        request.headers['Authorization'] = 'Bearer ${LlmConfig.openRouterApiKey}';
        // Recommended OpenRouter headers
        request.headers['HTTP-Referer'] = 'https://goalapp.dev';
        request.headers['X-Title'] = 'GoalApp';
        request.body = jsonEncode({
          'model': model,
          'stream': true,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        });

        final response =
            await client.send(request).timeout(const Duration(seconds: 60));

        if (response.statusCode != 200) {
          final body = await response.stream.bytesToString();
          throw Exception('OpenRouter Error ${response.statusCode} (Model: $model): $body');
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
        return; // Success, exit generator
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        client.close();
        // Continue to the next fallback model in the list
      }
    }
    
    // If all models failed, throw the last exception
    if (lastException != null) throw lastException;
  }

  // ── Gemini (Legacy/Fallback) ──────────────────────────────────────────────
  Stream<String> _generateGeminiStream(String prompt) async* {
    final url = Uri.parse(
        '${LlmConfig.geminiBaseUrl}/models/${LlmConfig.geminiModel}:streamGenerateContent?key=${LlmConfig.geminiApiKey}&alt=sse');

    final client = http.Client();
    try {
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

      final response = await client.send(request).timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('Gemini Stream Error ${response.statusCode}: $body');
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final payload = line.substring(6).trim();
        if (payload.isEmpty) continue;
        
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map<String, dynamic>?;
            if (content != null) {
              final parts = content['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                final text = parts[0]['text'] as String?;
                if (text != null && text.isNotEmpty) yield text;
              }
            }
          }
        } catch (e) {
          debugPrint('[Gemini Stream Parse Error]: $e\\nPayload: $payload');
        }
      }
    } finally {
      client.close();
    }
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
