import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_config.dart';

/// A real YouTube video result with verified metadata.
class YouTubeVideo {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final int viewCount;
  final int likeCount;
  final int durationSeconds;
  final DateTime publishedAt;
  final String watchUrl;

  const YouTubeVideo({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.viewCount,
    required this.likeCount,
    required this.durationSeconds,
    required this.publishedAt,
    required this.watchUrl,
  });

  double get likeRatio => viewCount > 0 ? likeCount / viewCount : 0;

  double get qualityScore {
    final viewNorm = (viewCount / 1000000).clamp(0.0, 1.0);
    final likeNorm = likeRatio.clamp(0.0, 0.1) * 10;
    final ageMonths = DateTime.now().difference(publishedAt).inDays / 30;
    final recencyBoost = (1 - (ageMonths / 24).clamp(0.0, 1.0)) * 0.3;
    return (viewNorm * 0.5) + (likeNorm * 0.3) + recencyBoost;
  }

  String get durationLabel {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class YouTubeTutorialService {
  static const _searchBase = 'https://www.googleapis.com/youtube/v3/search';
  static const _videosBase = 'https://www.googleapis.com/youtube/v3/videos';

  Future<List<YouTubeVideo>> searchTutorials({
    required String query,
    int maxResults = 3,
  }) async {
    final apiKey = LlmConfig.youtubeApiKey;
    if (apiKey.isEmpty || apiKey.startsWith('YOUR_')) return [];

    try {
      final candidateIds = await _search(query: query, apiKey: apiKey);
      if (candidateIds.isEmpty) return [];

      final videos = await _fetchStats(videoIds: candidateIds, apiKey: apiKey);

      final ranked = videos
          .where((v) => v.likeRatio >= 0.02)
          .toList()
        ..sort((a, b) => b.qualityScore.compareTo(a.qualityScore));

      return ranked.take(maxResults).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _search({
    required String query,
    required String apiKey,
  }) async {
    final uri = Uri.parse(_searchBase).replace(queryParameters: {
      'part': 'id',
      'q': '$query tutorial 2024 OR 2025',
      'type': 'video',
      'videoDuration': 'medium',
      'order': 'relevance',
      'relevanceLanguage': 'en',
      'safeSearch': 'strict',
      'maxResults': '10',
      'key': apiKey,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items
        .map((item) => item['id']?['videoId'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<List<YouTubeVideo>> _fetchStats({
    required List<String> videoIds,
    required String apiKey,
  }) async {
    final uri = Uri.parse(_videosBase).replace(queryParameters: {
      'part': 'snippet,statistics,contentDetails',
      'id': videoIds.join(','),
      'key': apiKey,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items.map((item) => _parseVideo(item)).whereType<YouTubeVideo>().toList();
  }

  YouTubeVideo? _parseVideo(dynamic item) {
    try {
      final id = item['id'] as String;
      final snippet = item['snippet'] as Map<String, dynamic>;
      final stats = item['statistics'] as Map<String, dynamic>? ?? {};
      final details = item['contentDetails'] as Map<String, dynamic>? ?? {};

      final viewCount = int.tryParse(stats['viewCount'] as String? ?? '0') ?? 0;
      final likeCount = int.tryParse(stats['likeCount'] as String? ?? '0') ?? 0;
      final duration = _parseDuration(details['duration'] as String? ?? 'PT0S');
      final publishedAt =
          DateTime.tryParse(snippet['publishedAt'] as String? ?? '') ?? DateTime.now();

      if (duration < 180 || duration > 2700) return null;

      final thumb = snippet['thumbnails']?['high']?['url'] as String? ??
          snippet['thumbnails']?['default']?['url'] as String? ?? '';

      return YouTubeVideo(
        videoId: id,
        title: snippet['title'] as String? ?? '',
        channelTitle: snippet['channelTitle'] as String? ?? '',
        thumbnailUrl: thumb,
        viewCount: viewCount,
        likeCount: likeCount,
        durationSeconds: duration,
        publishedAt: publishedAt,
        watchUrl: 'https://www.youtube.com/watch?v=$id',
      );
    } catch (_) {
      return null;
    }
  }

  int _parseDuration(String iso) {
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(iso);
    if (match == null) return 0;
    final h = int.tryParse(match.group(1) ?? '0') ?? 0;
    final m = int.tryParse(match.group(2) ?? '0') ?? 0;
    final s = int.tryParse(match.group(3) ?? '0') ?? 0;
    return h * 3600 + m * 60 + s;
  }
}
