import 'dart:convert';
import 'dart:io';

void main() async {
  final String apiKey = 'AIzaSyCGzFu9pa2NyRCC_Zi-pcTD8td98RGQduQ';
  final models = ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-pro'];
  final versions = ['v1', 'v1beta'];

  print('Starting API Test...\n');

  for (var version in versions) {
    for (var model in models) {
      final url = 'https://generativelanguage.googleapis.com/$version/models/$model:generateContent?key=$apiKey';
      print('Testing $version -> $model...');
      print('URL: $url');
      
      try {
        final client = HttpClient();
        final request = await client.postUrl(Uri.parse(url));
        request.headers.set('content-type', 'application/json');
        request.add(utf8.encode(jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Hello'}
              ]
            }
          ]
        })));

        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        
        print('Status: ${response.statusCode}');
        if (response.statusCode == 200) {
          print('SUCCESS!');
          exit(0);
        } else {
          print('Error: $body');
        }
      } catch (e) {
        print('Exception: $e');
      }
      print('-------------------\n');
    }
  }
  print('All tests failed.');
}
