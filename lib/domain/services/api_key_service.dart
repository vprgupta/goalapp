import '../../data/local/hive_service.dart';
import 'secrets.dart';

/// Persists user-supplied API keys in the existing Hive settings box.
/// Falls back to compile-time secrets if no key has been saved yet.
class ApiKeyService {
  // ── Hive keys ───────────────────────────────────────────────────────────────
  static const _kOpenRouter = 'api_key_openrouter';
  static const _kGemini     = 'api_key_gemini';
  static const _kTavily     = 'api_key_tavily';
  static const _kYouTube    = 'api_key_youtube';

  // ── Getters (runtime) ────────────────────────────────────────────────────────
  static String get openRouterKey {
    final saved = HiveService.settingsBox.get(_kOpenRouter) as String?;
    if (saved != null && saved.trim().isNotEmpty) return saved.trim();
    return Secrets.openRouterApiKey; // compile-time fallback
  }

  static String get geminiKey {
    final saved = HiveService.settingsBox.get(_kGemini) as String?;
    if (saved != null && saved.trim().isNotEmpty) return saved.trim();
    return Secrets.geminiApiKey;
  }

  static String get tavilyKey {
    final saved = HiveService.settingsBox.get(_kTavily) as String?;
    if (saved != null && saved.trim().isNotEmpty) return saved.trim();
    return Secrets.tavilyApiKey;
  }

  static String get youtubeKey {
    final saved = HiveService.settingsBox.get(_kYouTube) as String?;
    if (saved != null && saved.trim().isNotEmpty) return saved.trim();
    return Secrets.youtubeApiKey;
  }

  // ── Setters ───────────────────────────────────────────────────────────────────
  static Future<void> saveOpenRouterKey(String key) async =>
      HiveService.settingsBox.put(_kOpenRouter, key.trim());

  static Future<void> saveGeminiKey(String key) async =>
      HiveService.settingsBox.put(_kGemini, key.trim());

  static Future<void> saveTavilyKey(String key) async =>
      HiveService.settingsBox.put(_kTavily, key.trim());

  static Future<void> saveYouTubeKey(String key) async =>
      HiveService.settingsBox.put(_kYouTube, key.trim());

  /// Clears all user-supplied keys, reverting to compile-time defaults.
  static Future<void> clearAll() async {
    await HiveService.settingsBox.delete(_kOpenRouter);
    await HiveService.settingsBox.delete(_kGemini);
    await HiveService.settingsBox.delete(_kTavily);
    await HiveService.settingsBox.delete(_kYouTube);
  }

  /// True if the user has saved at least one custom key.
  static bool get hasAnyCustomKey =>
      [_kOpenRouter, _kGemini, _kTavily, _kYouTube].any(
        (k) {
          final v = HiveService.settingsBox.get(k) as String?;
          return v != null && v.trim().isNotEmpty;
        },
      );
}
