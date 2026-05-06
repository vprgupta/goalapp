import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'llm_config.dart';
import 'resource_registry.dart';

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
    final viewNorm = (viewCount / 500000).clamp(0.0, 1.0);
    final likeNorm = likeRatio.clamp(0.0, 0.1) * 10;
    final ageMonths = DateTime.now().difference(publishedAt).inDays / 30;
    final recencyBoost = (1 - (ageMonths / 36).clamp(0.0, 1.0)) * 0.2;
    return (viewNorm * 0.55) + (likeNorm * 0.25) + recencyBoost;
  }

  String get durationLabel {
    if (durationSeconds >= 3600) {
      final h = durationSeconds ~/ 3600;
      final m = (durationSeconds % 3600) ~/ 60;
      return '${h}h ${m}m';
    }
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get viewCountLabel {
    if (viewCount >= 1000000) return '${(viewCount / 1000000).toStringAsFixed(1)}M views';
    if (viewCount >= 1000) return '${(viewCount / 1000).toStringAsFixed(0)}K views';
    return '$viewCount views';
  }

  /// Converts this video to the resource map format used by the Learning Hub.
  Map<String, String> toResourceMap() => {
    'type': 'video',
    'title': title,
    'url': watchUrl,
    'description': '$channelTitle • $viewCountLabel • $durationLabel',
    'source': channelTitle,
    'quality_note': _qualityLabel(),
    'rank': '1',
    'thumbnail_url': thumbnailUrl,
    'video_id': videoId,
    'view_count': viewCount.toString(),
    'duration_seconds': durationSeconds.toString(),
    'channel_title': channelTitle,
  };

  String _qualityLabel() {
    if (viewCount >= 1000000) return '🔥 ${(viewCount / 1000000).toStringAsFixed(1)}M views';
    if (viewCount >= 100000) return '⭐ ${(viewCount / 1000).toStringAsFixed(0)}K views';
    return '📺 ${(viewCount / 1000).toStringAsFixed(0)}K views';
  }
}

class YouTubeTutorialService {
  static const _searchBase = 'https://www.googleapis.com/youtube/v3/search';
  static const _videosBase = 'https://www.googleapis.com/youtube/v3/videos';

  /// Searches YouTube for the best tutorial video for a given topic.
  /// Uses domain-aware channel boosting for more relevant results.
  Future<List<YouTubeVideo>> searchTutorials({
    required String query,
    String? goalName,
    String? pillarName,
    int maxResults = 3,
  }) async {
    final apiKey = LlmConfig.youtubeApiKey;
    if (apiKey.isEmpty || apiKey.startsWith('YOUR_')) return [];

    try {
      // Build a domain-aware, channel-boosted query
      final enrichedQuery = _buildEnrichedQuery(
        query: query,
        goalName: goalName,
        pillarName: pillarName,
      );

      // First attempt: targeted query
      var candidateIds = await _search(query: enrichedQuery, apiKey: apiKey);

      // Fallback: simpler query if too narrow
      if (candidateIds.isEmpty) {
        candidateIds = await _search(query: '$query tutorial', apiKey: apiKey);
      }

      if (candidateIds.isEmpty) return [];

      final videos = await _fetchStats(videoIds: candidateIds, apiKey: apiKey);

      // Sort by quality, but be lenient — even a 10K view video can be great
      final ranked = videos
          .where((v) => v.durationSeconds >= 120) // at least 2 minutes
          .toList()
        ..sort((a, b) => b.qualityScore.compareTo(a.qualityScore));

      return ranked.take(maxResults).toList();
    } catch (e) {
      debugPrint('[YouTubeService] Search failed for "$query": $e');
      return [];
    }
  }

  /// Builds a domain-aware search query that targets the best channels for a tech domain.
  String _buildEnrichedQuery({
    required String query,
    String? goalName,
    String? pillarName,
  }) {
    final domain = ResourceRegistry.detectDomain(goalName ?? '', pillarName ?? query);
    final profile = ResourceRegistry.getProfile(domain);

    // Pick the top 2 channel names to bias the YouTube algorithm
    final channels = profile.ytChannels.split(' OR ').take(2).join(' OR ');

    // e.g. "Variables Java tutorial Amigoscode OR Tim Buchalka 2024 OR 2025"
    return '$query tutorial $channels 2024 OR 2025';
  }

  Future<List<String>> _search({
    required String query,
    required String apiKey,
  }) async {
    final uri = Uri.parse(_searchBase).replace(queryParameters: {
      'part': 'id',
      'q': query,
      'type': 'video',
      'order': 'relevance',
      'relevanceLanguage': 'en',
      'safeSearch': 'strict',
      'maxResults': '12',
      'key': apiKey,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      debugPrint('[YouTubeService] Search HTTP ${response.statusCode}: ${response.body}');
      return [];
    }

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

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
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

      // Accept videos between 2 minutes and 6 hours (course videos are long!)
      if (duration < 120 || duration > 21600) return null;

      // Prefer high-quality thumbnails
      final thumb = snippet['thumbnails']?['maxres']?['url'] as String? ??
          snippet['thumbnails']?['high']?['url'] as String? ??
          snippet['thumbnails']?['medium']?['url'] as String? ??
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
    } catch (e) {
      debugPrint('[YouTubeService] Failed to parse video: $e');
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
