import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fyp/utils/constants.dart';

/// BuddyChatService - A friendly eye-health chatbot using our backend
class BuddyChatService {
  final String _baseUrl = '${ApiEndpoints.baseUrl}/api/ChatBot';

  /// Chat history for context
  final List<Map<String, String>> _chatHistory = [];

  /// Send a message and get a response
  Future<String> sendMessage(String userMessage) async {
    try {
      final requestBody = {
        'userMessage': userMessage,
        'history': _chatHistory
      };

      // Add user message to history
      _chatHistory.add({'role': 'user', 'parts': userMessage});

      final response = await http.post(
        Uri.parse('$_baseUrl/ask'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['isSuccess'] == true) {
          final text = data['message'] ?? "I'm having trouble thinking right now. Please try again! 👁️";
          
          // Add assistant response to history
          _chatHistory.add({'role': 'model', 'parts': text});
          
          return text;
        } else {
          return data['message'] ?? "I couldn't generate a response. Please try again! 👁️";
        }
      } else {
        print('Backend ChatBot Error: ${response.statusCode} - ${response.body}');
        return "Oops! I'm having a little trouble connecting. Please try again in a moment! 👁️";
      }
    } catch (e) {
      print('BuddyChatService Error: $e');
      return "Something went wrong on my end ($e). Please try again! 👁️";
    }
  }

  /// Clear chat history
  void clearHistory() {
    _chatHistory.clear();
  }

  /// Get greeting message
  String getGreeting() {
    return "👁️ Hi there! I'm Eye Buddy, your friendly eye health assistant!\n\n"
        "I can help you with:\n"
        "• Eye health questions\n"
        "• Vision care tips\n"
        "• Understanding eye conditions\n"
        "• Fun eye facts & jokes!\n\n"
        "What would you like to know about your eyes today? 😊";
  }
}
