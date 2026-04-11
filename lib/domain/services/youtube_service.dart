import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  final _yt = YoutubeExplode();

  /// Fetches video titles and durations from a YouTube playlist URL.
  Future<List<Map<String, dynamic>>> fetchPlaylistMetadata(String url) async {
    try {
      final playlistId = _extractPlaylistId(url);
      if (playlistId == null) throw Exception('Invalid playlist URL');

      final playlist = await _yt.playlists.get(playlistId);
      final List<Map<String, dynamic>> metadata = [];

      await for (final video in _yt.playlists.getVideos(playlist.id)) {
        metadata.add({
          'title': video.title,
          'duration_sec': video.duration?.inSeconds ?? 1200,
          'video_id': video.id.value,
          'thumbnail_url': video.thumbnails.mediumResUrl,
        });
      }

      if (metadata.isEmpty) throw Exception('No videos found in playlist');
      
      return metadata;
    } catch (e) {
      throw Exception('Failed to fetch playlist: $e');
    }
  }

  String? _extractPlaylistId(String url) {
    if (url.contains('list=')) {
      final match = RegExp(r'list=([^&]+)').firstMatch(url);
      return match?.group(1);
    }
    // Handle short IDs or other patterns if necessary
    return null;
  }

  void dispose() {
    _yt.close();
  }
}
