import 'api_key_service.dart';

enum LlmProvider { gemini, ollama, openRouter }

class LlmConfig {
  static const LlmProvider provider = LlmProvider.openRouter;

  // ── OpenRouter Config ────────────────────────────────────────────────────
  // Key is read at call-time so hot-swapping in the Settings screen takes
  // effect immediately without restarting the app.
  static String get openRouterApiKey => ApiKeyService.openRouterKey;
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String openRouterModel = 'google/gemini-2.0-flash-001';

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
