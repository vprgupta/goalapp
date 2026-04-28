import 'secrets.dart';

enum LlmProvider { gemini, ollama, openRouter }

class LlmConfig {
  static const LlmProvider provider = LlmProvider.openRouter;

  // ── OpenRouter Config ────────────────────────────────────────────────────
  static String get openRouterApiKey => Secrets.openRouterApiKey;
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String openRouterModel = 'google/gemini-2.0-flash-001';

  // ── Tavily Web Search (Resource Finder Agent) ────────────────────────────
  // Get a free key at: https://tavily.com  (1000 searches/month free)
  // Leave empty → agent falls back to LLM-only resource generation
  static String get tavilyApiKey => Secrets.tavilyApiKey;

  // ── YouTube Data API v3 ──────────────────────────────────────────────────
  // Get key at: https://console.cloud.google.com → Enable "YouTube Data API v3"
  // Free tier: 10,000 units/day (~100 searches). Leave empty to skip.
  static String get youtubeApiKey => Secrets.youtubeApiKey;

  // ── Gemini Config (legacy) ───────────────────────────────────────────────
  static String get geminiApiKey => Secrets.geminiApiKey;
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String geminiModel = 'gemini-flash-latest';

  // ── Ollama Config (local) ────────────────────────────────────────────────
  static const String ollamaBaseUrl = 'http://10.22.31.214:11434';
  static const String ollamaModel = 'qwen2.5-coder:7b-instruct-q4_K_M';
}
