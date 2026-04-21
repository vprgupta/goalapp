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
      case LlmProvider.gemini:
        yield* _generateGeminiStream(prompt);
      case LlmProvider.ollama:
        yield* _generateOllamaStream(prompt);
    }
  }

  Stream<String> _generateGeminiStream(String prompt) async* {
    final url = Uri.parse('${LlmConfig.geminiBaseUrl}/models/${LlmConfig.geminiModel}:streamGenerateContent?key=${LlmConfig.geminiApiKey}');
    
    final client = http.Client();
    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'generationConfig': {
        'responseMimeType': 'application/json',
      },
      'contents': [
        {'parts': [{'text': prompt}]}
      ],
    });

    final response = await client.send(request).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Gemini Stream Error ${response.statusCode}: $body');
    }

    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) continue;
      try {
        // Gemini stream wraps chunks in a list of candidates
        final data = jsonDecode(line.replaceFirst(RegExp(r'^\[|,$'), '')); 
        final String? text = data['candidates']?[0]['content']?['parts']?[0]['text'];
        if (text != null) yield text;
      } catch (e) {
        // Skip partial JSON chunks if they happen
      }
    }
    client.close();
  }

  Stream<String> _generateOllamaStream(String prompt) async* {
    final url = Uri.parse('${LlmConfig.ollamaBaseUrl}/api/chat');
    
    print('--- OLLAMA REQUEST START ---');
    print('URL: $url');
    print('Model: ${LlmConfig.ollamaModel}');

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

    final response = await client.send(request).timeout(const Duration(seconds: 300));

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Ollama API Error ${response.statusCode}: $body');
    }

    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      try {
        final Map<String, dynamic> data = jsonDecode(line);
        // Native Ollama matches data['message']['content']
        final String? text = data['message']?['content'];
        
        if (text != null) {
          yield text;
        }
        
        if (data['done'] == true) {
          print('--- OLLAMA REQUEST COMPLETE ---');
          break;
        }
      } catch (e) {
        print('Ollama Parse Error: $e | Line: $line');
      }
    }
    client.close();
  }

  Future<String> _generateGemini(String prompt) async {
    // Legacy support via stream
    final buffer = StringBuffer();
    await for (final chunk in _generateGeminiStream(prompt)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  Future<String> _generateOllama(String prompt) async {
    // Legacy support via stream
    final buffer = StringBuffer();
    await for (final chunk in _generateOllamaStream(prompt)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }
}
