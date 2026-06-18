import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = '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';
  final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
  
  try {
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'user', 'content': 'hello'}
        ]
      }),
    );
    print('Status: ${res.statusCode}');
    print('Body: ${res.body}');
  } catch (e) {
    print('Error: $e');
  }
}
