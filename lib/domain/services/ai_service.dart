import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const String _apiKey = 'AIzaSyCGzFu9pa2NyRCC_Zi-pcTD8td98RGQduQ';
  
  // Switching back to v1beta as confirmed by direct curl diagnostic
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  AiService();

  Future<List<Map<String, dynamic>>> generateSyllabus({
    required String goal,
    required String level,
    required int days,
  }) async {
    final systemPrompt = """
Create a professional learning syllabus.
GOAL: $goal | LEVEL: $level | DURATION: $days days.

JSON SCHEMA (Return ONLY this object):
{
  "topics": [
    { 
      "title": "Module name", 
      "duration_sec": 3600,
      "subtopics": ["concept 1", "concept 2", "concept 3"],
      "chapter": "Thematic World Name (e.g. World 1: Basics)",
      "is_boss": boolean (true for last topic of each world),
      "rank": "S|A|B|C" (Difficulty)
    }
  ]
}

BEHAVIOR:
- Be concise. 
- Group topics into 3-5 'Worlds'.
- Last topic of each World must be a Boss Challenge ('is_boss': true).
- Rank: S (Expert), A (Advanced), B (Mid), C (Basic).
""";

    final modelName = 'gemini-flash-latest';
    
    try {
      final url = Uri.parse('$_baseUrl/models/$modelName:generateContent?key=$_apiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'parts': [{'text': systemPrompt}]}
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 429) {
        final body = jsonDecode(response.body);
        final message = body['error']?['message'] ?? '';
        if (message.contains('quota')) {
          throw Exception('Daily Limit Reached: You have used all 1,500 daily requests. Please try again tomorrow.');
        } else {
          throw Exception('Rate Limit: Please wait 60 seconds before trying again.');
        }
      }

      if (response.statusCode != 200) {
        throw Exception('API ERROR ${response.statusCode}');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final String? text = responseData['candidates']?[0]['content']?['parts']?[0]['text'];
      
      if (text == null || text.isEmpty) {
        throw Exception('AI returned no text content. Response: ${response.body}');
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
      final List<dynamic> topics = decoded['topics'] ?? [];
      
      if (topics.isEmpty) {
        throw Exception('No topics found in extracted JSON: $cleanedText');
      }

      return topics.map((t) => {
        'title': t['title'] as String,
        'duration_sec': (t['duration_sec'] as num).toInt(),
        'subtopics': (t['subtopics'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [],
        'chapter': t['chapter'] as String? ?? 'Exploration',
        'is_boss': t['is_boss'] as bool? ?? false,
        'rank': t['rank'] as String? ?? 'B',
      }).toList();
    } catch (e) {
      throw Exception('Roadmap Generation Failed: $e');
    }
  }
}
