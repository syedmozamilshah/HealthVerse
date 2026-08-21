import 'package:fyp/models/question/question.dart';

// M-4 FOR QUESTION MODEL
class QuestionModel {
  final String sessionId;
  final Question? question;
  final String? initialGuess;
  final bool isCompleted;
  final int questionsAnswered;
  final int totalQuestions;
  final bool? error;
  final String? errorType; // 'invalid_symptoms' or 'service_error'
  final String? errorMessage;
  final String? detectedLanguage;

  QuestionModel({
    required this.sessionId,
    this.question,
    this.initialGuess,
    required this.isCompleted,
    required this.questionsAnswered,
    required this.totalQuestions,
    this.error,
    this.errorType,
    this.errorMessage,
    this.detectedLanguage,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    try {
      final sessionId = json['session_id'] ?? '';
      final questionData = json['question'];
      final initialGuess = json['initial_guess'];
      final isCompleted = json['is_completed'] ?? false;
      final questionsAnswered = json['questions_answered'] ?? 0;
      final totalQuestions = json['total_questions'] ?? 0;
      final error = json['error'];
      final errorType = json['error_type'];
      final errorMessage = json['error_message'];
      final detectedLanguage = json['detected_language'];

      Question? question;
      print(question);
      print(questionData);
      if (questionData != null) {
        print("inside");
        question = Question.fromJson(questionData);
      }
      if (question != null) {
        print(question.questionId);
      }

      return QuestionModel(
        sessionId: sessionId,
        question: question,
        initialGuess: initialGuess,
        isCompleted: isCompleted,
        questionsAnswered: questionsAnswered,
        totalQuestions: totalQuestions,
        error: error,
        errorType: errorType,
        errorMessage: errorMessage,
        detectedLanguage: detectedLanguage,
      );
    } catch (e) {
      print("Error parsing QuestionModel: $e");
      print("JSON data: $json");
      return QuestionModel(
        sessionId: '',
        question: null,
        initialGuess: null,
        isCompleted: false,
        questionsAnswered: 0,
        totalQuestions: 0,
      );
    }
  }

  bool get hasError => error == true;

  /// Returns true if the error is due to invalid/non-eye-related symptoms
  bool get isInvalidSymptoms => errorType == 'invalid_symptoms';

  /// Returns true if the error is due to a service issue
  bool get isServiceError => errorType == 'service_error';

  double get progressPercentage {
    if (totalQuestions == 0) return 0.0;
    return (questionsAnswered / totalQuestions) * 100;
  }

  bool get hasMoreQuestions {
    return !isCompleted && question != null;
  }
}
