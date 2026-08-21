import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const String _apiKey = 'AIzaSyCfk1BkQY3UFrD1ekuuxIGg4diViNfqcnE';
  const String _model = 'gemini-2.5-flash-lite';
  const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  final requestBody = {
    'contents': [
      {
        'role': 'user',
        'parts': [{'text': 'Hello'}]
      }
    ]
  };

  try {
    final response = await http.post(
      Uri.parse('$_baseUrl/$_model:generateContent?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );
    print('Status Code: ${response.statusCode}');
    print('Response: ${response.body}');
  } catch (e) {
    print('Exception: $e');
  }
}
