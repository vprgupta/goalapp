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

class GoalSetupScreen extends ConsumerStatefulWidget {
  const GoalSetupScreen({super.key});

  @override
  ConsumerState<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends ConsumerState<GoalSetupScreen> {
  final _controller = TextEditingController();
  final _urlController = TextEditingController();
  final _ytService = YouTubeService();
  final _aiService = AiService();

  String _level = 'beginner';
  double _days = 14;
  bool _isCreating = false;
  bool _isYoutubeSource = false;
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
    "Interleaving: Mixing different topics prevents 'learning plateaus'."
  ];

  final List<String> _loadingStatuses = [
    "Analyzing goal complexity...",
    "Curating expert content...",
    "Structuring curriculum hierarchy...",
    "Mapping scientific sub-topics...",
    "Refining path for your level...",
    "Optimizing revision schedule...",
    "Finalizing expert roadmap..."
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

  void _startLoadingTimers() {
    _tipTimer?.cancel();
    _statusTimer?.cancel();
    setState(() {
      _currentTipIndex = 0;
      _currentStatusIndex = 0;
    });

    _tipTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted)
        setState(() =>
            _currentTipIndex = (_currentTipIndex + 1) % _loadingTips.length);
    });

    _statusTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
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

  Future<void> _generateAiSyllabus() async {
    final goal = _controller.text.trim();
    if (goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a goal first')),
      );
      return;
    }

    setState(() => _isFetching = true);
    _startLoadingTimers();
    try {
      final metadata = await _aiService.generateSyllabus(
        goal: goal,
        level: _level,
        days: _days.round(),
      );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _createGoal() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a learning goal first')),
      );
      return;
    }

    if (_isYoutubeSource &&
        (_fetchedMetadata == null || _fetchedMetadata!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fetch the playlist syllabus first')),
      );
      return;
    }

    if (!_isYoutubeSource && _fetchedMetadata == null) {
      // First time clicking while AI source is active: Generate syllabus
      await _generateAiSyllabus();
      return;
    }

    setState(() => _isCreating = true);
    await ref.read(activeGoalProvider.notifier).createGoal(
          name: name,
          level: _level,
          totalDays: _days.round(),
          customMetadata: _fetchedMetadata,
        );
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
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
            child: _isFetching
                ? _buildLoadingState()
                : SingleChildScrollView(
                    key: const ValueKey('form'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildHeader(),
                        const SizedBox(height: 32),
                        _buildSourceSelector(),
                        const SizedBox(height: 32),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isYoutubeSource
                              ? _buildYoutubeInput()
                              : _buildGoalInputSection(),
                        ),
                        const SizedBox(height: 36),
                        _buildLevelPicker(),
                        const SizedBox(height: 36),
                        _buildDurationSlider(),
                        const SizedBox(height: 48),
                        _buildCTA(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      key: const ValueKey('loading'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Background Aura
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accentAmber.withOpacity(0.2),
                        AppColors.accentAmber.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.3, 1.3),
                        duration: 2.seconds,
                        curve: Curves.easeInOut)
                    .fadeOut(duration: 2.seconds, curve: Curves.easeInOut),

                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundElevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.accentAmber.withOpacity(0.3),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentAmber.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 40,
                    color: AppColors.accentAmber,
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 3.seconds, color: Colors.white24)
                    .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.05, 1.05),
                        duration: 1.5.seconds,
                        curve: Curves.easeInOut)
                    .then()
                    .scale(
                        begin: const Offset(1.05, 1.05),
                        end: const Offset(1, 1),
                        duration: 1.5.seconds,
                        curve: Curves.easeInOut),
              ],
            ),

            const SizedBox(height: 48),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _loadingStatuses[_currentStatusIndex],
                key: ValueKey(_currentStatusIndex),
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Personalizing for ',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
                Text(
                  _level.toUpperCase(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.accentAmber,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 64),

            // Premium Tips Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.backgroundElevated.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ClipRRect(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                              color: AppColors.accentAmber,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'MASTER TIPS',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.accentAmber.withOpacity(0.8),
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                              color: AppColors.accentAmber,
                              shape: BoxShape.circle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Text(
                        _loadingTips[_currentTipIndex],
                        key: ValueKey(_currentTipIndex),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary.withOpacity(0.9),
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 800.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

            const SizedBox(height: 56),

            // Refined Progress Indicator
            Stack(
              children: [
                Container(
                  width: 160,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: 160,
                  height: 3,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accentAmber.withOpacity(0.6)),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 1200.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Row(
      children: [
        _sourceButton(false, 'AI Syllabus', Icons.auto_awesome_rounded),
        const SizedBox(width: 12),
        _sourceButton(true, 'YouTube Playlist', Icons.video_library_rounded),
      ],
    );
  }

  Widget _sourceButton(bool isYoutube, String label, IconData icon) {
    final selected = _isYoutubeSource == isYoutube;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _isYoutubeSource = isYoutube;
          if (!isYoutube) _fetchedMetadata = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentAmber.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accentAmber : AppColors.borderCard,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? AppColors.accentAmber
                      : AppColors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: selected
                        ? AppColors.accentAmber
                        : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            GestureDetector(
              onTap: _isFetching ? null : _fetchPlaylist,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.accentAmber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isFetching
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.backgroundDark),
                      )
                    : const Icon(Icons.download_rounded,
                        color: AppColors.backgroundDark),
              ),
            ),
          ],
        ),
        if (_fetchedMetadata != null) ...[
          const SizedBox(height: 20),
          _buildTopicsPreview(),
        ],
        const SizedBox(height: 24),
        _buildGoalInput(), // Reuse for naming the goal
      ],
    );
  }

  Widget _buildTopicsPreview() {
    final metadata = _fetchedMetadata!;
    final totalDurationSec =
        metadata.fold(0, (sum, item) => sum + (item['duration_sec'] as int));
    final totalMinutes = (totalDurationSec / 60).ceil();
    final averageMinutesPerDay = (totalMinutes / _days).ceil();
    final dynamicMaxMinutes = averageMinutesPerDay.clamp(15, 120);

    String formatDuration(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final s = d.inSeconds % 60;
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.accentAmber,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          (entry['title'] as String).toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 1,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child:
                                Divider(color: Colors.white.withOpacity(0.05))),
                      ],
                    ),
                  );
                }

                final item = entry['data'] as Map<String, dynamic>;
                final bool isBoss = item['is_boss'] as bool? ?? false;
                final String rank = item['rank'] as String? ?? 'B';
                final topicMinutes =
                    ((item['duration_sec'] as int) / 60).ceil();
                final subtopics = item['subtopics'] as List<dynamic>? ?? [];

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
                        if (isBoss)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'BOSS CHALLENGE',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.accentAmber,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
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
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.accentAmber, fontSize: 10),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accentAmber, Color(0xFFFF6B35)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text(
          'What do you\nwant to learn?',
          style: AppTextStyles.displayLarge.copyWith(height: 1.15),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 500.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          'Build a science-backed plan that adapts to you.',
          style: AppTextStyles.bodyMedium,
        ).animate().fadeIn(delay: 350.ms, duration: 500.ms),
      ],
    );
  }

  Widget _buildGoalInput() {
    return TextField(
      controller: _controller,
      style: AppTextStyles.bodyLarge,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'e.g. Learn Java, Master SQL...',
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
      ),
      onSubmitted: (_) => _createGoal(),
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
        return GestureDetector(
          onTap: () => setState(() => _controller.text = entry.value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderCard),
            ),
            child: Text(entry.value, style: AppTextStyles.bodyMedium),
          ),
        )
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: (450 + entry.key * 40).toInt()))
            .scale(begin: const Offset(0.9, 0.9));
      }).toList(),
    );
  }

  Widget _buildLevelPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Level', style: AppTextStyles.titleMedium),
        const SizedBox(height: 14),
        Row(
          children: [
            _levelButton('beginner', 'Beginner', Icons.spa_rounded),
            const SizedBox(width: 10),
            _levelButton(
                'intermediate', 'Intermediate', Icons.trending_up_rounded),
            const SizedBox(width: 10),
            _levelButton(
                'advanced', 'Advanced', Icons.local_fire_department_rounded),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 550.ms, duration: 400.ms);
  }

  Widget _levelButton(String value, String label, IconData icon) {
    final selected = _level == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _level = value),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentAmber.withOpacity(0.15)
                : AppColors.backgroundElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accentAmber : AppColors.borderCard,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected
                      ? AppColors.accentAmber
                      : AppColors.textSecondary),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: selected
                      ? AppColors.accentAmber
                      : AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Duration', style: AppTextStyles.titleMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_days.round()} days',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.accentAmber),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.accentAmber,
            inactiveTrackColor: AppColors.progressTrack,
            thumbColor: AppColors.accentAmber,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            overlayColor: AppColors.accentAmber.withOpacity(0.15),
          ),
          child: Slider(
            value: _days,
            min: 7,
            max: 90,
            divisions: 83,
            onChanged: (v) => setState(() => _days = v),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('7 days', style: AppTextStyles.bodySmall),
            Text('90 days', style: AppTextStyles.bodySmall),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 650.ms, duration: 400.ms);
  }

  Widget _buildCTA() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isCreating ? null : _createGoal,
        child: _isCreating
            ? SizedBox(
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
                      _fetchedMetadata == null || _isYoutubeSource
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
