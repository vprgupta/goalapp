import 'dart:convert';
import 'dart:isolate';
import 'base_llm_service.dart';

class DynamicLearningService {
  final BaseLlmService _llmService;

  DynamicLearningService({BaseLlmService? llmService}) 
      : _llmService = llmService ?? BaseLlmService();

  /// Generates the overarching Directed Acyclic Graph (DAG) for a given topic.
  /// Phase 1 of the Multi-Call Adaptive Learning Engine.
  Future<List<Map<String, dynamic>>> generateKnowledgeGraph({
    required String goal,
    required String pillarName,
    required String level,
    required int days,
    int? dailyMinutes,
    void Function(String)? onProgress,
  }) async {
    final systemPrompt = """
You are an expert AI Blueprint Specialist. Your task is to generate an ULTRA-ATOMIC blueprint for a specific pillar of a larger goal.

TOTAL GOAL: $goal
STRATEGIC PILLAR: $pillarName
SKILL LEVEL: $level

Your objective is to break down '$pillarName' into 4-7 hyper-detailed 'Knowledge Nodes'.

ATOMIC RULES:
- Each node must focus on a specific technical tool or concept within $pillarName.
- FOR EACH NODE: You MUST list 6-10 atomic subtopics (commands, micro-concepts, verify steps).
- Example: If the node is 'File Permissions', subtopics must be: ['ls -l notation', 'chmod numeric vs symbolic', 'chown usage', 'sticky bits', 'umask defaults'].

JSON SCHEMA:
{
  "graph": [
    {
      "id": "slug",
      "concept": "Atomic Topic Title",
      "subtopics": ["Micro 1", "Micro 2", "Micro 3", "Micro 4", "Micro 5", "Micro 6", "Micro 7", "Micro 8"],
      "module_name": "$pillarName",
      "prerequisites": [],
      "weight": 1.0,
      "estimated_time_minutes": 45,
      "is_boss": false,
      "tier": "1|2|3"
    }
  ]
}
""";

    try {
      final buffer = StringBuffer();
      await for (final chunk in _llmService.generateTextStream(systemPrompt)) {
        buffer.write(chunk);
        if (onProgress != null) onProgress(chunk);
      }
      
      final text = buffer.toString();
      String cleanedText = text.trim();
      if (cleanedText.contains('```')) {
        final regex = RegExp(r'\{[\s\S]*\}');
        final match = regex.stringMatch(cleanedText);
        if (match != null) {
          cleanedText = match;
        }
      }
      
      // flutter-handling-concurrency skill: knowledge graph JSON can be large
      // (4-7 nodes * 8 subtopics each). Offload decoding to isolate.
      final Map<String, dynamic> decoded = await Isolate.run(
        () => jsonDecode(cleanedText.trim()) as Map<String, dynamic>,
      );
      final List<dynamic> graph = decoded['graph'] ?? [];
      
      if (graph.isEmpty) {
        throw Exception('No graph nodes found in extracted JSON: $cleanedText');
      }

      return graph.map((node) {
        final List<dynamic> subs = node['subtopics'] as List<dynamic>? ?? [];
        return {
          'id': node['id']?.toString() ?? '',
          'concept': node['concept']?.toString() ?? 'Learning Node',
          'subtopics': subs.map((e) => e.toString()).toList(),
          'module_name': node['module_name']?.toString() ?? 'Core Journey',
          'prerequisites': (node['prerequisites'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          'weight': (node['weight'] as num?)?.toDouble() ?? 0.5,
          'estimated_time_minutes': (node['estimated_time_minutes'] as num?)?.toInt() ?? 30,
          'is_boss': node['is_boss'] as bool? ?? false,
          'tier': int.tryParse(node['tier']?.toString() ?? '1') ?? 1,
        };
      }).toList();
      
    } catch (e) {
      throw Exception('Knowledge Graph Generation Failed: $e');
    }
  }
}
