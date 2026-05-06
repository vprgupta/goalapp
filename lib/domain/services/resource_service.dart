import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'base_llm_service.dart';
import 'web_search_service.dart';
import 'youtube_tutorial_service.dart';
import 'llm_config.dart';
import 'resource_registry.dart';
import 'mcq_verifier_service.dart';

/// Resource Finder Agent — curates top 5 resources spread across all tab types.
/// Uses YouTube API and Tavily concurrently to get real, verified results.
class ResourceService {
  final BaseLlmService _llmService = BaseLlmService();
  final WebSearchService _searchService = WebSearchService();
  final YouTubeTutorialService _youtubeService = YouTubeTutorialService();
  late final McqVerifierService _mcqVerifier = McqVerifierService(_llmService);

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
      
      final results = await Future.wait([
        _searchService.searchMultiple(queries),
        _youtubeService.searchTutorials(query: '$topicName $goalName $level'),
      ]);

      final searchResults = results[0] as Map<String, List<Map<String, dynamic>>>;
      final ytResults = results[1] as List<YouTubeVideo>;

      final totalWeb = searchResults.values.fold(0, (sum, r) => sum + r.length);
      if (totalWeb == 0 && ytResults.isEmpty) {
        return _fetchWithExpertCurator(topicName: topicName, goalName: goalName, level: level);
      }
      
      final summary = _formatSearchResultsForLlm(searchResults, ytResults);
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

  // ── Bulk Pre-Computation (Learning Hub overhaul) ──────────────────────────

  /// Generates resources for an entire list of topics using a DETERMINISTIC URL engine.
  /// - ZERO API quota required for resource links
  /// - Uses YouTube Search, Google, DevDocs, interactive platforms via search URLs
  /// - LLM is only used for practice questions and mastery synopsis
  Future<Map<String, List<String>>> bulkGenerateResources({
    required String goalName,
    required String pillarName,
    required String level,
    required List<Map<String, dynamic>> topicsJson,
    void Function(String)? onProgress,
  }) async {
    try {
      onProgress?.call('\n\n--- PRE-COMPUTING LEARNING HUB ---\nBuilding high-fidelity resource links for each topic...\n');

      final Map<String, List<Map<String, String>>> programmaticResources = {};

      final bool hasYtApi = LlmConfig.youtubeApiKey.isNotEmpty &&
          !LlmConfig.youtubeApiKey.startsWith('YOUR_');

      if (hasYtApi) {
        onProgress?.call('🎬 Fetching real YouTube videos concurrently for ${topicsJson.length} topics...\n');
        // Concurrent YouTube API calls — one per topic
        final futures = topicsJson.map((topic) async {
          final String topicId = topic['id']?.toString() ?? '';
          final String topicConcept = topic['concept']?.toString() ?? '';
          if (topicId.isEmpty || topicConcept.isEmpty) return;

          // Get registry resources as base (docs, practice, cheatsheet, deep-dive)
          final base = ResourceRegistry.buildResources(
            topicConcept: topicConcept,
            pillarName: pillarName,
            goalName: goalName,
            level: level,
          );

          // Fetch a real YouTube video and replace the generic search URL slot
          final ytVideos = await _youtubeService.searchTutorials(
            query: '$topicConcept $pillarName',
            goalName: goalName,
            pillarName: pillarName,
          );

          final List<Map<String, String>> resources = List.from(base);
          if (ytVideos.isNotEmpty) {
            // Replace the registry's YouTube search URL with actual video data
            final idx = resources.indexWhere((r) => r['type'] == 'video');
            if (idx != -1) resources[idx] = ytVideos.first.toResourceMap();

            // Add a 2nd video as an alternative if available
            if (ytVideos.length > 1) {
              final alt = ytVideos[1].toResourceMap();
              resources.insert(idx + 1, {...alt, 'rank': '2', 'quality_note': '📺 Alternative'});
            }
          }
          programmaticResources[topicId] = resources;
        });

        await Future.wait(futures);
        onProgress?.call('✓ Real YouTube videos mapped for ${programmaticResources.length} topics.\n');

      } else {
        // No YouTube API key — use registry URLs (always-working search URLs)
        onProgress?.call('ℹ️ No YouTube API key — using direct search links.\n');
        for (final topic in topicsJson) {
          final String topicId = topic['id']?.toString() ?? '';
          final String topicConcept = topic['concept']?.toString() ?? '';
          if (topicId.isEmpty || topicConcept.isEmpty) continue;
          programmaticResources[topicId] = ResourceRegistry.buildResources(
            topicConcept: topicConcept,
            pillarName: pillarName,
            goalName: goalName,
            level: level,
          );
        }
      }

      onProgress?.call('⚙️ Generating practice sets with AI...\n');


      // LLM is ONLY used for practice MCQs and mastery synopsis — NOT for URLs
      final topicsDump = jsonEncode(topicsJson.map((t) => {'id': t['id'], 'concept': t['concept']}).toList());
      final prompt = '''
You are a Senior Curriculum Architect. Generate 4-tier practice exercises for each topic.

GOAL: $goalName | MILESTONE: $pillarName | LEVEL: $level

TOPICS:
$topicsDump

For EACH topic ID, return:
- "practice": Array of EXACTLY 4 questions — one per tier:
  1. EASY (type: "mcq", tier: "easy") — direct recall, basic definition
  2. MEDIUM (type: "mcq", tier: "medium") — code reading or "what's the output?"
  3. HARD (type: "mcq", tier: "hard") — edge case, tricky gotcha, common mistake
  4. BRAINSTORM (type: "theory", tier: "brainstorm") — open-ended design/trade-off question
- "mastery": Object with synopsis, pitfalls, revision_sheet

JSON SCHEMA:
{
  "topic_id_here": {
    "practice": [
      {
        "type": "mcq",
        "tier": "easy",
        "question": "Which keyword declares a constant in Dart?",
        "options": ["A. var", "B. final", "C. const", "D. let"],
        "correct_index": 2,
        "explanation": "const declares compile-time constants. final is runtime-immutable."
      },
      {
        "type": "mcq",
        "tier": "medium",
        "question": "What does this code print? ...",
        "options": ["A. ...", "B. ...", "C. ...", "D. ..."],
        "correct_index": 1,
        "explanation": "..."
      },
      {
        "type": "mcq",
        "tier": "hard",
        "question": "Tricky edge case question",
        "options": ["A. ...", "B. ...", "C. ...", "D. ..."],
        "correct_index": 3,
        "explanation": "..."
      },
      {
        "type": "theory",
        "tier": "brainstorm",
        "question": "Design question or trade-off analysis",
        "explanation": "Key talking points and ideal answer structure"
      }
    ],
    "mastery": {
      "synopsis": "Two-sentence intuition-building explanation.",
      "pitfalls": ["Common Trap 1", "Common Trap 2", "Common Trap 3"],
      "revision_sheet": "5-point senior-level cheat-sheet summary."
    }
  }
}

CRITICAL: Every correct_index MUST be accurate. Double-check each answer before returning.
Return ONLY valid JSON. No markdown. No explanation outside JSON.
''';

      Map<String, dynamic> decoded = {};
      try {
        final raw = await _llmService.generateText(prompt);
        String cleanedText = raw.trim();
        final start = cleanedText.indexOf('{');
        final end = cleanedText.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          cleanedText = cleanedText.substring(start, end + 1);
        }
        decoded = jsonDecode(cleanedText);

        // ── MCQ Verifier Pass ────────────────────────────────────────────────
        onProgress?.call('🔍 Verifying MCQ accuracy...\n');
        for (final topicEntry in topicsJson) {
          final String topicId = topicEntry['id']?.toString() ?? '';
          final String topicConcept = topicEntry['concept']?.toString() ?? '';
          if (topicId.isEmpty) continue;
          final rawPractice = decoded[topicId]?['practice'];
          if (rawPractice is List && rawPractice.isNotEmpty) {
            final rawList = rawPractice.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            final verified = await _mcqVerifier.verifyAndFix(rawList, topicConcept: topicConcept);
            decoded[topicId]['practice'] = verified;
          }
        }
        onProgress?.call('✅ MCQ accuracy verified.\n');
      } catch (e) {
        debugPrint('[ResourceService] Practice/mastery LLM generation failed: $e');
        onProgress?.call('[WARN] AI practice sets unavailable, but all resource links are ready.\n');
      }

      final Map<String, List<String>> finalMap = {};

      for (final topic in topicsJson) {
        final String topicId = topic['id']?.toString() ?? '';
        final dynamic llmData = decoded[topicId] ?? {};
        final List<Map<String, String>> baseResources = programmaticResources[topicId] ?? [];

        final List<Map<String, String>> allResources = List.from(baseResources);

        // Append practice set from LLM if available
        if (llmData is Map && llmData['practice'] != null && (llmData['practice'] as List).isNotEmpty) {
          allResources.add({
            'type': 'practice_set',
            'title': 'Practice Questions',
            'url': '',
            'description': jsonEncode(llmData['practice']),
            'source': 'Curriculum AI',
            'quality_note': '',
            'rank': '6',
          });
        }

        // Append mastery hub from LLM if available
        if (llmData is Map && llmData['mastery'] != null && (llmData['mastery'] as Map).isNotEmpty) {
          allResources.add({
            'type': 'mastery_hub',
            'title': 'Mastery Snapshot',
            'url': '',
            'description': jsonEncode(llmData['mastery']),
            'source': 'Curriculum AI',
            'quality_note': '',
            'rank': '7',
          });
        }

        finalMap[topicId] = allResources.map((e) => jsonEncode(e)).toList();
      }

      onProgress?.call('✓ Learning Hub ready! ${finalMap.length} topics mapped.\n');
      return finalMap;

    } catch (e) {
      debugPrint('[ResourceService] Bulk generation fatal error: $e');
      onProgress?.call('[WARN] Bulk pipeline failed — using registry fallback for all topics.\n');
      // ── GUARANTEED FALLBACK ──────────────────────────────────────────────────
      // Even if the entire pipeline crashes, return deterministic registry
      // resources for every topic so all tabs are always populated.
      final Map<String, List<String>> fallback = {};
      for (final topic in topicsJson) {
        final String topicId = topic['id']?.toString() ?? '';
        final String topicConcept = topic['concept']?.toString() ?? '';
        if (topicId.isEmpty || topicConcept.isEmpty) continue;
        final base = ResourceRegistry.buildResources(
          topicConcept: topicConcept,
          pillarName: pillarName,
          goalName: goalName,
          level: level,
        );
        fallback[topicId] = base.map((r) => jsonEncode(r)).toList();
      }
      onProgress?.call('✓ Registry fallback applied for ${fallback.length} topics.\n');
      return fallback;
    }
  }

  /// Deterministic resource builder — delegates to the domain-aware ResourceRegistry.
  /// Covers 20+ tech domains with direct links to the world's best learning platforms.
  List<Map<String, String>> _buildDeterministicResources({
    required String topicConcept,
    required String pillarName,
    required String goalName,
    required String level,
  }) {
    return ResourceRegistry.buildResources(
      topicConcept: topicConcept,
      pillarName: pillarName,
      goalName: goalName,
      level: level,
    );
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
  rank 1 → type: "video"       — YouTube tutorial search
  rank 2 → type: "article"     — DuckDuckGo search for official docs
  rank 3 → type: "interactive" — DuckDuckGo search for practice platforms
  rank 4 → type: "visual"      — DuckDuckGo search for cheatsheets
  rank 5 → type: "article"     — DuckDuckGo search for advanced guides

URL RULES — READ CAREFULLY (CRITICAL FOR PREVENTING 404 ERRORS):
  ✅ video type: ALWAYS use YouTube search: https://www.youtube.com/results?search_query=TOPIC+tutorial
     Example for "$topicName": $ytUrl
  ✅ article type: NEVER guess the direct URL. ALWAYS use a DuckDuckGo search targeting official docs.
     Format: https://duckduckgo.com/?q=[URL-encoded Topic]+docs+mdn+OR+official
     Example: https://duckduckgo.com/?q=React+useState+hook+docs+official
  ✅ interactive type: NEVER guess the direct URL. Use search.
     Format: https://duckduckgo.com/?q=[URL-encoded Topic]+interactive+tutorial+freecodecamp
  ✅ visual type: NEVER guess the direct URL. Use search.
     Format: https://duckduckgo.com/?q=[URL-encoded Topic]+cheatsheet+pdf+roadmap.sh
  ❌ NEVER invent or guess a domain path (e.g. do not write freecodecamp.org/learn/x). It will 404.

Return ONLY this JSON (no markdown fences, no extra text):
{
  "resources": [
    {
      "type": "video",
      "title": "$topicName — Best YouTube Tutorials",
      "url": "$ytUrl",
      "description": "Curated search across top YouTube creators for $topicName.",
      "source": "YouTube",
      "quality_note": "🔥 Top video results",
      "rank": "1"
    },
    {
      "type": "article",
      "title": "Official Documentation / Best Guide for $topicName",
      "url": "https://duckduckgo.com/?q=... (encoded safe search URL)",
      "description": "FILL IN: why official docs are critical for this topic",
      "source": "Official Docs / Web Search",
      "quality_note": "📖 Verified Search",
      "rank": "2"
    },
    {
      "type": "interactive",
      "title": "Interactive Practice for $topicName",
      "url": "https://duckduckgo.com/?q=... (encoded safe search URL)",
      "description": "FILL IN: why hands-on practice here works best",
      "source": "Interactive Search",
      "quality_note": "🛠️ Hands-on",
      "rank": "3"
    },
    {
      "type": "visual",
      "title": "Visual Cheatsheet for $topicName",
      "url": "https://duckduckgo.com/?q=... (encoded safe search URL)",
      "description": "FILL IN: why a cheatsheet helps memory retention",
      "source": "Cheatsheet Search",
      "quality_note": "🗺️ Visual Reference",
      "rank": "4"
    },
    {
      "type": "visual",
      "title": "$topicName — Quick Reference Cheatsheet",
      "url": "https://duckduckgo.com/?q=${Uri.encodeComponent('$topicName cheatsheet reference card site:devhints.io OR site:quickref.me OR site:roadmap.sh')}",
      "description": "Visual cheatsheet and quick-reference card for $topicName to aid memory retention.",
      "source": "Cheatsheet Search",
      "quality_note": "🗺️ Visual Reference",
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
    return '''
You are a Senior Developer. Select the best resources from real search results below.
One resource per type: video, article, interactive, visual, article.

TOPIC: $topicName | GOAL: $goalName | LEVEL: $level

REAL SEARCH RESULTS (YouTube & Web):
$searchSummary

RULES:
- For "video" type, you MUST select the exact 'URL' of the best video from the YOUTUBE VIDEO RESULTS section (e.g. watch?v=...).
- For all other types, select the most relevant 'URL' from the TAVILY results.
- Assign one resource to each type: video / article / interactive / visual / article
- Rank 1 = best overall resource

Return ONLY this JSON (no markdown):
{
  "resources": [
    {
      "type": "video",
      "title": "exact title from YouTube results",
      "url": "exact watch?v= URL from YouTube results",
      "description": "why this specific video tutorial is excellent",
      "source": "Channel Name",
      "quality_note": "🔥 Top viewed tutorial",
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

  String _formatSearchResultsForLlm(Map<String, List<Map<String, dynamic>>> webResults, List<YouTubeVideo> ytResults) {
    final buffer = StringBuffer();
    
    if (ytResults.isNotEmpty) {
      buffer.writeln('=== YOUTUBE VIDEO RESULTS ===');
      for (var i = 0; i < ytResults.length; i++) {
        final v = ytResults[i];
        buffer.writeln('Title: ${v.title}');
        buffer.writeln('URL: ${v.watchUrl}');
        buffer.writeln('Channel: ${v.channelTitle} | Views: ${v.viewCount} | Quality: ${v.qualityScore.toStringAsFixed(2)}');
        buffer.writeln('---');
      }
    }

    for (final entry in webResults.entries) {
      buffer.writeln('=== ${entry.key.toUpperCase()} (TAVILY) ===');
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
    try {
      String cleaned = raw.trim();
      // Strip markdown fences — try to isolate the JSON object
      if (cleaned.contains('```') || !cleaned.startsWith('{')) {
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

      // Post-process: filter out resources whose URL is a FILL IN placeholder
      final List<Map<String, String>> resources = sorted
          .where((r) {
            final url = r['url']?.toString() ?? '';
            return !url.contains('FILL IN') && !url.contains('FILL_IN');
          })
          .map((r) {
            return <String, String>{
              'type': r['type']?.toString() ?? 'article',
              'title': r['title']?.toString() ?? 'Learning Resource',
              'url': r['url']?.toString() ?? '',
              'description': r['description']?.toString() ?? '',
              'source': r['source']?.toString() ?? 'Web',
              'quality_note': r['quality_note']?.toString() ?? '',
              'rank': r['rank']?.toString() ?? '',
            };
          })
          .toList();

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
    } catch (e) {
      debugPrint('[ResourceService] _parseResourceResponse failed: $e');
      return []; // Caller handles empty gracefully
    }
  }
}
