import 'dart:convert';
import 'dart:isolate';
import 'base_llm_service.dart';
import 'roadmap_template_registry.dart';
import '../engines/topic_order_validator.dart';

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
    // Inject domain-specific constraint for better accuracy
    final domainConstraint = RoadmapTemplateRegistry.getConstraint(
      goalName: goal,
      level: level,
    );

    final systemPrompt = """
You are an expert AI Blueprint Specialist. Generate an ULTRA-ATOMIC, ORDERED blueprint for a specific pillar.

TOTAL GOAL: $goal
STRATEGIC PILLAR: $pillarName
SKILL LEVEL: $level

$domainConstraint

Break down '$pillarName' into 4-7 Knowledge Nodes in STRICT LEARNING ORDER.

ORDERING RULES (critical):
- Node 1 must be learnable with zero prior knowledge of $pillarName.
- Each subsequent node may only reference IDs of nodes that come BEFORE it.
- A node's prerequisites list MUST contain the IDs of nodes it depends on.
- No circular dependencies. This is a Directed Acyclic Graph (DAG).

ATOMIC RULES:
- Each node: one specific technical tool or concept within $pillarName.
- Each node: 6-10 atomic subtopics (commands, micro-concepts, verify steps).
- Example for 'File Permissions': ['ls -l notation', 'chmod numeric vs symbolic', 'chown usage', 'sticky bits', 'umask defaults'].
- learning_order: sequential integer starting at 1 (defines the study order).
- tier: 1=foundational, 2=intermediate, 3=advanced.
- cognitive_load: 1-10 integer based on conceptual difficulty (1=syntax/memorization, 10=complex architecture/abstract).

JSON SCHEMA:
{
  "graph": [
    {
      "id": "slug_1",
      "concept": "Foundational Concept Title",
      "learning_order": 1,
      "subtopics": ["micro1", "micro2", "micro3", "micro4", "micro5", "micro6"],
      "module_name": "$pillarName",
      "prerequisites": [],
      "weight": 1.0,
      "estimated_time_minutes": 30,
      "cognitive_load": 3,
      "is_boss": false,
      "tier": 1
    },
    {
      "id": "slug_2",
      "concept": "Intermediate Concept Title",
      "learning_order": 2,
      "subtopics": ["micro1", "micro2", "micro3", "micro4", "micro5", "micro6"],
      "module_name": "$pillarName",
      "prerequisites": ["slug_1"],
      "weight": 1.0,
      "estimated_time_minutes": 45,
      "cognitive_load": 6,
      "is_boss": false,
      "tier": 2
    }
  ]
}

Return ONLY valid JSON. No markdown. No explanation.
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

      // Sort by learning_order so sub-topics are placed in dependency order
      graph.sort((a, b) {
        final aOrder = (a['learning_order'] as num?)?.toInt() ?? 99;
        final bOrder = (b['learning_order'] as num?)?.toInt() ?? 99;
        return aOrder.compareTo(bOrder);
      });

      final rawTopics = graph.map((node) {
        final List<dynamic> subs = node['subtopics'] as List<dynamic>? ?? [];
        return {
          'id': node['id']?.toString() ?? '',
          'concept': node['concept']?.toString() ?? 'Learning Node',
          'learning_order': (node['learning_order'] as num?)?.toInt() ?? 0,
          'subtopics': subs.map((e) => e.toString()).toList(),
          'module_name': node['module_name']?.toString() ?? 'Core Journey',
          'prerequisites': (node['prerequisites'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          'weight': (node['weight'] as num?)?.toDouble() ?? 0.5,
          'estimated_time_minutes': (node['estimated_time_minutes'] as num?)?.toInt() ?? 30,
          'cognitive_load': (node['cognitive_load'] as num?)?.toInt() ?? 5,
          'is_boss': node['is_boss'] as bool? ?? false,
          'tier': int.tryParse(node['tier']?.toString() ?? '1') ?? 1,
        };
      }).toList();

      // Validate and fix prerequisite ordering
      return TopicOrderValidator.validate(rawTopics);

      
    } catch (e) {
      throw Exception('Knowledge Graph Generation Failed: $e');
    }
  }
}
