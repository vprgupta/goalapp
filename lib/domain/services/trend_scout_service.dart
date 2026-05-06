import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_config.dart';

/// Result returned by the Trend Scout Agent.
class TrendReport {
  /// Top skills/tools the job market currently demands for this tech.
  final List<String> inDemandSkills;

  /// Community-recommended learning order (e.g., from roadmap.sh, Reddit).
  final List<String> recommendedPhases;

  /// Latest trends (new frameworks, deprecated tools, ecosystem shifts).
  final List<String> recentTrends;

  /// Raw narrative from the web search — fed to the Architect as context.
  final String narrative;

  const TrendReport({
    required this.inDemandSkills,
    required this.recommendedPhases,
    required this.recentTrends,
    required this.narrative,
  });

  /// Formats the report as a concise brief for the Architect prompt.
  String toArchitectBrief() => '''
=== WEB RESEARCH REPORT (Trend Scout) ===

IN-DEMAND SKILLS (2025 Job Market):
${inDemandSkills.map((s) => '• $s').join('\n')}

COMMUNITY-RECOMMENDED LEARNING PATH:
${recommendedPhases.isNotEmpty ? recommendedPhases.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n') : '(No community consensus found — use strategic defaults)'}

LATEST ECOSYSTEM TRENDS:
${recentTrends.map((t) => '→ $t').join('\n')}

FULL RESEARCH NARRATIVE:
$narrative
=== END REPORT ===
''';
}

/// Agent 0 — Trend Scout
///
/// Uses Perplexity Sonar (web-search enabled model) to research:
/// 1. Popular roadmaps and recommended learning paths for the topic.
/// 2. In-demand skills from recent job postings.
/// 3. Ecosystem trends (new tools, deprecated tech, community advice).
///
/// The [TrendReport] is then injected into the Architect's prompt so the
/// final curriculum reflects real-world requirements, not just AI assumptions.
class TrendScoutService {
  static const _perplexityModel = 'perplexity/sonar-pro'; // web-search enabled
  static const _fallbackModel = 'perplexity/sonar';

  /// Run both research queries in parallel for speed.
  Future<TrendReport> research({
    required String goal,
    required String level,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('🌐 Trend Scout — Searching the web for "$goal" roadmaps...\n');

    try {
      // Run two targeted searches in parallel
      final results = await Future.wait([
        _webSearch(
          query: 'Best "$goal" learning roadmap for $level developers 2025 '
              'site:roadmap.sh OR site:dev.to OR site:reddit.com/r/learnprogramming',
          onProgress: null,
        ),
        _webSearch(
          query: '"$goal" in-demand skills and recent trends 2025 '
              'job requirements ecosystem changes',
          onProgress: null,
        ),
      ]);

      final roadmapRaw = results[0];
      final trendsRaw = results[1];

      onProgress?.call('✓ Web research complete — analysing findings...\n');

      // Parse the combined research into a structured report using a fast model
      final report = await _parseResearch(
        goal: goal,
        level: level,
        roadmapResearch: roadmapRaw,
        trendsResearch: trendsRaw,
        onProgress: onProgress,
      );

      onProgress?.call('✓ Trend Report ready.\n\n');
      return report;
    } catch (e) {
      // Graceful fallback — if search fails, return an empty report so the
      // main pipeline can continue without web grounding.
      onProgress?.call('⚠️ Web search unavailable — continuing without trends.\n\n');
      return const TrendReport(
        inDemandSkills: [],
        recommendedPhases: [],
        recentTrends: [],
        narrative: 'Web research unavailable.',
      );
    }
  }

  // ── Raw web search via Perplexity Sonar ──────────────────────────────────

  Future<String> _webSearch({
    required String query,
    void Function(String)? onProgress,
  }) async {
    final url = Uri.parse('${LlmConfig.openRouterBaseUrl}/chat/completions');
    final client = http.Client();

    try {
      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer ${LlmConfig.openRouterApiKey}';
      request.headers['HTTP-Referer'] = 'https://goalapp.dev';
      request.headers['X-Title'] = 'GoalApp TrendScout';

      request.body = jsonEncode({
        'model': _perplexityModel,
        'stream': false, // non-streaming for parallel execution
        'messages': [
          {
            'role': 'system',
            'content': 'You are a research assistant. Search the web and summarise '
                'the most relevant, up-to-date information. Be specific and factual. '
                'Cite the types of sources you found (e.g., official docs, community forums, job boards).',
          },
          {'role': 'user', 'content': query},
        ],
        'max_tokens': 800,
      });

      final response = await client.send(request).timeout(const Duration(seconds: 30));
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        // Try fallback model
        return await _webSearchWithModel(query: query, model: _fallbackModel);
      }

      final data = jsonDecode(body);
      return data['choices']?[0]?['message']?['content'] as String? ?? '';
    } catch (_) {
      return await _webSearchWithModel(query: query, model: _fallbackModel);
    } finally {
      client.close();
    }
  }

  Future<String> _webSearchWithModel({
    required String query,
    required String model,
  }) async {
    final url = Uri.parse('${LlmConfig.openRouterBaseUrl}/chat/completions');
    final client = http.Client();
    try {
      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer ${LlmConfig.openRouterApiKey}';
      request.headers['HTTP-Referer'] = 'https://goalapp.dev';
      request.body = jsonEncode({
        'model': model,
        'stream': false,
        'messages': [
          {'role': 'user', 'content': query},
        ],
        'max_tokens': 600,
      });
      final response = await client.send(request).timeout(const Duration(seconds: 25));
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);
      return data['choices']?[0]?['message']?['content'] as String? ?? '';
    } finally {
      client.close();
    }
  }

  // ── Parse raw research into structured TrendReport ───────────────────────

  Future<TrendReport> _parseResearch({
    required String goal,
    required String level,
    required String roadmapResearch,
    required String trendsResearch,
    void Function(String)? onProgress,
  }) async {
    final url = Uri.parse('${LlmConfig.openRouterBaseUrl}/chat/completions');
    final client = http.Client();

    const parsePrompt = '''
You are a research analyst. Parse the following web research into a structured JSON report.

GOAL: {goal}
LEVEL: {level}

--- ROADMAP RESEARCH ---
{roadmap}

--- TRENDS RESEARCH ---
{trends}
--- END RESEARCH ---

Return ONLY this JSON (no markdown, no extra text):
{
  "in_demand_skills": ["skill1", "skill2", "skill3", "skill4", "skill5"],
  "recommended_phases": ["phase1", "phase2", "phase3", "phase4", "phase5", "phase6"],
  "recent_trends": ["trend1", "trend2", "trend3"],
  "narrative": "2-3 sentence summary of key findings"
}

Rules:
- in_demand_skills: top 5 skills/tools from job postings or community surveys
- recommended_phases: 4-6 learning phases in order (from beginner to advanced), specific to the goal
- recent_trends: 2-4 recent ecosystem changes (new frameworks, deprecations, paradigm shifts)
- narrative: concise synthesis to guide roadmap generation
''';

    try {
      final filledPrompt = parsePrompt
          .replaceAll('{goal}', goal)
          .replaceAll('{level}', level)
          .replaceAll('{roadmap}', roadmapResearch.length > 1500
              ? roadmapResearch.substring(0, 1500)
              : roadmapResearch)
          .replaceAll('{trends}', trendsResearch.length > 1500
              ? trendsResearch.substring(0, 1500)
              : trendsResearch);

      Exception? lastException;
      for (final model in LlmConfig.openRouterModels) {
        final request = http.Request('POST', url);
        request.headers['Content-Type'] = 'application/json';
        request.headers['Authorization'] = 'Bearer ${LlmConfig.openRouterApiKey}';
        request.headers['HTTP-Referer'] = 'https://goalapp.dev';
        request.body = jsonEncode({
          'model': model,
          'stream': false,
          'messages': [
            {'role': 'user', 'content': filledPrompt},
          ],
          'max_tokens': 500,
        });

        try {
          final response = await client.send(request).timeout(const Duration(seconds: 30));
          final body = await response.stream.bytesToString();
          
          if (response.statusCode == 200) {
            final data = jsonDecode(body);
            final raw = data['choices']?[0]?['message']?['content'] as String? ?? '{}';
            return _parseTrendJson(raw, roadmapResearch, trendsResearch);
          } else {
            lastException = Exception('OpenRouter Parsing Error ${response.statusCode} (Model: $model): $body');
          }
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
        }
      }
      throw lastException ?? Exception('All OpenRouter models failed to parse research');
    } finally {
      client.close();
    }
  }

  TrendReport _parseTrendJson(String raw, String roadmap, String trends) {
    try {
      String cleaned = raw.trim();
      if (cleaned.contains('```')) {
        final match = RegExp(r'\{[\s\S]*\}').stringMatch(cleaned);
        if (match != null) cleaned = match;
      }

      final Map<String, dynamic> json = jsonDecode(cleaned);

      return TrendReport(
        inDemandSkills: (json['in_demand_skills'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        recommendedPhases: (json['recommended_phases'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        recentTrends: (json['recent_trends'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        narrative: json['narrative'] as String? ?? '',
      );
    } catch (_) {
      // If parsing fails, return narrative-only report
      return TrendReport(
        inDemandSkills: [],
        recommendedPhases: [],
        recentTrends: [],
        narrative: '$roadmap\n\n$trends',
      );
    }
  }
}
