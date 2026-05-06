import 'api_key_service.dart';

enum LlmProvider { gemini, ollama, openRouter }

class LlmConfig {
  static const LlmProvider provider = LlmProvider.openRouter;

  // ── OpenRouter Config ────────────────────────────────────────────────────
  // Key is read at call-time so hot-swapping in the Settings screen takes
  // effect immediately without restarting the app.
  static String get openRouterApiKey => ApiKeyService.openRouterKey;
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const List<String> openRouterModels = [
    'google/gemini-2.0-flash-001',
    'google/gemini-2.0-pro-exp-02-05:free',
    'google/gemini-2.0-flash-lite-preview-02-05:free',
    'meta-llama/llama-3.3-70b-instruct:free',
    'meta-llama/llama-3-8b-instruct:free',
    'mistralai/mistral-7b-instruct:free',
    'mistralai/mistral-nemo:free',
    'cognitivecomputations/dolphin3.0-r1-mistral-24b:free',
    'microsoft/phi-3-mini-128k-instruct:free',
    'nousresearch/hermes-3-llama-3.1-405b:free',
    'qwen/qwen-2.5-72b-instruct:free',
    'huggingfaceh4/zephyr-7b-beta:free',
  ];

  // ── Tavily Web Search ────────────────────────────────────────────────────
  static String get tavilyApiKey => ApiKeyService.tavilyKey;

  // ── YouTube Data API v3 ──────────────────────────────────────────────────
  static String get youtubeApiKey => ApiKeyService.youtubeKey;

  // ── Gemini Config (legacy / fallback) ────────────────────────────────────
  static String get geminiApiKey => ApiKeyService.geminiKey;
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String geminiModel = 'gemini-flash-latest';

  // ── Ollama Config (local) ────────────────────────────────────────────────
  static const String ollamaBaseUrl = 'http://10.22.31.214:11434';
  static const String ollamaModel = 'qwen2.5-coder:7b-instruct-q4_K_M';
}
