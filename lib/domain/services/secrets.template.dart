// ─────────────────────────────────────────────────────────────────────────────
// SECRETS TEMPLATE — safe to commit, contains no real keys.
// To use: copy this file to secrets.dart and fill in your API keys.
//
//   cp lib/domain/services/secrets.template.dart \
//      lib/domain/services/secrets.dart
//
// ─────────────────────────────────────────────────────────────────────────────

class Secrets {
  /// OpenRouter API key — https://openrouter.ai/keys
  static const String openRouterApiKey = 'YOUR_OPENROUTER_API_KEY_HERE';

  /// Gemini API key (legacy fallback) — https://aistudio.google.com/apikey
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';

  /// Tavily search key (optional) — https://tavily.com
  /// Leave empty to use LLM-only resource generation.
  static const String tavilyApiKey = '';
}
