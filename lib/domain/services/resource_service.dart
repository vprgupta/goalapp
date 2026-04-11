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
You are an Expert Learning Librarian. Your task is to find the absolute BEST learning resources for a specific topic.

TOPIC: $topicName
OVERALL GOAL: $goalName
LEARNER LEVEL: $level

BEHAVIOR:
- Provide a curated list of high-quality resources.
- Include a variety of types: video, article, visual (cheatsheets/diagrams), audio (podcasts/talks), and interactive (exercises/playgrounds).
- Return EVERY high-quality resource you can find, aiming for at least 3-5 diverse options per category. 
- The user wants the 'Top 5' best resources across all categories as a minimum, but more is better if they are high-quality.
- Favor official documentation, high-rated tutorials (FreeCodeCamp, Traversy Media, etc.), and interactive tools.

JSON SCHEMA:
Return a JSON object with two keys: 'resources' (list) and 'practice' (list).
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
      "type": "mcq",
      "question": "Famous MCQ question",
      "options": ["A", "B", "C", "D"],
      "correct_index": 0,
      "explanation": "Why it is correct"
    },
    {
      "type": "code",
      "question": "Coding challenge or logic puzzle (e.g. LeetCode style)",
      "starter_code": "Snippet to start with",
      "solution": "Ideal code solution",
      "explanation": "Logic walkthrough"
    },
    {
      "type": "theory",
      "question": "Standard exam theoretical question (e.g. 'Describe how...')",
      "solution": "Comprehensive ideal answer",
      "explanation": "Key points for marks"
    }
  ]
}

Try to find real, famous, or official resources. Mimetize the ACTUAL exam format of the field (e.g. Coding for Tech, Case Study for MBA, MCQ for Medical).
""";

    final modelName = 'gemini-flash-latest';
    
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

      return resources;
    } catch (e) {
      print('Resource Fetching Failed: $e');
      return [];
    }
  }
}
