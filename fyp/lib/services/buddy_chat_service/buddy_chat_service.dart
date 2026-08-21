import 'dart:convert';
import 'package:http/http.dart' as http;

/// BuddyChatService - A friendly eye-health chatbot using Gemini AI
/// Only answers eye-related questions, greetings, and fun eye jokes
class BuddyChatService {
  static const String _apiKey = 'AIzaSyBcRyQ8HKsznXUlyk56Su-dRVUSWnLkKx8';
  static const String _primaryModel = 'gemini-2.5-flash';
  static const String _fallbackModel = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Max retry attempts before switching to fallback model
  static const int _maxRetries = 3;

  /// System prompt that defines the chatbot's personality and constraints
  static const String _systemPrompt = '''
You are "Eye Buddy" - a friendly, fun, and helpful eye health assistant for HealthVerse app. Your role is to help patients with eye-related questions in simple, easy-to-understand language.

PERSONALITY:
- Be warm, friendly, and encouraging like a helpful friend
- Use simple language that anyone can understand (no medical jargon)
- Add occasional eye-related puns or jokes to keep things fun 👁️
- Be empathetic and reassuring when users express concerns
- Use emojis sparingly to be friendly but professional

WHAT YOU CAN DO:
✅ Answer general eye health questions (dry eyes, eye strain, common symptoms)
✅ Explain common eye conditions in layman's terms (cataracts, glaucoma, myopia, etc.)
✅ Give eye care tips (screen time, nutrition, exercises, proper lighting)
✅ Tell fun eye facts and jokes when asked
✅ Respond to greetings and casual conversation
✅ Encourage users to book appointments for serious concerns
✅ Explain what to expect at eye exams

WHAT YOU CANNOT DO:
❌ Diagnose any eye condition - always recommend seeing a doctor
❌ Prescribe medications or treatments
❌ Answer questions unrelated to eyes, vision, or general wellness
❌ Provide emergency medical advice (direct to emergency services)
❌ Make fun of any disability or condition

BOUNDARIES:
- For non-eye questions, politely redirect: "I'm your eye health buddy! I can only help with eye-related questions. Is there something about your eyes or vision I can help with? 👁️"
- For serious symptoms (sudden vision loss, severe pain, injury), say: "That sounds serious! Please seek immediate medical attention or visit your nearest eye doctor/emergency room right away. Your vision is precious! 🏥"
- Never claim to replace professional medical advice

RESPONSE STYLE:
- Keep responses concise (2-4 sentences for simple questions)
- Use bullet points for tips or lists
- End with a helpful question or encouragement when appropriate
- For jokes, keep them light and family-friendly

EXAMPLE JOKES (when asked):
- "Why did the phone wear glasses? Because it lost all its contacts! 📱👓"
- "I used to hate my glasses, but then I looked back and realized they helped me see things more clearly!"
- "What do you call a fish with no eyes? A fsh! 🐟"

Remember: You're here to be helpful, fun, and supportive while keeping eyes healthy! 👁️✨
''';

  /// Chat history for context
  final List<Map<String, String>> _chatHistory = [];

  /// Send a message and get a response
  Future<String> sendMessage(String userMessage) async {
    try {
      // Build the request body using proper Gemini API structure
      final requestBody = {
        'system_instruction': {
          'parts': [
            {'text': _systemPrompt}
          ]
        },
        'contents': [
          // Include recent chat history for context (last 10 messages)
          ..._chatHistory
              .take(10)
              .map((msg) => {
                    'role': msg['role'],
                    'parts': [
                      {'text': msg['parts']}
                    ]
                  })
              .toList(),
          // Add the current user message
          {
            'role': 'user',
            'parts': [
              {'text': userMessage}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
        ],
      };

      // Add user message to history AFTER building request so it doesn't get duplicated
      _chatHistory.add({'role': 'user', 'parts': userMessage});

      // Try primary model with retries, then fall back
      final response = await _callWithRetryAndFallback(requestBody);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final text = candidates[0]['content']?['parts']?[0]?['text'] ??
              "I'm having trouble thinking right now. Please try again! 👁️";

          // Add assistant response to history
          _chatHistory.add({'role': 'model', 'parts': text});

          return text;
        } else {
          return "I couldn't generate a response. Please try again! 👁️";
        }
      } else {
        print('Gemini API Error: ${response.statusCode} - ${response.body}');
        return "Oops! I'm having a little trouble connecting. Please try again in a moment! 👁️";
      }
    } catch (e) {
      print('BuddyChatService Error: $e');
      return "Something went wrong on my end ($e). Please try again! 👁️";
    }
  }

  Future<http.Response> _callWithRetryAndFallback(
      Map<String, dynamic> requestBody) async {
    // --- Try primary model with retries ---
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      final response = await http.post(
        Uri.parse('$_baseUrl/$_primaryModel:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 503) {
        return response; // Success or a non-retryable error
      }

      print(
          'Gemini 503 (attempt $attempt/$_maxRetries) - model overloaded, retrying...');

      // Exponential backoff: 1s, 2s, 4s
      await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
    }

    // --- Primary model exhausted retries, try fallback model ---
    print(
        'Primary model $_primaryModel unavailable after $_maxRetries attempts. '
        'Falling back to $_fallbackModel...');

    final fallbackResponse = await http.post(
      Uri.parse('$_baseUrl/$_fallbackModel:generateContent?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    return fallbackResponse;
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
