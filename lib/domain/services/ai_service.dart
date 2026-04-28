import 'dart:convert';
import 'dart:isolate';
import 'base_llm_service.dart';
import 'trend_scout_service.dart';

class AiService {
  final BaseLlmService _llmService = BaseLlmService();
  final TrendScoutService _trendScout = TrendScoutService();

  AiService();

  // ────────────────────────────────────────────────────────────────────────────
  // ROADMAP PLANNING AGENT  (3-step: Analyst → Architect → Critic)
  // ────────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> generateSyllabus({
    required String goal,
    required String level,
    required int days,
    void Function(String)? onProgress,
  }) async {
    const maxRetries = 2;

    // ── AGENT 1: TREND SCOUT (web search) ────────────────────────────────────
    // Searches the internet for real-world roadmaps, job-market skills, and
    // ecosystem trends. Result is injected into the Architect for grounding.
    onProgress?.call('🌐 Agent 1/5 — Trend Scout: Searching real-world roadmaps...\n');
    final trendReport = await _trendScout.research(
      goal: goal,
      level: level,
      onProgress: onProgress,
    );

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // ── AGENT 2: STRATEGIC ANALYST ───────────────────────────────────────
        // Pure reasoning pass — uses trend data as context to produce a grounded
        // strategic brief before any JSON is generated.
        onProgress?.call('⚡ Agent 2/5 — Strategic Analysis\n');

        final analysisPrompt = '''
You are a Senior Learning Strategist. Produce a STRATEGIC BRIEF for a learner.

GOAL: $goal
LEARNER LEVEL: $level
TOTAL DAYS: $days

WEB RESEARCH CONTEXT (from internet search — use this to ground your analysis):
${trendReport.toArchitectBrief()}

Output a concise brief (plain text, no JSON) covering:
1. PREREQUISITES: What must the learner already know before starting?
2. PHASE SEQUENCE: The ideal 6-phase learning arc in order (themes, not titles).
   Use the community-recommended phases from research WHERE THEY MATCH the goal.
3. DIFFICULTY CURVE: Which phases are foundational vs advanced?
4. COMMON TRAPS: Top 3 mistakes learners make with "$goal".
5. SCOPE NOTE: What is realistically achievable in $days days at $level level?
6. TREND ALIGNMENT: Which in-demand skills from the research should be prioritised?

Be highly specific to "$goal". Incorporate real-world findings from the web research.
''';

        final analysis = await _llmService.generateText(analysisPrompt);

        // Determine ideal phase count from scope
        final int phaseCount = _computePhaseCount(goal: goal, days: days, trendReport: trendReport);
        onProgress?.call('✓ Analysis complete (targeting $phaseCount phases).\n\n⚡ Agent 3/5 — Roadmap Architect\n');

        // ── AGENT 4: ARCHITECT (streaming) ───────────────────────────────────
        // Takes analyst brief + trend research as grounding — output constrained
        // to master JSON template. Web research ensures real-world relevance.
        final architectPrompt = '''
You are a pure JSON data architect. You received this strategic brief AND web research:

--- STRATEGIC BRIEF ---
$analysis
--- END BRIEF ---

--- WEB RESEARCH (real roadmaps + trends) ---
${trendReport.toArchitectBrief()}
--- END RESEARCH ---

GOAL: $goal | LEVEL: $level | DAYS: $days | PHASE COUNT: $phaseCount

Generate EXACTLY $phaseCount phases for this goal. Do NOT generate more or fewer.

Phase count rationale:
- Simple/narrow goals (< 15 days): 4 phases
- Standard goals (15-30 days): 6 phases  
- Broad/complex goals (30-60 days): 8 phases
- Comprehensive goals (60+ days): 10-12 phases

Return a JSON object with exactly $phaseCount items:
{
  "topics": [
    { "chapter": "PHASE 1: [Theme Name]", "title": "[3-5 word specific title]", "duration_sec": 3600, "is_boss": true, "rank": "B" },
    { "chapter": "PHASE 2: [Theme Name]", "title": "[3-5 word specific title]", "duration_sec": 3600, "is_boss": true, "rank": "B" },
    ... (continue up to PHASE $phaseCount)
  ]
}

RULES:
- Each "chapter" MUST follow "PHASE N: Descriptive Theme" format (N = 1 to $phaseCount).
- Each "title" is the SPECIFIC concept/tool for "$goal" at that phase — NO generic labels.
- Phases 1-2: foundational (rank B, duration 2400-3600)
- Phases 3 to ${phaseCount - 2}: intermediate/advanced (rank A, duration 3600-5400)
- Last 2 phases: capstone/integration (rank S, duration 5400-7200)
- Prioritise skills from the web research that appear in job postings.
- Return ONLY the JSON. No markdown. No explanation.
''';

        final archBuffer = StringBuffer();
        await for (final chunk in _llmService.generateTextStream(architectPrompt)) {
          archBuffer.write(chunk);
          onProgress?.call(chunk);
        }

        onProgress?.call('\n\n⚡ Agent 5/5 — Critic Validation\n');

        // ── AGENT 5: CRITIC ──────────────────────────────────────────────────
        // Self-correcting pass — the model inspects its own output and patches
        // any ordering issues, generic titles, or missing fields before parse.
        final criticPrompt = '''
You are a Roadmap Quality Inspector. Review this roadmap JSON for goal "$goal" at "$level" level over $days days.
Expected phase count: $phaseCount.

ROADMAP TO REVIEW:
${archBuffer.toString()}

CHECKLIST — silently fix any issues, then return the corrected JSON:
1. Exactly $phaseCount phases present? If more/fewer, merge or add phases to reach $phaseCount.
2. Each chapter follows "PHASE N: Theme" format with sequential numbering?
3. Titles SPECIFIC to "$goal"? Reject generic labels like "Advanced Topics".
4. Phase ORDER logical — foundational before advanced?
5. Rank progression: first 2 = B, middle = A, last 2 = S?
6. duration_sec values realistic for $days days? (scale down if days < 10)
7. JSON valid and parseable?

Return ONLY the corrected JSON object. No explanation. No markdown.
''';

        final finalJson = await _llmService.generateText(criticPrompt);
        onProgress?.call('✓ Roadmap validated.\n');

        // ── PARSE ────────────────────────────────────────────────────────────
        return await _parseTopics(finalJson);

      } catch (e) {
        if (attempt >= maxRetries) {
          throw Exception('Roadmap Planning Agent failed after $maxRetries attempts: $e');
        }
        onProgress?.call('\n[Agent] Retrying — recalibrating...\n');
      }
    }
    throw Exception('Unknown error in Roadmap Planning Agent');
  }

  // ── Phase count calculator ────────────────────────────────────────────────
  // Computes the ideal number of roadmap phases (4–12) based on:
  //   1. Number of days available (more time → room for more phases)
  //   2. Goal complexity keywords (broad stacks need more phases)
  //   3. Number of in-demand skills found by Trend Scout (proxy for scope)
  int _computePhaseCount({
    required String goal,
    required int days,
    required dynamic trendReport,
  }) {
    // Base from duration
    int count;
    if (days < 15) {
      count = 4;
    } else if (days < 30) {
      count = 6;
    } else if (days < 60) {
      count = 8;
    } else {
      count = 10;
    }

    // Boost for complex/broad goals
    final lower = goal.toLowerCase();
    const broadKeywords = [
      'full stack', 'fullstack', 'devops', 'cloud', 'machine learning',
      'data science', 'backend', 'frontend', 'mobile', 'system design',
      'microservices', 'kubernetes', 'aws', 'azure', 'complete', 'comprehensive'
    ];
    if (broadKeywords.any((k) => lower.contains(k))) count += 2;

    // Boost if Trend Scout found many in-demand skills (= wide scope)
    final skillCount = (trendReport?.inDemandSkills as List?)?.length ?? 0;
    if (skillCount >= 6) count += 2;

    // Clamp to [4, 12]
    return count.clamp(4, 12);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PDF / TEXT EXTRACTION  (single-shot, unchanged)
  // ────────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> extractRoadmapFromText({
    required String extractedText,
    required int days,
    void Function(String)? onProgress,
  }) async {
    final systemPrompt = '''
You are a Senior Learning Architect. Analyze the provided raw syllabus or roadmap text and extract the MENTAL PILLARS for a professional-grade roadmap.

DOCUMENT TEXT:
$extractedText

DURATION: $days days.

Identify the 5–7 major "Phases", "Tools", or "Technologies" required to master this goal from scratch, derived from the text.

IMPORTANT: Return topics in CHRONOLOGICAL LEARNING ORDER (fundamentals first, advanced last).

JSON SCHEMA (Return ONLY this object):
{
  "topics": [
    {
      "title": "Master Tool/Technology Name",
      "duration_sec": 3600,
      "chapter": "PHASE X: Strategic Theme",
      "is_boss": true,
      "rank": "S|A|B|C"
    }
  ]
}

RULES:
- Each item MUST represent a major step, tool, or technology from the document.
- The "chapter" field must follow "PHASE X: Title" format.
- Do NOT include a "subtopics" field.
''';

    const maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final buffer = StringBuffer();
        await for (final chunk in _llmService.generateTextStream(systemPrompt)) {
          buffer.write(chunk);
          onProgress?.call(chunk);
        }
        return await _parseTopics(buffer.toString());
      } catch (e) {
        if (attempt >= maxRetries) {
          throw Exception('PDF Roadmap Extraction Failed after $maxRetries attempts: $e');
        }
        onProgress?.call('\n[System] Parsing anomaly detected. Re-evaluating document...\n');
      }
    }
    throw Exception('Unknown extraction error in AiService');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // SHARED PARSER  (extracted to avoid duplication)
  // ────────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _parseTopics(String raw) async {
    String cleaned = raw.trim();

    // Strip markdown fences if model added them
    if (cleaned.contains('```')) {
      final match = RegExp(r'(\{[\s\S]*\}|\[[\s\S]*\])').stringMatch(cleaned);
      if (match != null) cleaned = match;
    }

    // Offload CPU-bound JSON decode to isolate (keeps UI at 60fps)
    final dynamic decoded = await Isolate.run(() => jsonDecode(cleaned.trim()));

    List<dynamic> topics = [];
    if (decoded is Map<String, dynamic>) {
      topics = decoded['topics'] ?? [];
    } else if (decoded is List<dynamic>) {
      topics = decoded;
    }

    if (topics.isEmpty) {
      throw FormatException('No topics found in parsed JSON: $cleaned');
    }

    return topics.map((t) => {
          'title': t['title'] as String? ?? 'Learning Node',
          'duration_sec': (t['duration_sec'] as num?)?.toInt() ?? 3600,
          'subtopics': (t['subtopics'] as List<dynamic>?)
                  ?.map((s) => s.toString())
                  .toList() ??
              [],
          'chapter': t['chapter'] as String? ?? 'Exploration',
          'is_boss': t['is_boss'] as bool? ?? false,
          'rank': t['rank'] as String? ?? 'B',
        }).toList();
  }
}
