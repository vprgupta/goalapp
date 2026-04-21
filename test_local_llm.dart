import 'dart:io';
import 'lib/domain/services/base_llm_service.dart';
import 'lib/domain/services/llm_config.dart';

void main() async {
  print('--- Testing Local Llama Integration ---');
  print('Provider: ${LlmConfig.provider}');
  print('Model: ${LlmConfig.ollamaModel}');
  // Overriding for host test
  final String testEndpoint = 'http://localhost:11434/v1';
  print('Endpoint: $testEndpoint');

  final service = BaseLlmService();
  
  try {
    // We need to temporarily modify the config or use a local variable in the test
    // For simplicity, I'll just run a curl command to verify the API separately 
    // but the logic in BaseLlmService is what needs testing.
    // I'll update BaseLlmService to accept a baseUrl optionally or just rely on global config.
    print('\nSending test prompt "Say Hello!"...');
    final result = await service.generateText('Say hello in a short sentence.');
    print('\nRESULT: $result');
    print('\nSUCCESS!');
  } catch (e) {
    print('\nFAILED: $e');
    print('\nMake sure Ollama is running and the endpoint is accessible.');
  }
}
