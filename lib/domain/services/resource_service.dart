import 'dart:convert';
import 'package:http/http.dart' as http;

class ResourceService {
  static const String _apiKey = 'AIzaSyCGzFu9pa2NyRCC_Zi-pcTD8td98RGQduQ';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  Future<List<Map<String, String>>> fetchResources({
    required String topicName,
    required String goalName,
    required String level,
  }) async {
    final systemPrompt = """
You are an Expert Learning Librarian. Your task is to find the absolute BEST learning resources and create a 'Topper-Level' mastery dashboard for a specific topic.

TOPIC: $topicName
OVERALL GOAL: $goalName
LEARNER LEVEL: $level

BEHAVIOR:
1. CURATE: Find high-quality resources (video, article, visual, audio, interactive).
2. MASTER: Generate deep pedagogical insights that help a student master the topic like a topper.

JSON SCHEMA:
Return a JSON object with THREE keys: 'resources', 'practice', and 'mastery'.

{
  "resources": [
    {
      "type": "video|article|visual|audio|interactive",
      "title": "Clear title",
      "url": "Valid working URL",
      "description": "Short value proposition",
      "source": "YouTube|MDN|etc"
    }
  ],
  "practice": [
    {
      "type": "mcq|code|theory",
      "question": "...",
      "options": ["A", "B", "C", "D"], // for mcq
      "correct_index": 0, // for mcq
      "starter_code": "...", // for code
      "solution": "...", 
      "explanation": "..."
    }
  ],
  "mastery": {
    "synopsis": "A 2-sentence snapshot that builds instant intuition for the topic.",
    "pitfalls": ["Common trap 1", "Common trap 2", "Common trap 3"],
    "revision_sheet": "A concise, topper-level summary of key concepts, formulas, or principles."
  }
}

Focus on providing 'Topper IQ'—insights that go beyond just facts.
""";

    final modelName = 'gemini-1.5-flash';
    
    try {
      final url = Uri.parse('$_baseUrl/models/$modelName:generateContent?key=$_apiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': systemPrompt}
              ]
            }
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('API ERROR ${response.statusCode}');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final String? text = responseData['candidates']?[0]['content']?['parts']?[0]['text'];
      
      if (text == null || text.isEmpty) {
        return [];
      }

      String cleanedText = text.trim();
      if (cleanedText.contains('```')) {
        final regex = RegExp(r'\{[\s\S]*\}');
        final match = regex.stringMatch(cleanedText);
        if (match != null) {
          cleanedText = match;
        }
      }
      
      final Map<String, dynamic> decoded = jsonDecode(cleanedText.trim());
      final List<dynamic> rawResources = decoded['resources'] ?? [];
      final List<dynamic> rawPractice = decoded['practice'] ?? [];
      final Map<String, dynamic> rawMastery = decoded['mastery'] ?? {};
      
      final List<Map<String, String>> resources = rawResources.map((r) => {
        'type': r['type']?.toString() ?? 'article',
        'title': r['title']?.toString() ?? 'Learning Resource',
        'url': r['url']?.toString() ?? '',
        'description': r['description']?.toString() ?? '',
        'source': r['source']?.toString() ?? 'Web',
      }).toList();

      if (rawPractice.isNotEmpty) {
        resources.add({
          'type': 'practice_set',
          'title': 'Practice Questions',
          'url': '',
          'description': jsonEncode(rawPractice),
          'source': 'AI Librarian',
        });
      }

      if (rawMastery.isNotEmpty) {
        resources.add({
          'type': 'mastery_hub',
          'title': 'Mastery Snapshot',
          'url': '',
          'description': jsonEncode(rawMastery),
          'source': 'AI Topper IQ',
        });
      }

      return resources;
    } catch (e) {
      print('Resource Fetching Failed: $e');
      return [];
    }
  }
}
