import 'package:goalapp/domain/services/base_llm_service.dart';

void main() async {
  final service = BaseLlmService();
  final prompt = '''
You are a pure data parser. DO NOT generate your own structural headers.
Your task is to fill in the `title` field for the 6 highly rigid phases below.

GOAL: Learn Python
LEVEL: Beginner
DURATION: 30 days.

MASTER JSON TEMPLATE:
{
  "topics": [
    { "chapter": "PHASE 1: Core Fundamentals & Primitives", "title": "[LLM INFILL]" },
    { "chapter": "PHASE 2: Ecosystem & Tooling Setup", "title": "[LLM INFILL]" }
  ]
}

INSTRUCTIONS:
1. Return EXACTLY the JSON schema above.
2. Replace "[LLM INFILL]" with the specific technology, concept, or tool that fits the chapter for learning 'Learn Python'. (e.g. if the goal is Python, PHASE 1 title might be "Syntax & Variables").
3. Retain the exact "chapter" strings.
4. Keep titles short and conceptual (3-5 words max).
5. Add "duration_sec": 3600, "is_boss": true, "rank": "A" to every object.
''';

  try {
    print('Testing prompt to Gemini...');
    final response = await service.generateText(prompt);
    print('SUCCESS! Response:');
    print(response);
  } catch (e) {
    print('FAILED!');
    print(e);
  }
}
