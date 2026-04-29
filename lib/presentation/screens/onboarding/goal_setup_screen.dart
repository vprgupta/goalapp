import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/goal_provider.dart';
import '../../../domain/services/youtube_service.dart';
import '../../../domain/services/ai_service.dart';
import '../../../domain/services/pdf_extraction_service.dart';
// Extracted sub-widgets (flutter-building-layouts skill decomposition)
import 'widgets/goal_setup_header.dart';
import 'widgets/source_selector.dart';
import 'widgets/level_picker.dart';
import 'widgets/duration_slider.dart';
import 'widgets/loading_state_view.dart';

class GoalSetupScreen extends ConsumerStatefulWidget {
  const GoalSetupScreen({super.key});

  @override
  ConsumerState<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends ConsumerState<GoalSetupScreen> {
  final _controller = TextEditingController();
  final _urlController = TextEditingController();
  // flutter-building-forms skill: persist GlobalKey in State (never in build())
  final _formKey = GlobalKey<FormState>();
  final _ytService = YouTubeService();
  final _aiService = AiService();
  final _pdfService = PdfExtractionService();

  String _currentLevel = 'beginner';
  String _targetLevel = 'advanced';
  double _days = 14;
  bool _isCreating = false;
  String _sourceType = 'ai';
  bool _isFetching = false;
  List<Map<String, dynamic>>? _fetchedMetadata;

  int _currentTipIndex = 0;
  int _currentStatusIndex = 0;
  Timer? _tipTimer;
  Timer? _statusTimer;

  final List<String> _loadingTips = [
    "Spaced repetition can improve long-term retention by up to 200%.",
    "Short study sessions (25-45 mins) are more effective than marathon cramming.",
    "The Feynman Technique: Teaching a concept accelerates your own mastery.",
    "Consistency is king. 15 minutes daily beats 4 hours once a week.",
    "Active Recall is the #1 science-backed method for durable learning.",
    "Sleep is when your brain actually encodes the day's new memories.",
    "Interleaving: Mixing different topics prevents 'learning plateaus'.",
  ];

  final List<String> _loadingStatuses = [
    "Analyzing goal complexity...",
    "Curating expert content...",
    "Structuring curriculum hierarchy...",
    "Mapping scientific sub-topics...",
    "Refining path for your level...",
    "Optimizing revision schedule...",
    "Finalizing expert roadmap...",
  ];

  final List<String> _suggestions = [
    'Learn Java',
    'Python for Beginners',
    'JavaScript',
    'React',
    'SQL Databases',
    'DSA / LeetCode',
    'Flutter',
    'Machine Learning',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _urlController.dispose();
    _ytService.dispose();
    _tipTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  // ── Timers ────────────────────────────────────────────────────────────────

  void _startLoadingTimers() {
    _tipTimer?.cancel();
    _statusTimer?.cancel();
    setState(() {
      _currentTipIndex = 0;
      _currentStatusIndex = 0;
    });

    _tipTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(
            () => _currentTipIndex = (_currentTipIndex + 1) % _loadingTips.length);
      }
    });

    _statusTimer =
        Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted && _currentStatusIndex < _loadingStatuses.length - 1) {
        setState(() => _currentStatusIndex++);
      }
    });
  }

  void _stopLoadingTimers() {
    _tipTimer?.cancel();
    _statusTimer?.cancel();
    _tipTimer = null;
    _statusTimer = null;
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchPlaylist() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isFetching = true);
    _startLoadingTimers();
    try {
      final metadata = await _ytService.fetchPlaylistMetadata(url);
      setState(() {
        _fetchedMetadata = metadata;
        _isFetching = false;
        _stopLoadingTimers();
      });
    } catch (e) {
      setState(() {
        _isFetching = false;
        _stopLoadingTimers();
      });
    }
  }

  Future<void> _pickAndExtractPdf() async {
    setState(() => _isFetching = true);
    _startLoadingTimers();
    try {
      final text = await _pdfService.pickAndExtractPdfText();
      if (text != null && text.isNotEmpty) {
        final metadata = await _aiService.extractRoadmapFromText(
          extractedText: text,
          days: _days.round(),
        );
        setState(() {
          _fetchedMetadata = metadata;
          _isFetching = false;
          _stopLoadingTimers();
        });
      } else {
        setState(() {
          _isFetching = false;
          _stopLoadingTimers();
        });
      }
    } catch (e) {
      setState(() {
        _isFetching = false;
        _stopLoadingTimers();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to extract PDF: $e')),
        );
      }
    }
  }

  Future<void> _createGoal() async {
    // flutter-building-forms skill: validate before proceeding
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _controller.text.trim();

    if (_sourceType == 'youtube' &&
        (_fetchedMetadata == null || _fetchedMetadata!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fetch the playlist syllabus first')),
      );
      return;
    }

    if (_sourceType == 'pdf' &&
        (_fetchedMetadata == null || _fetchedMetadata!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload and successfully parse a PDF first')),
      );
      return;
    }

    if (_sourceType == 'ai') {
      _startLoadingTimers();
    }

    setState(() => _isCreating = true);
    try {
      await ref.read(goalListProvider.notifier).createGoal(
            name: name,
            level: '$_currentLevel to $_targetLevel',
            totalDays: _days.round(),
            customMetadata: _sourceType != 'ai' ? _fetchedMetadata : null,
          );
      _stopLoadingTimers();
      if (mounted) context.go('/goals');
    } catch (e) {
      setState(() {
        _isCreating = false;
        _stopLoadingTimers();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation Failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isLoading = _isFetching || (_isCreating && _sourceType == 'ai');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0F1A), Color(0xFF111827), Color(0xFF0D1225)],
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: isLoading
                ? LoadingStateView(
                    key: const ValueKey('loading'),
                    currentLevel: _currentLevel,
                    targetLevel: _targetLevel,
                    currentStatus: _loadingStatuses[_currentStatusIndex],
                    currentTip: _loadingTips[_currentTipIndex],
                  )
                : _buildForm(),
          ),
        ),
      ),
    );
  }

  /// The main form — wrapped in LayoutBuilder for responsive centering on wide screens.
  Widget _buildForm() {
    return LayoutBuilder(
      key: const ValueKey('form'),
      builder: (context, constraints) {
        // On wide screens (tablets/desktop): constrain form to 560px and center it.
        final double horizontalPadding = constraints.maxWidth > 600
            ? (constraints.maxWidth - 560) / 2
            : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: 20),
          // flutter-building-forms skill: Form widget binds the GlobalKey
          // so all TextFormField validators run together via _formKey.validate()
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const GoalSetupHeader(),
                const SizedBox(height: 32),
                SourceSelector(
                  selectedSource: _sourceType,
                  onSourceChanged: (type) => setState(() {
                    _sourceType = type;
                    if (type == 'ai') _fetchedMetadata = null;
                  }),
                ),
                const SizedBox(height: 32),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _sourceType == 'youtube'
                      ? _buildYoutubeInput()
                      : _sourceType == 'pdf'
                          ? _buildPdfInput()
                          : _buildGoalInputSection(),
                ),
                const SizedBox(height: 36),
                LevelPicker(
                  currentLevel: _currentLevel,
                  targetLevel: _targetLevel,
                  onCurrentChanged: (v) => setState(() => _currentLevel = v),
                  onTargetChanged: (v) => setState(() => _targetLevel = v),
                ),
                const SizedBox(height: 36),
                DurationSlider(
                  days: _days,
                  onChanged: (v) => setState(() => _days = v),
                ),
                const SizedBox(height: 48),
                _buildCTA(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Input sections ────────────────────────────────────────────────────────

  Widget _buildGoalInputSection() {
    return Column(
      key: const ValueKey('curated'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGoalInput(),
        if (_fetchedMetadata != null) ...[
          const SizedBox(height: 24),
          _buildTopicsPreview(),
        ],
        const SizedBox(height: 24),
        _buildSuggestions(),
      ],
    );
  }

  Widget _buildYoutubeInput() {
    return Column(
      key: const ValueKey('youtube'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Playlist URL', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Paste YouTube playlist link...',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Fetch button
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: _isFetching
                    ? AppColors.textMuted
                    : AppColors.accentAmber,
                child: InkWell(
                  onTap: _isFetching ? null : _fetchPlaylist,
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: _isFetching
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.backgroundDark),
                          )
                        : const Icon(Icons.download_rounded,
                            color: AppColors.backgroundDark),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_fetchedMetadata != null) ...[
          const SizedBox(height: 20),
          _buildTopicsPreview(),
        ],
        const SizedBox(height: 24),
        _buildGoalInput(),
      ],
    );
  }

  Widget _buildPdfInput() {
    return Column(
      key: const ValueKey('pdf'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload PDF Document', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        // Fixed: Material+InkWell instead of GestureDetector
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: AppColors.backgroundElevated,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isFetching ? null : _pickAndExtractPdf,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _fetchedMetadata != null
                        ? AppColors.accentGreen
                        : AppColors.borderCard,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _fetchedMetadata != null
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      size: 40,
                      color: _fetchedMetadata != null
                          ? AppColors.accentGreen
                          : AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _fetchedMetadata != null
                          ? 'PDF Extracted Successfully'
                          : 'Tap to pick a PDF file',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _fetchedMetadata != null
                            ? AppColors.accentGreen
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_fetchedMetadata != null) ...[
          const SizedBox(height: 20),
          _buildTopicsPreview(),
        ],
        const SizedBox(height: 24),
        _buildGoalInput(),
      ],
    );
  }

  Widget _buildGoalInput() {
    // flutter-building-forms skill: TextFormField with validator
    // Validator returns String on error, null on success.
    return TextFormField(
      controller: _controller,
      style: AppTextStyles.bodyLarge,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'e.g. Learn Java, Master SQL...',
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a learning goal';
        }
        if (value.trim().length < 3) {
          return 'Goal must be at least 3 characters';
        }
        return null; // valid
      },
      onFieldSubmitted: (_) => _createGoal(),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 400.ms)
        .slideY(begin: 0.15, end: 0);
  }

  Widget _buildSuggestions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _suggestions.asMap().entries.map((entry) {
        // Fixed: Material+InkWell for proper ripple on chips
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: AppColors.backgroundElevated,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              splashColor: AppColors.accentAmber.withOpacity(0.1),
              onTap: () => setState(() => _controller.text = entry.value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderCard),
                ),
                child: Text(entry.value, style: AppTextStyles.bodyMedium),
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: (450 + entry.key * 40).toInt()))
            .scale(begin: const Offset(0.9, 0.9));
      }).toList(),
    );
  }

  // ── Topics preview ────────────────────────────────────────────────────────

  Widget _buildTopicsPreview() {
    final metadata = _fetchedMetadata!;
    final totalDurationSec =
        metadata.fold(0, (sum, item) => sum + (item['duration_sec'] as int));
    final totalMinutes = (totalDurationSec / 60).ceil();
    final averageMinutesPerDay = (totalMinutes / _days).ceil();

    String formatDuration(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    // Group topics by chapter
    final List<dynamic> displayItems = [];
    String? lastChapter;
    for (final item in metadata) {
      final chapter = item['chapter'] as String? ?? 'Exploration';
      if (chapter != lastChapter) {
        displayItems.add({'type': 'header', 'title': chapter});
        lastChapter = chapter;
      }
      displayItems.add({'type': 'topic', 'data': item});
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.map_rounded,
                        size: 18, color: AppColors.accentAmber),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'QUEST LOG',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.accentAmber,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formatDuration(Duration(seconds: totalDurationSec)),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: ListView.builder(
              itemCount: displayItems.length,
              itemBuilder: (ctx, i) {
                final entry = displayItems[i];

                if (entry['type'] == 'header') {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentAmber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.accentAmber.withOpacity(0.2)),
                          ),
                          child: Text(
                            (entry['title'] as String).toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.accentAmber,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Divider(
                                color:
                                    AppColors.accentAmber.withOpacity(0.15))),
                      ],
                    ),
                  );
                }

                final item = entry['data'] as Map<String, dynamic>;
                final bool isBoss = item['is_boss'] as bool? ?? false;
                final String rank = item['rank'] as String? ?? 'B';
                final subtopics =
                    item['subtopics'] as List<dynamic>? ?? [];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: EdgeInsets.all(isBoss ? 12 : 8),
                    decoration: BoxDecoration(
                      color: isBoss
                          ? AppColors.accentAmber.withOpacity(0.05)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isBoss
                          ? Border.all(
                              color: AppColors.accentAmber.withOpacity(0.3))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isBoss)
                              const Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: Icon(Icons.gite_rounded,
                                    size: 20, color: AppColors.accentAmber),
                              ),
                            Expanded(
                              child: Text(
                                item['title'],
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isBoss
                                      ? AppColors.accentAmber
                                      : AppColors.textPrimary,
                                  fontWeight: isBoss
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _rankBadge(rank),
                          ],
                        ),
                        if (subtopics.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: subtopics
                                  .take(4)
                                  .map((sub) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.03),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          sub.toString(),
                                          style:
                                              AppTextStyles.labelSmall.copyWith(
                                            fontSize: 8,
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Target: ${averageMinutesPerDay.clamp(10, 480)}m / day',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted, fontSize: 10),
                ),
                if (averageMinutesPerDay > 120)
                  Text(
                    '⚠️ High Difficulty',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.accentAmber, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(String rank) {
    Color color;
    switch (rank.toUpperCase()) {
      case 'S':
        color = AppColors.accentAmber;
        break;
      case 'A':
        color = const Color(0xFFFF6B6B);
        break;
      case 'B':
        color = const Color(0xFF4DABF7);
        break;
      case 'C':
        color = AppColors.accentGreen;
        break;
      default:
        color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        'RANK $rank',
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── CTA ───────────────────────────────────────────────────────────────────

  Widget _buildCTA() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isCreating ? null : _createGoal,
        child: _isCreating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.backgroundDark,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Generate My Plan'),
                  const SizedBox(width: 8),
                  Icon(
                      _fetchedMetadata == null || _sourceType == 'ai'
                          ? Icons.bolt_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18),
                ],
              ),
      ),
    )
        .animate()
        .fadeIn(delay: 750.ms, duration: 400.ms)
        .slideY(begin: 0.3, end: 0);
  }
}
