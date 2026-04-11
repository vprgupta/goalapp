import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const String _apiKey = 'AIzaSyDZBEIi_omqAPSGRC6eqcCUb1KryXUcUos';
  
  // Switching back to v1beta as confirmed by direct curl diagnostic
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  AiService();

  Future<List<Map<String, dynamic>>> generateSyllabus({
    required String goal,
    required String level,
    required int days,
  }) async {
    final systemPrompt = """
You are a Senior Learning Architect and Expert Curriculum Designer. Your task is to generate a comprehensive, professional learning syllabus for a user's goal.

BEHAVIOR:
- Be rigorous and highly structured. 
- Break down complex goals into logical, progressive steps.
- For each topic, provide specific, high-value sub-topics that the user should master.

JSON SCHEMA:
The response MUST be a valid JSON object with a single key 'topics'.
Each topic in the list must have:
- 'title': A professional name for the learning module.
- 'duration_sec': Estimated time in seconds (15-60 mins depending on complexity).
- 'subtopics': A list of 3-5 specific bullet points/concepts to be covered in this topic.

CONTEXT:
Goal: $goal
Target Level: $level
Planned Duration: $days days

Example Response Format:
{
  "topics": [
    { 
      "title": "Module 1: Professional Environment Setup", 
      "duration_sec": 1800,
      "subtopics": ["CLI Basics", "Compiler Installation", "Environment Variables", "First Hello World"]
    }
  ]
}
""";

    // Verified the available model ID for this project is 'gemini-flash-latest'
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
        throw Exception('API ERROR ${response.statusCode}: ${response.body}');
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
      }).toList();
    } catch (e) {
      throw Exception('Roadmap Generation Failed: $e');
    }
  }
}
