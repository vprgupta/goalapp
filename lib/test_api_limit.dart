import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  String apiKey = 'AIzaSyCGzFu9pa2NyRCC_Zi-pcTD8td98RGQduQ';
  String urlStr = 'https://generativelanguage.googleapis.com/v1beta/models?key=' + apiKey;
  
  final response = await http.get(Uri.parse(urlStr));
  
  print('HTTP ' + response.statusCode.toString());
  final json = jsonDecode(response.body);
  if (json['models'] != null) {
      for (var model in json['models']) {
          print(model['name']);
      }
  } else {
      print(response.body);
  }
}
