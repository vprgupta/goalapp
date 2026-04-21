enum LlmProvider { gemini, ollama }

class LlmConfig {
  static const LlmProvider provider = LlmProvider.gemini;

  // Gemini Config
  static const String geminiApiKey = 'AIzaSyAeGliCMt0y4mNhAIBnU0bv7qmnI_TwaG4';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String geminiModel = 'gemini-flash-latest';

  // Ollama Config (Local Llama)
  // Detected Local IP: 10.22.31.214
  // Ensure OLLAMA_HOST is set to 0.0.0.0 on your machine.
  static const String ollamaBaseUrl = 'http://10.22.31.214:11434';
  static const String ollamaModel = 'qwen2.5-coder:7b-instruct-q4_K_M';
}
