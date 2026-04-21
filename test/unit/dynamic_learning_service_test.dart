import 'package:flutter_test/flutter_test.dart';
import 'package:goalapp/domain/services/dynamic_learning_service.dart';
import '../fakes/fake_llm_service.dart';

void main() {
  group('DynamicLearningService Unit Tests', () {
    late DynamicLearningService service;

    setUp(() {
      service = DynamicLearningService(llmService: FakeLlmService());
    });

    test('generateKnowledgeGraph parses LLM JSON back into list of maps safely', () async {
      final graph = await service.generateKnowledgeGraph(
        goal: 'Mock Goal',
        pillarName: 'Mock Pillar',
        level: 'Beginner',
        days: 5,
      );

      // Verify the JSON logic mapping from string out of the LLM to parsed maps.
      expect(graph, isA<List<Map<String, dynamic>>>());
      expect(graph.length, 2);
      expect(graph[0]['id'], 'intro');
      expect(graph[1]['id'], 'advanced');
      expect(graph[1]['prerequisites'], contains('intro'));
    });
  });
}
