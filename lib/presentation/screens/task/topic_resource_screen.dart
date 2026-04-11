import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadData();
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
      if (!forceRefresh && topic.resources.isNotEmpty) {
        _resources = topic.resources.map((e) => Map<String, String>.from(jsonDecode(e))).toList();
        _isLoading = false;
      }
    });

    if (_resources.isEmpty || forceRefresh) {
      final goal = ref.read(activeGoalProvider);
      final fetched = await _resourceService.fetchResources(
        topicName: topic.name,
        goalName: goal?.name ?? 'Skill Mastery',
        level: goal?.level ?? 'Beginner',
      );

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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _getResourcesByType(String type) {
    return _resources.where((r) => r['type'] == type).toList();
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    try {
      // First try opening in an external app (browser/youtube)
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      
      // If external fails, try opening inside the app as a fallback
      if (!launched) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppBrowserView,
        );
      }
    } catch (e) {
      debugPrint('Could not launch URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_topic == null) return const Scaffold();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: AppColors.backgroundDark,
            expandedHeight: 200,
            floating: false,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: () => _loadData(forceRefresh: true),
                tooltip: 'Refresh Resources',
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.accentAmber.withOpacity(0.15),
                      AppColors.backgroundDark,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _topic!.moduleName ?? 'Core Module',
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.accentAmber),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (_topic!.isBoss)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accentRed.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'BOSS NODE',
                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.accentRed),
                              ),
                            ),
                        ],
                      ).animate().fadeIn().slideX(begin: -0.1),
                      const SizedBox(height: 12),
                      Text(
                        _topic!.name,
                        style: AppTextStyles.headlineLarge.copyWith(fontSize: 28),
                      ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.backgroundDark,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.accentAmber,
                labelColor: AppColors.accentAmber,
                unselectedLabelColor: AppColors.textMuted,
                tabs: const [
                  Tab(icon: Icon(Icons.play_circle_fill_rounded), text: 'Videos'),
                  Tab(icon: Icon(Icons.article_rounded), text: 'Articles'),
                  Tab(icon: Icon(Icons.image_rounded), text: 'Visuals'),
                  Tab(icon: Icon(Icons.headphones_rounded), text: 'Audio'),
                  Tab(icon: Icon(Icons.code_rounded), text: 'Interactive'),
                  Tab(icon: Icon(Icons.quiz_rounded), text: 'Practice'),
                ],
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
            _buildResourceList('audio'),
            _buildResourceList('interactive'),
            _buildPracticeList(),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceList(String type) {
    if (_isLoading) {
      return _buildShimmer();
    }

    final list = _getResourcesByType(type);

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
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final res = list[index];
        return _buildResourceCard(res)
            .animate()
            .fadeIn(delay: (index * 100).ms)
            .slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildResourceCard(Map<String, String> res) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchUrl(res['url']),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        res['source']?.toUpperCase() ?? 'WEB',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.accentAmber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  res['title'] ?? 'Resource',
                  style: AppTextStyles.titleMedium,
                ),
                if (res['description']?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text(
                    res['description']!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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

  Widget _buildPracticeList() {
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
      padding: const EdgeInsets.all(20),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        return PracticeExerciseCard(
          data: Map<String, dynamic>.from(questions[index]),
          index: index,
        ).animate().fadeIn(delay: (index * 150).ms).slideX(begin: 0.1, end: 0);
      },
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
    String label = 'EXERCISE';
    IconData icon = Icons.quiz_rounded;
    Color color = AppColors.accentAmber;

    if (type == 'code') {
      label = 'CODING TASK';
      icon = Icons.code_rounded;
      color = const Color(0xFF4DABF7);
    } else if (type == 'theory') {
      label = 'EXAM THEORY';
      icon = Icons.history_edu_rounded;
      color = const Color(0xFFB197FC);
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
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: 1),
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
