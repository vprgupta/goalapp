import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/topic_model.dart';
import '../../providers/goal_provider.dart';
import '../../../domain/services/resource_service.dart';
import '../../../domain/services/resource_registry.dart';

class TopicResourceScreen extends ConsumerStatefulWidget {
  final String topicId;

  const TopicResourceScreen({
    super.key,
    required this.topicId,
  });

  @override
  ConsumerState<TopicResourceScreen> createState() => _TopicResourceScreenState();
}

class _TopicResourceScreenState extends ConsumerState<TopicResourceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _resourceService = ResourceService();
  bool _isLoading = true;
  List<Map<String, String>> _resources = [];
  TopicModel? _topic;

  Map<String, dynamic> get _masteryData {
    final masteryRes = _resources.firstWhere(
      (r) => r['type'] == 'mastery_hub',
      orElse: () => {},
    );
    if (masteryRes.isEmpty) return {};
    return jsonDecode(masteryRes['description']!);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final repo = ref.read(goalRepositoryProvider);
    final topic = repo.getTopic(widget.topicId);
    
    if (topic == null) {
      if (mounted) context.pop();
      return;
    }

    setState(() {
      _topic = topic;
      _isLoading = true;
    });

    bool cacheIsValid = false;
    if (!forceRefresh && topic.resources.isNotEmpty) {
      try {
        final cached = topic.resources
            .map((e) => Map<String, String>.from(jsonDecode(e)))
            .toList();
        // Valid cache = at least 1 resource with a real URL (not empty)
        final resourcesWithUrls = cached.where(
          (r) => r['type'] != 'practice_set' && r['type'] != 'mastery_hub' && (r['url']?.isNotEmpty ?? false),
        ).toList();
        if (resourcesWithUrls.length >= 1) {
          _resources = cached;
          _isLoading = false;
          cacheIsValid = true;
        }
      } catch (_) {
        // Corrupted cache — will re-fetch
      }
    }

    setState(() {});

    if (!cacheIsValid) {
      final goal = ref.read(activeGoalProvider);
      List<Map<String, String>> fetched = [];

      // Primary: LLM-based resource fetch
      try {
        fetched = await _resourceService.fetchResources(
          topicName: topic.name,
          goalName: goal?.name ?? 'Skill Mastery',
          level: goal?.level ?? 'Beginner',
        );
      } catch (e) {
        debugPrint('[ResourceScreen] fetchResources threw: $e');
      }

      // Guaranteed fallback: if LLM fetch returned nothing, use deterministic registry
      if (fetched.isEmpty) {
        debugPrint('[ResourceScreen] LLM fetch empty — falling back to ResourceRegistry');
        fetched = ResourceRegistry.buildResources(
          topicConcept: topic.name,
          pillarName: topic.moduleName ?? goal?.name ?? 'Core',
          goalName: goal?.name ?? 'Skill Mastery',
          level: goal?.level ?? 'Beginner',
        );
      }

      if (mounted) {
        setState(() {
          _resources = fetched;
          _isLoading = false;
        });

        // Save to Hive for offline use
        if (fetched.isNotEmpty) {
          topic.resources = fetched.map((e) => jsonEncode(e)).toList();
          await repo.saveTopic(topic);
        }
      }
    }
  }

  void _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      debugPrint('Could not launch URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_topic == null) return const Scaffold();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.accentAmber.withOpacity(0.12),
              AppColors.backgroundDark,
              AppColors.backgroundDark,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              expandedHeight: 200,
              pinned: true,
              forceElevated: innerBoxIsScrolled,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  onPressed: () => _loadData(forceRefresh: true),
                  tooltip: 'Refresh Mastery Hub',
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      right: -30,
                      bottom: 0,
                      // Hero destination: matches 'topic_icon_${topicId}' tag
                      // set in task_card_widget.dart — flies from the task card icon.
                      child: Hero(
                        tag: 'topic_icon_${widget.topicId}',
                        child: Icon(
                          _topic!.isBoss ? Icons.gite_rounded : Icons.menu_book_rounded,
                          size: 160,
                          color: AppColors.accentAmber.withOpacity(0.04),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentAmber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _topic!.moduleName?.toUpperCase() ?? 'CORE MODULE',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.accentAmber,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                if (_topic!.isBoss) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentRed.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'BOSS NODE',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.accentRed,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 9,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ).animate().fadeIn().slideX(begin: -0.1),
                            const SizedBox(height: 12),
                            Text(
                              _topic!.name,
                              style: AppTextStyles.headlineMedium.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.transparent,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: AppColors.accentAmber,
                    labelColor: AppColors.accentAmber,
                    unselectedLabelColor: AppColors.textMuted,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    labelStyle: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    tabs: const [
                      Tab(text: 'Videos'),
                      Tab(text: 'Theory'),
                      Tab(text: 'Visuals'),
                      Tab(text: 'Practice'),
                      Tab(text: 'Sandbox'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildResourceList('video'),
              _buildResourceList('article'),
              _buildResourceList('visual'),
              _buildPracticeTab(),
              _buildResourceList('interactive'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntuitionCard() {
    final synopsis = _masteryData['synopsis'] ?? 'Generating intuition for this topic...';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accentAmber.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: AppColors.accentAmber, size: 20),
              const SizedBox(width: 10),
              Text(
                'THE INTUITION',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.accentAmber, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            synopsis,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withOpacity(0.9), height: 1.6, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildPitfallsCard() {
    final pitfalls = List<String>.from(_masteryData['pitfalls'] ?? []);
    if (pitfalls.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 20),
              const SizedBox(width: 10),
              Text(
                'EXAM PITFALLS',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.accentRed, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...pitfalls.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold, fontSize: 18)),
                    Expanded(
                      child: Text(p, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70, height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildRevisionSheet() {
    final cheatSheet = _masteryData['revision_sheet'] ?? '';
    if (cheatSheet.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD43B).withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFFFD43B).withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD43B), size: 24),
              const SizedBox(width: 12),
              Text(
                'FINAL REVISION SHEET',
                style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFFFFD43B), fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            cheatSheet,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, height: 1.7, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildOverviewTab() {
    if (_isLoading) return _buildShimmer();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      children: [
        _buildIntuitionCard(),
        _buildPitfallsCard(),
        _buildRevisionSheet(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPracticeTab() {
    if (_isLoading) return _buildShimmer();

    final practiceSetResource = _resources.firstWhere(
      (r) => r['type'] == 'practice_set',
      orElse: () => {},
    );

    if (practiceSetResource.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_rounded, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'No practice questions found.\nTap Refresh to generate them!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final List<dynamic> questions = jsonDecode(practiceSetResource['description']!);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        return PracticeExerciseCard(
          data: Map<String, dynamic>.from(questions[index]),
          index: index,
        ).animate().fadeIn(delay: (index * 150).ms).slideX(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildResourceList(String type) {
    if (_isLoading) return _buildShimmer();

    final list = _resources.where((r) => r['type'] == type).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No ${type}s found yet',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final res = list[index];
        final isRealVideo = type == 'video' && (res['video_id']?.isNotEmpty ?? false);
        return (isRealVideo
            ? _buildYouTubeCard(res)
            : _buildResourceCard(res, AppColors.accentAmber))
            .animate()
            .fadeIn(delay: (index * 100).ms)
            .slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildYouTubeCard(Map<String, String> res) {
    final thumbnailUrl = res['thumbnail_url'] ?? '';
    final title = res['title'] ?? 'Video Tutorial';
    final channelTitle = res['channel_title'] ?? res['source'] ?? 'YouTube';
    final viewCount = int.tryParse(res['view_count'] ?? '0') ?? 0;
    final durationSec = int.tryParse(res['duration_seconds'] ?? '0') ?? 0;
    final qualityNote = res['quality_note'] ?? '';
    final isTopPick = (res['rank'] ?? '') == '1';

    String viewLabel = '$viewCount views';
    if (viewCount >= 1000000) viewLabel = '${(viewCount / 1000000).toStringAsFixed(1)}M views';
    else if (viewCount >= 1000) viewLabel = '${(viewCount / 1000).toStringAsFixed(0)}K views';

    String durLabel = '';
    if (durationSec > 0) {
      if (durationSec >= 3600) {
        final h = durationSec ~/ 3600;
        final m = (durationSec % 3600) ~/ 60;
        durLabel = '${h}h ${m}m';
      } else {
        final m = durationSec ~/ 60;
        final s = durationSec % 60;
        durLabel = '$m:${s.toString().padLeft(2, '0')}';
      }
    }

    return GestureDetector(
      onTap: () => _launchUrl(res['url']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTopPick
                ? AppColors.accentAmber.withOpacity(0.5)
                : AppColors.borderCard,
            width: isTopPick ? 1.5 : 1.0,
          ),
          boxShadow: isTopPick
              ? [BoxShadow(color: AppColors.accentAmber.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 6))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ───────────────────────────────────────────────────
            if (thumbnailUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    Image.network(
                      thumbnailUrl,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: AppColors.backgroundCard,
                        child: const Center(
                          child: Icon(Icons.play_circle_outline_rounded, color: Colors.white24, size: 56),
                        ),
                      ),
                    ),
                    // Duration badge
                    if (durLabel.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            durLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    // Play overlay
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // ── Info Row ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(fontSize: 14, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFFF0000), size: 12),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          channelTitle,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: const Color(0xFFFF0000).withOpacity(0.9),
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (viewLabel.isNotEmpty)
                        Text(
                          viewLabel,
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                        ),
                    ],
                  ),
                  if (qualityNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentAmber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.accentAmber.withOpacity(0.25)),
                      ),
                      child: Text(
                        qualityNote,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.accentAmber,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCard(Map<String, String> res, Color themeColor) {
    final rank = res['rank'] ?? '';
    final qualityNote = res['quality_note'] ?? '';
    final description = res['description'] ?? '';
    final hasRank = rank.isNotEmpty;
    final isTopPick = rank == '1';

    return GestureDetector(
      onTap: () => _launchUrl(res['url']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isTopPick
                ? AppColors.accentAmber.withOpacity(0.5)
                : AppColors.borderCard,
            width: isTopPick ? 1.5 : 1.0,
          ),
          boxShadow: isTopPick
              ? [
                  BoxShadow(
                    color: AppColors.accentAmber.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rank + Icon
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getResourceIcon(res['type'] ?? ''),
                          color: themeColor,
                          size: 22,
                        ),
                      ),
                      if (hasRank)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: isTopPick
                                  ? AppColors.accentAmber
                                  : AppColors.backgroundCard,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isTopPick
                                    ? AppColors.accentAmber
                                    : AppColors.borderCard,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '#$rank',
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                  color: isTopPick
                                      ? AppColors.backgroundDark
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          res['title'] ?? 'Resource',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontSize: 14,
                            color: isTopPick
                                ? AppColors.textPrimary
                                : AppColors.textPrimary.withOpacity(0.9),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              res['source'] ?? 'Web',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: themeColor.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                            if (qualityNote.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppColors.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  qualityNote,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 15,
                    color: Colors.white24,
                  ),
                ],
              ),
              // ── Description ───────────────────────────────────────────────
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.white10),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary.withOpacity(0.75),
                    height: 1.5,
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // ── Top Pick Banner ───────────────────────────────────────────
              if (isTopPick) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accentAmber.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded,
                          size: 11, color: AppColors.accentAmber),
                      const SizedBox(width: 5),
                      Text(
                        'CURATOR\'S TOP PICK',
                        style: AppTextStyles.tagStyle.copyWith(
                          color: AppColors.accentAmber,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  IconData _getResourceIcon(String type) {
    switch (type) {
      case 'video': return Icons.play_circle_fill_rounded;
      case 'article': return Icons.description_rounded;
      case 'visual': return Icons.image_rounded;
      case 'audio': return Icons.headphones_rounded;
      case 'interactive': return Icons.code_rounded;
      default: return Icons.link_rounded;
    }
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.05)),
    );
  }
}

class PracticeExerciseCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;

  const PracticeExerciseCard({super.key, required this.data, required this.index});

  @override
  State<PracticeExerciseCard> createState() => _PracticeExerciseCardState();
}

class _PracticeExerciseCardState extends State<PracticeExerciseCard> {
  int? _selectedIndex;
  bool _revealed = false;

  void _handleSelect(int idx) {
    if (_revealed) return;
    setState(() {
      _selectedIndex = idx;
      _revealed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.data['type'] ?? 'mcq';
    final question = widget.data['question'] ?? 'No question text?';
    final explanation = widget.data['explanation'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderCard, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBadge(type),
          const SizedBox(height: 16),
          Text(question, style: AppTextStyles.titleMedium.copyWith(fontSize: 18, height: 1.4)),
          const SizedBox(height: 24),
          _buildExerciseBody(type),
          if (_revealed) _buildSolutionSection(type, explanation),
        ],
      ),
    );
  }

  Widget _buildBadge(String type) {
    String label = 'MCQ';
    IconData icon = Icons.quiz_rounded;
    Color color = AppColors.accentAmber;

    if (type == 'code') {
      label = 'CODING';
      icon = Icons.code_rounded;
      color = const Color(0xFF4DABF7);
    } else if (type == 'theory') {
      label = 'THEORY';
      icon = Icons.history_edu_rounded;
      color = const Color(0xFFB197FC);
    }

    final difficulty = widget.data['difficulty']?.toString() ?? '';
    Color diffColor;
    String diffLabel;
    IconData diffIcon;
    switch (difficulty) {
      case 'easy':
        diffColor = const Color(0xFF69DB7C);
        diffLabel = 'EASY';
        diffIcon = Icons.looks_one_rounded;
        break;
      case 'medium':
        diffColor = const Color(0xFFFFD43B);
        diffLabel = 'MEDIUM';
        diffIcon = Icons.looks_two_rounded;
        break;
      case 'hard':
        diffColor = const Color(0xFFFF6B6B);
        diffLabel = 'HARD';
        diffIcon = Icons.whatshot_rounded;
        break;
      case 'brainstorm':
        diffColor = const Color(0xFFB197FC);
        diffLabel = 'BRAINSTORM';
        diffIcon = Icons.psychology_rounded;
        break;
      default:
        diffColor = AppColors.textMuted;
        diffLabel = 'Q${widget.index + 1}';
        diffIcon = Icons.help_outline_rounded;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (difficulty.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: diffColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: diffColor.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(diffIcon, size: 13, color: diffColor),
                const SizedBox(width: 6),
                Text(
                  diffLabel,
                  style: AppTextStyles.labelSmall.copyWith(color: diffColor, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ],
            ),
          ),
        const Spacer(),
        Text(
          'Q${widget.index + 1}',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildExerciseBody(String type) {
    if (type == 'code') {
      final starter = widget.data['starter_code'] ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (starter.isNotEmpty) _buildCodeSnippet(starter),
          const SizedBox(height: 12),
          if (!_revealed)
            _buildActionCard(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Tap to see standard solution',
              color: const Color(0xFF4DABF7),
              onTap: () => setState(() => _revealed = true),
            ),
        ],
      );
    } else if (type == 'theory') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_revealed)
            _buildActionCard(
              icon: Icons.remove_red_eye_rounded,
              title: 'Reveal Exam-Standard Answer',
              color: const Color(0xFFB197FC),
              onTap: () => setState(() => _revealed = true),
            ),
        ],
      );
    } else {
      // Default MCQ
      final options = List<String>.from(widget.data['options'] ?? []);
      final correctIdx = widget.data['correct_index'] ?? 0;
      return Column(
        children: List.generate(options.length, (i) => _buildMcqOption(i, options[i], correctIdx)),
      );
    }
  }

  Widget _buildCodeSnippet(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          color: Color(0xFFE6EDF3),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(title, style: AppTextStyles.bodyMedium.copyWith(color: color, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSolutionSection(String type, String explanation) {
    String solTitle = 'IDEAL SOLUTION';
    String? solCode = widget.data['solution'];
    String? solTheory = widget.data['solution'];
    Color color = AppColors.accentAmber;

    if (type == 'code') {
      solTitle = 'STANDARD CODE SOLUTION';
      color = const Color(0xFF4DABF7);
    } else if (type == 'theory') {
      solTitle = 'EXAM-STANDARD ANSWER';
      color = const Color(0xFFB197FC);
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                solTitle,
                style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (type == 'code' && solCode != null) ...[
            _buildCodeSnippet(solCode),
            const SizedBox(height: 16),
          ],
          if (type == 'theory' && solTheory != null) ...[
            Text(
              solTheory,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.6, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
          ],
          Text(explanation, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildMcqOption(int idx, String text, int correctIdx) {
    final isSelected = _selectedIndex == idx;
    final isCorrect = idx == correctIdx;
    
    Color borderColor = AppColors.borderCard;
    Color bgColor = Colors.transparent;
    Widget? trailing;

    if (_revealed) {
      if (isCorrect) {
        borderColor = AppColors.accentGreen;
        bgColor = AppColors.accentGreen.withOpacity(0.1);
        trailing = const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.accentGreen);
      } else if (isSelected) {
        borderColor = AppColors.accentRed;
        bgColor = AppColors.accentRed.withOpacity(0.1);
        trailing = const Icon(Icons.cancel_rounded, size: 18, color: AppColors.accentRed);
      }
    } else if (isSelected) {
      borderColor = AppColors.accentAmber;
      bgColor = AppColors.accentAmber.withOpacity(0.05);
    }

    return GestureDetector(
      onTap: () => _handleSelect(idx),
      child: AnimatedContainer(
        duration: 250.ms,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected || (_revealed && isCorrect) ? 1.8 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _revealed && isCorrect ? AppColors.accentGreen : (isSelected ? AppColors.accentAmber : AppColors.textPrimary),
                  fontWeight: isSelected || (_revealed && isCorrect) ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
