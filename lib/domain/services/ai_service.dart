import 'dart:convert';
import 'dart:isolate';
import 'base_llm_service.dart';

class AiService {
  final BaseLlmService _llmService = BaseLlmService();

  AiService();

  Future<List<Map<String, dynamic>>> generateSyllabus({
    required String goal,
    required String level,
    required int days,
    void Function(String)? onProgress,
  }) async {
    final systemPrompt = """
You are a pure data parser. DO NOT generate your own structural headers.
Your task is to fill in the `title` field for the 6 highly rigid phases below.

GOAL: $goal
LEVEL: $level
DURATION: $days days.

MASTER JSON TEMPLATE:
{
  "topics": [
    { "chapter": "PHASE 1: Core Fundamentals & Primitives", "title": "[LLM INFILL]" },
    { "chapter": "PHASE 2: Ecosystem & Tooling Setup", "title": "[LLM INFILL]" },
    { "chapter": "PHASE 3: Intermediate Logic & Execution", "title": "[LLM INFILL]" },
    { "chapter": "PHASE 4: Architecture & Best Practices", "title": "[LLM INFILL]" },
    { "chapter": "PHASE 5: Advanced Optimization", "title": "[LLM INFILL]" },
    { "chapter": "PHASE 6: Capstone Integration", "title": "[LLM INFILL]" }
  ]
}

INSTRUCTIONS:
1. Return EXACTLY the JSON schema above.
2. Replace "[LLM INFILL]" with the specific technology, concept, or tool that fits the chapter for learning '$goal'. (e.g. if the goal is Python, PHASE 1 title might be "Syntax & Variables").
3. Retain the exact "chapter" strings.
4. Keep titles short and conceptual (3-5 words max).
5. Add "duration_sec": 3600, "is_boss": true, "rank": "A" to every object.
""";

    int maxRetries = 2;
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        final buffer = StringBuffer();
        await for (final chunk in _llmService.generateTextStream(systemPrompt)) {
          buffer.write(chunk);
          if (onProgress != null) onProgress(chunk);
        }
        final text = buffer.toString();
        String cleanedText = text.trim();
        
        // Robust extraction
        if (cleanedText.contains('```')) {
          final regex = RegExp(r'(\{[\s\S]*\}|\[[\s\S]*\])'); // Match object or raw array
          final match = regex.stringMatch(cleanedText);
          if (match != null) cleanedText = match;
        }
        
        // flutter-handling-concurrency skill: jsonDecode is CPU-bound.
        // Offload to a background isolate via Isolate.run() so the main
        // isolate (UI thread) stays at 60fps during large JSON parsing.
        final dynamic decoded = await Isolate.run(
          () => jsonDecode(cleanedText.trim()),
        );
        List<dynamic> topics = [];
        
        if (decoded is Map<String, dynamic>) {
          topics = decoded['topics'] ?? [];
        } else if (decoded is List<dynamic>) {
          topics = decoded; // Fallback if AI skips the wrapper
        }
        
        if (topics.isEmpty) {
          throw FormatException('No topics found in extracted JSON: $cleanedText');
        }

        return topics.map((t) => {
          'title': t['title'] as String? ?? 'Learning Node',
          'duration_sec': (t['duration_sec'] as num?)?.toInt() ?? 3600,
          'subtopics': (t['subtopics'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [],
          'chapter': t['chapter'] as String? ?? 'Exploration',
          'is_boss': t['is_boss'] as bool? ?? false,
          'rank': t['rank'] as String? ?? 'B',
        }).toList();
        
      } catch (e) {
        if (attempts >= maxRetries) {
          throw Exception('Roadmap Generation Failed after $maxRetries attempts: $e');
        }
        // If it fails, loop continues and generates again.
        if (onProgress != null) {
          onProgress("\n[System] Connection stutter detected. Recalibrating Matrix...\n");
        }
      }
    }
    throw Exception('Unknown generation error in AiService');
  }

  Future<List<Map<String, dynamic>>> extractRoadmapFromText({
    required String extractedText,
    required int days,
    void Function(String)? onProgress,
  }) async {
    final systemPrompt = """
You are a Senior Learning Architect. Your goal is to analyze the provided raw syllabus or roadmap text and extract the MENTAL PILLARS for a professional-grade roadmap.

DOCUMENT TEXT:
$extractedText

DURATION: $days days.

Analyze the above text and identify the 5-7 major "Phases", "Tools", or "Technologies" required to master this goal from scratch, as derived from the text. 

IMPORTANT: Return the topics in CHRONOLOGICAL LEARNING ORDER (e.g. Fundamental concepts first, followed by advanced implementations).

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

BEHAVIOR:
- Each item MUST represent a major "Step", "Tool", or "Technology" mentioned in the document.
- The 'chapter' should follow the format 'PHASE X: Title'.
- Do NOT include a "subtopics" field in the JSON. The atomic planner will handle that in Phase 2.
""";

    int maxRetries = 2;
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        final buffer = StringBuffer();
        await for (final chunk in _llmService.generateTextStream(systemPrompt)) {
          buffer.write(chunk);
          if (onProgress != null) onProgress(chunk);
        }
        final text = buffer.toString();
        String cleanedText = text.trim();
        
        // Robust extraction
        if (cleanedText.contains('```')) {
          final regex = RegExp(r'(\{[\s\S]*\}|\[[\s\S]*\])'); // Match object or raw array
          final match = regex.stringMatch(cleanedText);
          if (match != null) cleanedText = match;
        }
        
        // flutter-handling-concurrency skill: offload JSON decoding
        final dynamic decoded = await Isolate.run(
          () => jsonDecode(cleanedText.trim()),
        );
        List<dynamic> topics = [];
        
        if (decoded is Map<String, dynamic>) {
          topics = decoded['topics'] ?? [];
        } else if (decoded is List<dynamic>) {
          topics = decoded; // Fallback if AI skips the wrapper
        }
        
        if (topics.isEmpty) {
          throw FormatException('No topics found in extracted JSON: $cleanedText');
        }

        return topics.map((t) => {
          'title': t['title'] as String? ?? 'Learning Node',
          'duration_sec': (t['duration_sec'] as num?)?.toInt() ?? 3600,
          'subtopics': (t['subtopics'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [],
          'chapter': t['chapter'] as String? ?? 'Exploration',
          'is_boss': t['is_boss'] as bool? ?? false,
          'rank': t['rank'] as String? ?? 'B',
        }).toList();
        
      } catch (e) {
        if (attempts >= maxRetries) {
          throw Exception('PDF Roadmap Extraction Failed after $maxRetries attempts: $e');
        }
        if (onProgress != null) {
          onProgress("\n[System] Parsing anomaly detected. Re-evaluating document...\n");
        }
      }
    }
    throw Exception('Unknown extraction error in AiService');
  }
}
