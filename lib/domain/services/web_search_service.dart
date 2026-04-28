import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'llm_config.dart';

/// Calls the Tavily Search API to get real, verified web results.
/// Returns an empty list gracefully when no API key is configured.
class WebSearchService {
  static const String _baseUrl = 'https://api.tavily.com/search';

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int maxResults = 5,
    String searchDepth = 'basic',
  }) async {
    if (LlmConfig.tavilyApiKey.isEmpty) {
      debugPrint('[WebSearch] No Tavily API key — skipping real search for: $query');
      return [];
    }

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'api_key': LlmConfig.tavilyApiKey,
              'query': query,
              'search_depth': searchDepth,
              'include_answer': false,
              'include_raw_content': false,
              'max_results': maxResults,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        return results.map((r) => {
              'title': r['title']?.toString() ?? '',
              'url': r['url']?.toString() ?? '',
              'snippet': r['content']?.toString() ?? '',
            }).toList();
      } else {
        debugPrint('[WebSearch] Tavily error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[WebSearch] Search failed for "$query": $e');
    }
    return [];
  }

  /// Runs multiple queries in parallel for speed.
  Future<Map<String, List<Map<String, dynamic>>>> searchMultiple(
    Map<String, String> labeledQueries,
  ) async {
    final futures = labeledQueries.entries.map((entry) async {
      final results = await search(entry.value);
      return MapEntry(entry.key, results);
    });

    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }
}
