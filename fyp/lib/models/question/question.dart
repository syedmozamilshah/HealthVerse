import 'option_model.dart';

// M-4 FOR QUESTION
class Question {
  final String questionId;
  final String questionText;
  final List<OptionModel> options;

  Question({
    required this.questionText,
    required this.options,
    required this.questionId,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    try {
      return Question(
        questionId: json['id'] ?? '',
        questionText: json['text'] ?? 'No question text',
        options: json['options'] != null
            ? (json['options'] as List)
                .map((o) => OptionModel.fromJson(o))
                .toList()
            : <OptionModel>[],
      );
    } catch (e) {
      print("Error parsing Question: $e");
      print("JSON data: $json");
      return Question(
        questionId: '',
        questionText: 'Error loading question',
        options: <OptionModel>[],
      );
    }
  }
}
