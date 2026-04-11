import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/goal_provider.dart';
import '../../../domain/services/youtube_service.dart';

class GoalSetupScreen extends ConsumerStatefulWidget {
  const GoalSetupScreen({super.key});

  @override
  ConsumerState<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends ConsumerState<GoalSetupScreen> {
  final _controller = TextEditingController();
  final _urlController = TextEditingController();
  final _ytService = YouTubeService();

  String _level = 'beginner';
  double _days = 14;
  bool _isCreating = false;
  bool _isYoutubeSource = false;
  bool _isFetching = false;
  List<Map<String, dynamic>>? _fetchedMetadata;

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
    super.dispose();
  }

  Future<void> _fetchPlaylist() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isFetching = true);
    try {
      final metadata = await _ytService.fetchPlaylistMetadata(url);
      setState(() {
        _fetchedMetadata = metadata;
        _isFetching = false;
      });
    } catch (e) {
      setState(() => _isFetching = false);
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

    if (_isYoutubeSource && (_fetchedMetadata == null || _fetchedMetadata!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fetch the playlist syllabus first')),
      );
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                  child: _isYoutubeSource ? _buildYoutubeInput() : _buildGoalInputSection(),
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
            color: selected ? AppColors.accentAmber.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accentAmber : AppColors.borderCard,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.accentAmber : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: selected ? AppColors.accentAmber : AppColors.textSecondary,
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.backgroundDark),
                      )
                    : const Icon(Icons.download_rounded, color: AppColors.backgroundDark),
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
    final totalDurationSec = metadata.fold(0, (sum, item) => sum + (item['duration_sec'] as int));
    final totalMinutes = (totalDurationSec / 60).ceil();
    final averageMinutesPerDay = (totalMinutes / _days).ceil();
    final dynamicMaxMinutes = averageMinutesPerDay.clamp(15, 120);

    String formatDuration(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final s = d.inSeconds % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    String formatTag(Duration d) {
       final h = d.inHours;
      final m = d.inMinutes % 60;
      final s = d.inSeconds % 60;
      return h > 0 ? '$h:$m:$s' : '$m:$s';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.list_alt_rounded, size: 16, color: AppColors.accentGreen),
                  const SizedBox(width: 8),
                  Text(
                    'Syllabus Preview',
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.accentGreen),
                  ),
                ],
              ),
              Text(
                'Total: ${formatDuration(Duration(seconds: totalDurationSec))}',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              itemCount: metadata.length,
              itemBuilder: (ctx, i) {
                final item = metadata[i];
                final videoMinutes = ((item['duration_sec'] as int) / 60).ceil();
                final splitParts = (videoMinutes / dynamicMaxMinutes).ceil();
                final isSplit = splitParts > 1;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${i + 1}. ${item['title']}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSplit ? AppColors.accentAmber.withOpacity(0.1) : AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isSplit ? '$splitParts Parts' : formatTag(Duration(seconds: item['duration_sec'] as int)),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isSplit ? AppColors.accentAmber : AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Session Estimate: ~${averageMinutesPerDay.clamp(10, 480)} mins',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textPrimary, fontSize: 10),
                ),
                if (averageMinutesPerDay > 120)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Warning: Heavy workload. Consider increasing days.',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.accentAmber, fontSize: 10),
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
        )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut),
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
        )
            .animate()
            .fadeIn(delay: 350.ms, duration: 500.ms),
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
            .fadeIn(delay: Duration(milliseconds: 450 + entry.key * 40))
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
            _levelButton('intermediate', 'Intermediate', Icons.trending_up_rounded),
            const SizedBox(width: 10),
            _levelButton('advanced', 'Advanced', Icons.local_fire_department_rounded),
          ],
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 550.ms, duration: 400.ms);
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
    )
        .animate()
        .fadeIn(delay: 650.ms, duration: 400.ms);
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
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    )
        .animate()
        .fadeIn(delay: 750.ms, duration: 400.ms)
        .slideY(begin: 0.3, end: 0);
  }
}
