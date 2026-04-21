import 'package:goalapp/domain/services/base_llm_service.dart';

class FakeLlmService implements BaseLlmService {
  final String standardGraphJson = '''
  {
    "graph": [
      {
        "id": "intro",
        "concept": "Intro to Test",
        "subtopics": ["Micro 1", "Micro 2"],
        "module_name": "Testing",
        "prerequisites": [],
        "estimated_minutes": 15
      },
      {
        "id": "advanced",
        "concept": "Advanced Test",
        "subtopics": ["Micro 3", "Micro 4"],
        "module_name": "Testing",
        "prerequisites": ["intro"],
        "estimated_minutes": 25
      }
    ]
  }
  ''';

  @override
  Future<String> generateText(String prompt) async {
    // Return a dummy valid JSON for testing the dynamic learning system
    return standardGraphJson;
  }
  
  @override
  Stream<String> generateTextStream(String prompt) async* {
    yield standardGraphJson;
  }
}
