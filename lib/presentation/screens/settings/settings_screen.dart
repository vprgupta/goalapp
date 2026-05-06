import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import '../../../data/local/hive_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/services/api_key_service.dart';
import '../../../domain/services/llm_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _openRouterCtrl = TextEditingController();
  final _geminiCtrl     = TextEditingController();
  final _tavilyCtrl     = TextEditingController();
  final _youtubeCtrl    = TextEditingController();

  final Map<String, bool> _visible = {
    'openRouter': false,
    'gemini'    : false,
    'tavily'    : false,
    'youtube'   : false,
  };

  bool _saving = false;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill only with explicitly user-saved keys (not compile-time fallbacks)
    _openRouterCtrl.text = _savedKey('api_key_openrouter');
    _geminiCtrl.text     = _savedKey('api_key_gemini');
    _tavilyCtrl.text     = _savedKey('api_key_tavily');
    _youtubeCtrl.text    = _savedKey('api_key_youtube');
  }

  /// Returns the raw value stored in Hive, or empty string if nothing was saved.
  String _savedKey(String hiveKey) {
    try {
      final val = HiveService.settingsBox.get(hiveKey) as String?;
      return (val != null && val.trim().isNotEmpty) ? val.trim() : '';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _openRouterCtrl.dispose();
    _geminiCtrl.dispose();
    _tavilyCtrl.dispose();
    _youtubeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    await ApiKeyService.saveOpenRouterKey(_openRouterCtrl.text);
    await ApiKeyService.saveGeminiKey(_geminiCtrl.text);
    await ApiKeyService.saveTavilyKey(_tavilyCtrl.text);
    await ApiKeyService.saveYouTubeKey(_youtubeCtrl.text);
    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 18),
              const SizedBox(width: 10),
              Text('API keys saved!',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
            ],
          ),
          backgroundColor: AppColors.backgroundElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final key = _openRouterCtrl.text.trim();
    if (key.isEmpty) {
      setState(() {
        _testResult = 'Enter an OpenRouter API key first.';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${LlmConfig.openRouterBaseUrl}/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
          'HTTP-Referer': 'https://goalapp.dev',
          'X-Title': 'GoalApp',
        },
        body: jsonEncode({
          'model': LlmConfig.openRouterModels.first,
          'max_tokens': 5,
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _testResult = '✓ Connection successful! Key is valid.';
          _testSuccess = true;
        });
      } else {
        final body = jsonDecode(response.body);
        final msg = body['error']?['message'] ?? 'HTTP ${response.statusCode}';
        setState(() {
          _testResult = '✗ Error: $msg';
          _testSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _testResult = '✗ Could not connect: $e';
        _testSuccess = false;
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All Keys?', style: AppTextStyles.headlineMedium),
        content: Text(
          'This will revert to the default built-in keys.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiKeyService.clearAll();
      _openRouterCtrl.clear();
      _geminiCtrl.clear();
      _tavilyCtrl.clear();
      _youtubeCtrl.clear();
      setState(() {
        _testResult = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Keys cleared — using built-in defaults.',
                style: AppTextStyles.bodyMedium),
            backgroundColor: AppColors.backgroundElevated,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [

          SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── App Bar ────────────────────────────────────────────────
                SliverAppBar(
                  backgroundColor: AppColors.backgroundDark,
                  surfaceTintColor: Colors.transparent,
                  pinned: true,
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderCard),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70, size: 16),
                    ),
                  ),
                  title: Text('Settings', style: AppTextStyles.headlineMedium),
                  actions: [
                    IconButton(
                      onPressed: _clearAll,
                      tooltip: 'Clear all keys',
                      icon: const Icon(Icons.delete_sweep_rounded,
                          color: AppColors.textMuted),
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Hero header ────────────────────────────────────
                        _buildHeader()
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),
                        const SizedBox(height: 32),

                        // ── Primary: OpenRouter ────────────────────────────
                        _buildSectionLabel('PRIMARY AI MODEL', AppColors.accentAmber),
                        const SizedBox(height: 12),
                        _buildKeyCard(
                          index: 0,
                          icon: Icons.hub_rounded,
                          title: 'OpenRouter API Key',
                          subtitle: 'Powers roadmap generation · openrouter.ai',
                          controller: _openRouterCtrl,
                          visibilityKey: 'openRouter',
                          hintText: 'sk-or-v1-...',
                          accentColor: AppColors.accentAmber,
                          getUrl: 'https://openrouter.ai/keys',
                        ),
                        const SizedBox(height: 16),

                        // Test connection button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _testing ? null : _testConnection,
                            icon: _testing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accentAmber,
                                    ),
                                  )
                                : const Icon(Icons.wifi_tethering_rounded, size: 18),
                            label: Text(_testing ? 'Testing...' : 'Test Connection'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accentAmber,
                              side: const BorderSide(color: AppColors.accentAmber, width: 1),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        if (_testResult != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _testSuccess
                                  ? AppColors.accentGreen.withOpacity(0.08)
                                  : AppColors.accentRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _testSuccess
                                    ? AppColors.accentGreen.withOpacity(0.3)
                                    : AppColors.accentRed.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _testResult!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: _testSuccess
                                    ? AppColors.accentGreen
                                    : AppColors.accentRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ).animate().fadeIn(duration: 300.ms),
                        ],

                        const SizedBox(height: 28),
                        // ── Secondary keys ─────────────────────────────────
                        _buildSectionLabel('SECONDARY SERVICES', AppColors.accentTeal),
                        const SizedBox(height: 12),
                        _buildKeyCard(
                          index: 1,
                          icon: Icons.diamond_rounded,
                          title: 'Gemini API Key',
                          subtitle: 'Fallback AI model · aistudio.google.com',
                          controller: _geminiCtrl,
                          visibilityKey: 'gemini',
                          hintText: 'AIza...',
                          accentColor: AppColors.accentTeal,
                          getUrl: 'https://aistudio.google.com/app/apikey',
                        ),
                        const SizedBox(height: 14),
                        _buildKeyCard(
                          index: 2,
                          icon: Icons.travel_explore_rounded,
                          title: 'Tavily API Key',
                          subtitle:
                              'Web search for roadmap research · tavily.com',
                          controller: _tavilyCtrl,
                          visibilityKey: 'tavily',
                          hintText: 'tvly-...',
                          accentColor: const Color(0xFF60A5FA),
                          getUrl: 'https://app.tavily.com/home',
                        ),
                        const SizedBox(height: 14),
                        _buildKeyCard(
                          index: 3,
                          icon: Icons.smart_display_rounded,
                          title: 'YouTube Data API Key',
                          subtitle:
                              'Verified video resources · console.cloud.google.com',
                          controller: _youtubeCtrl,
                          visibilityKey: 'youtube',
                          hintText: 'AIza...',
                          accentColor: const Color(0xFFFF4444),
                          getUrl:
                              'https://console.cloud.google.com/apis/library/youtube.googleapis.com',
                        ),

                        const SizedBox(height: 36),

                        // ── Save button ────────────────────────────────────
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.accentAmber,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: _saving ? null : _saveAll,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_saving)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.backgroundDark,
                                        ),
                                      )
                                    else
                                      const Icon(Icons.save_rounded,
                                          color: AppColors.backgroundDark, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      _saving ? 'Saving...' : 'Save API Keys',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.backgroundDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        // Info note
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundElevated.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderCard),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lock_rounded,
                                  size: 16, color: AppColors.accentTeal),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Keys are stored locally on your device only. They are never sent to any server other than the API provider.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderCard),
              ),
              child: const Icon(Icons.key_rounded,
                  color: AppColors.accentAmber, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API Keys', style: AppTextStyles.displayMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Your keys, your generation.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.tagStyle.copyWith(
            color: color,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required String visibilityKey,
    required String hintText,
    required Color accentColor,
    required String getUrl,
  }) {
    final isVisible = _visible[visibilityKey] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accentColor.withOpacity(0.2)),
                        ),
                        child: Icon(icon, color: accentColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                            Text(subtitle,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Input field
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderCard),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            obscureText: !isVisible,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: hintText,
                              hintStyle: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textHint),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                            ),
                          ),
                        ),
                        // Show/hide toggle
                        IconButton(
                          onPressed: () =>
                              setState(() => _visible[visibilityKey] = !isVisible),
                          icon: Icon(
                            isVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ),
                        // Paste button
                        IconButton(
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null) {
                              controller.text = data!.text!.trim();
                            }
                          },
                          icon: const Icon(Icons.content_paste_rounded,
                              color: AppColors.textMuted, size: 18),
                          tooltip: 'Paste from clipboard',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // "Get key" link row
                  GestureDetector(
                    onTap: () {
                      // Copy URL to clipboard as a lightweight action
                      Clipboard.setData(ClipboardData(text: getUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('URL copied — open in browser to get key',
                              style: AppTextStyles.bodySmall),
                          backgroundColor: AppColors.backgroundElevated,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            size: 12, color: accentColor.withOpacity(0.7)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Get free key → $getUrl',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: accentColor.withOpacity(0.7),
                              fontSize: 10,
                              decoration: TextDecoration.underline,
                              decorationColor: accentColor.withOpacity(0.4),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 80 * index))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.08, end: 0);
  }
}


