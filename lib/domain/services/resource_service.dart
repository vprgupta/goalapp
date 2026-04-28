import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'base_llm_service.dart';
import 'web_search_service.dart';
import 'llm_config.dart';

/// Resource Finder Agent — curates top 5 resources spread across all tab types.
/// Uses YouTube SEARCH URLs (never watch?v= which hallucinate/go offline).
class ResourceService {
  final BaseLlmService _llmService = BaseLlmService();
  final WebSearchService _searchService = WebSearchService();

  Future<List<Map<String, String>>> fetchResources({
    required String topicName,
    required String goalName,
    required String level,
  }) async {
    if (LlmConfig.tavilyApiKey.isNotEmpty) {
      return _fetchWithAgent(topicName: topicName, goalName: goalName, level: level);
    }
    return _fetchWithExpertCurator(topicName: topicName, goalName: goalName, level: level);
  }

  // ── Agent path (Tavily) ────────────────────────────────────────────────────

  Future<List<Map<String, String>>> _fetchWithAgent({
    required String topicName,
    required String goalName,
    required String level,
  }) async {
    try {
      final plannerRaw = await _llmService.generateText(_plannerPrompt(topicName, goalName, level));
      final queries = _parseSearchQueries(plannerRaw);
      final searchResults = await _searchService.searchMultiple(queries);
      final total = searchResults.values.fold(0, (sum, r) => sum + r.length);
      if (total == 0) {
        return _fetchWithExpertCurator(topicName: topicName, goalName: goalName, level: level);
      }
      final summary = _formatSearchResultsForLlm(searchResults);
      final raw = await _llmService.generateText(_agentCuratorPrompt(topicName, goalName, level, summary));
      return _parseResourceResponse(raw);
    } catch (e) {
      debugPrint('[ResourceAgent] Agent failed: $e');
      return _fetchWithExpertCurator(topicName: topicName, goalName: goalName, level: level);
    }
  }

  // ── Expert curator path (LLM only) ────────────────────────────────────────

  Future<List<Map<String, String>>> _fetchWithExpertCurator({
    required String topicName,
    required String goalName,
    required String level,
  }) async {
    try {
      final text = await _llmService.generateText(_expertCuratorPrompt(topicName, goalName, level));
      return _parseResourceResponse(text);
    } catch (e) {
      debugPrint('[ResourceService] Expert curator failed: $e');
      return [];
    }
  }

  // ── Prompts ────────────────────────────────────────────────────────────────

  String _expertCuratorPrompt(String topicName, String goalName, String level) {
    // Build a proper YouTube search URL for the topic
    final ytQuery = Uri.encodeComponent('$topicName tutorial $level site:youtube.com OR fireship OR freecodecamp OR traversy');
    final ytUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$topicName tutorial $level')}';

    return '''
You are a Senior Developer curating the BEST learning resources for a specific topic.
Return exactly 5 resources — one per type — so every learning tab has content.

TOPIC: $topicName
GOAL: $goalName
LEVEL: $level

STRICT TYPE ASSIGNMENT (return exactly one resource per type in this order):
  rank 1 → type: "video"       — YouTube tutorial search (see URL rule below)
  rank 2 → type: "article"     — Official docs or best written guide
  rank 3 → type: "interactive" — Hands-on practice platform
  rank 4 → type: "visual"      — Cheatsheet or visual reference
  rank 5 → type: "article"     — Deep-dive blog or advanced guide

URL RULES — READ CAREFULLY:
  ✅ video type:   ALWAYS use YouTube search: https://www.youtube.com/results?search_query=TOPIC+tutorial
     Example for "$topicName": $ytUrl
  ✅ article:      Use real stable docs (MDN, official docs, freeCodeCamp articles, dev.to)
  ✅ interactive:  Use platform root or course page (freecodecamp.org, exercism.org, theodinproject.com)
  ✅ visual:       Use roadmap.sh, devhints.io, quickref.me, or a real cheatsheet page
  ❌ NEVER use youtube.com/watch?v= — video IDs go offline and cannot be verified
  ❌ If you are unsure of an exact article URL, use: https://duckduckgo.com/?q=$topicName+topic_type+site:mdn.dev OR site:freecodecamp.org

HIGH-AUTHORITY SOURCES:
  Video searches: include "fireship" OR "freecodecamp" OR "traversy media" OR "academind" in the query
  Docs: MDN Web Docs, official language docs, DevDocs.io
  Practice: freecodecamp.org, exercism.org, theodinproject.com, leetcode.com
  Visual: roadmap.sh, devhints.io, quickref.me

Return ONLY this JSON (no markdown fences, no extra text):
{
  "resources": [
    {
      "type": "video",
      "title": "$topicName — Best YouTube Tutorials",
      "url": "$ytUrl",
      "description": "Curated search across freeCodeCamp, Fireship, and Traversy Media — the most-watched $topicName tutorials from creators with millions of subscribers.",
      "source": "YouTube",
      "quality_note": "🔥 Millions of views | Top creators",
      "rank": "1"
    },
    {
      "type": "article",
      "title": "FILL IN: actual docs/guide title for $topicName",
      "url": "FILL IN: real stable URL (MDN, official docs, or freeCodeCamp article)",
      "description": "FILL IN: why this is the authoritative written source",
      "source": "FILL IN: MDN / official site / freeCodeCamp",
      "quality_note": "📖 Official docs | Always current",
      "rank": "2"
    },
    {
      "type": "interactive",
      "title": "FILL IN: practice platform for $topicName",
      "url": "FILL IN: real platform URL",
      "description": "FILL IN: why hands-on practice here works best",
      "source": "FILL IN: freeCodeCamp / Exercism / The Odin Project",
      "quality_note": "🛠️ Hands-on | Project-based",
      "rank": "3"
    },
    {
      "type": "visual",
      "title": "FILL IN: cheatsheet or roadmap for $topicName",
      "url": "FILL IN: roadmap.sh or devhints.io or quickref.me URL",
      "description": "FILL IN: why this visual reference accelerates retention",
      "source": "FILL IN: roadmap.sh / devhints.io",
      "quality_note": "🗺️ One-page mastery | Bookmark worthy",
      "rank": "4"
    },
    {
      "type": "article",
      "title": "FILL IN: deep-dive or advanced guide for $topicName",
      "url": "FILL IN: real article URL",
      "description": "FILL IN: what makes this a must-read for serious learners",
      "source": "FILL IN: dev.to / CSS-Tricks / Smashing Magazine / official blog",
      "quality_note": "⭐ Community favourite | Expert-written",
      "rank": "5"
    }
  ],
  "practice": [
    {
      "type": "mcq",
      "question": "FILL IN: insight-testing MCQ about $topicName",
      "options": ["A. FILL", "B. FILL", "C. FILL", "D. FILL"],
      "correct_index": 0,
      "starter_code": "",
      "solution": "FILL IN: correct answer with reasoning",
      "explanation": "FILL IN: the mental model that makes this clear"
    },
    {
      "type": "theory",
      "question": "FILL IN: open-ended question testing deep understanding of $topicName",
      "options": [],
      "correct_index": -1,
      "starter_code": "",
      "solution": "FILL IN: expert explanation",
      "explanation": "FILL IN: what separates a junior from a senior understanding here"
    },
    {
      "type": "mcq",
      "question": "FILL IN: common gotcha or trap question about $topicName",
      "options": ["A. FILL", "B. FILL", "C. FILL", "D. FILL"],
      "correct_index": 2,
      "starter_code": "",
      "solution": "FILL IN: the non-obvious correct answer",
      "explanation": "FILL IN: the trap most beginners fall into"
    }
  ],
  "mastery": {
    "synopsis": "FILL IN: two-sentence intuition about $topicName that makes it click instantly.",
    "pitfalls": [
      "FILL IN: most common beginner mistake with $topicName",
      "FILL IN: intermediate trap that slows progress",
      "FILL IN: mental model error that causes confusion"
    ],
    "revision_sheet": "FILL IN: 5-point senior-level summary of $topicName — key APIs, patterns, gotchas, mental models."
  }
}

Replace every FILL IN with real, specific content for "$topicName". Keep the video URL exactly as shown — do not change it.
''';
  }

  String _agentCuratorPrompt(String topicName, String goalName, String level, String searchSummary) {
    final ytUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$topicName tutorial $level')}';
    return '''
You are a Senior Developer. Select the best resources from real search results below.
One resource per type: video, article, interactive, visual, article.

TOPIC: $topicName | GOAL: $goalName | LEVEL: $level

REAL SEARCH RESULTS:
$searchSummary

RULES:
- For "video" type, use the YouTube search URL: $ytUrl (NOT watch?v= URLs)
- Only use URLs that appear in the search results for non-video types
- Assign one resource to each type: video / article / interactive / visual / article
- Rank 1 = best overall resource

Return ONLY this JSON (no markdown):
{
  "resources": [
    {
      "type": "video",
      "title": "$topicName Tutorials — Top YouTube Search",
      "url": "$ytUrl",
      "description": "Direct search for the best $topicName tutorials from top creators",
      "source": "YouTube",
      "quality_note": "🔥 Curated search | Top creators",
      "rank": "1"
    },
    {
      "type": "article",
      "title": "title from search results",
      "url": "URL from search results",
      "description": "why this is the best written source",
      "source": "source from results",
      "quality_note": "📖 Best article",
      "rank": "2"
    },
    {
      "type": "interactive",
      "title": "title from search results",
      "url": "URL from search results",
      "description": "why hands-on here",
      "source": "source from results",
      "quality_note": "🛠️ Hands-on",
      "rank": "3"
    },
    {
      "type": "visual",
      "title": "title from search results",
      "url": "URL from search results",
      "description": "why this visual reference",
      "source": "source from results",
      "quality_note": "🗺️ Visual reference",
      "rank": "4"
    },
    {
      "type": "article",
      "title": "second best article from results",
      "url": "URL from results",
      "description": "why this is worth reading",
      "source": "source from results",
      "quality_note": "⭐ Deep dive",
      "rank": "5"
    }
  ],
  "practice": [
    {
      "type": "mcq",
      "question": "specific MCQ about $topicName",
      "options": ["A. ...", "B. ...", "C. ...", "D. ..."],
      "correct_index": 0,
      "starter_code": "",
      "solution": "...",
      "explanation": "..."
    },
    {
      "type": "theory",
      "question": "open-ended question about $topicName",
      "options": [],
      "correct_index": -1,
      "starter_code": "",
      "solution": "...",
      "explanation": "..."
    }
  ],
  "mastery": {
    "synopsis": "Two-sentence intuition for $topicName.",
    "pitfalls": ["Trap 1", "Trap 2", "Trap 3"],
    "revision_sheet": "Senior-level summary of $topicName."
  }
}
''';
  }

  String _plannerPrompt(String topicName, String goalName, String level) => '''
Generate search queries for learning resources.
TOPIC: $topicName | GOAL: $goalName | LEVEL: $level

Return ONLY this JSON:
{
  "article": "best $topicName documentation OR guide for $level",
  "interactive": "$topicName practice exercises OR playground",
  "visual": "$topicName cheatsheet OR reference card OR roadmap"
}
''';

  // ── Parsers ────────────────────────────────────────────────────────────────

  Map<String, String> _parseSearchQueries(String raw) {
    try {
      String cleaned = raw.trim();
      if (cleaned.contains('```')) {
        final match = RegExp(r'\{[\s\S]*\}').stringMatch(cleaned);
        if (match != null) cleaned = match;
      }
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint('[ResourceAgent] Failed to parse search queries: $e');
      return {};
    }
  }

  String _formatSearchResultsForLlm(Map<String, List<Map<String, dynamic>>> results) {
    final buffer = StringBuffer();
    for (final entry in results.entries) {
      buffer.writeln('=== ${entry.key.toUpperCase()} ===');
      for (final r in entry.value) {
        buffer.writeln('Title: ${r['title']}');
        buffer.writeln('URL: ${r['url']}');
        buffer.writeln('Snippet: ${r['snippet']}');
        buffer.writeln('---');
      }
    }
    return buffer.toString();
  }

  List<Map<String, String>> _parseResourceResponse(String raw) {
    String cleaned = raw.trim();
    // Strip markdown fences
    if (cleaned.contains('```')) {
      final match = RegExp(r'\{[\s\S]*\}').stringMatch(cleaned);
      if (match != null) cleaned = match;
    }

    final Map<String, dynamic> decoded = jsonDecode(cleaned.trim());
    final List<dynamic> rawResources = decoded['resources'] ?? [];
    final List<dynamic> rawPractice = decoded['practice'] ?? [];
    final Map<String, dynamic> rawMastery = decoded['mastery'] ?? {};

    // Sort by rank so best resource appears first
    final sorted = List<dynamic>.from(rawResources)
      ..sort((a, b) {
        final ra = int.tryParse(a['rank']?.toString() ?? '9') ?? 9;
        final rb = int.tryParse(b['rank']?.toString() ?? '9') ?? 9;
        return ra.compareTo(rb);
      });

    // Post-process: replace any watch?v= YouTube URLs with search URLs
    final List<Map<String, String>> resources = sorted.map((r) {
      String url = r['url']?.toString() ?? '';
      // Convert rogue watch?v= to search URL
      if (url.contains('youtube.com/watch?v=')) {
        final title = r['title']?.toString() ?? '';
        url = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(title)}';
      }
      return {
        'type': r['type']?.toString() ?? 'article',
        'title': r['title']?.toString() ?? 'Learning Resource',
        'url': url,
        'description': r['description']?.toString() ?? '',
        'source': r['source']?.toString() ?? 'Web',
        'quality_note': r['quality_note']?.toString() ?? '',
        'rank': r['rank']?.toString() ?? '',
      };
    }).toList();

    if (rawPractice.isNotEmpty) {
      resources.add({
        'type': 'practice_set',
        'title': 'Practice Questions',
        'url': '',
        'description': jsonEncode(rawPractice),
        'source': 'Expert Curator',
        'quality_note': '',
        'rank': '',
      });
    }

    if (rawMastery.isNotEmpty) {
      resources.add({
        'type': 'mastery_hub',
        'title': 'Mastery Snapshot',
        'url': '',
        'description': jsonEncode(rawMastery),
        'source': 'Expert Curator',
        'quality_note': '',
        'rank': '',
      });
    }

    return resources;
  }
}
