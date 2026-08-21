// M-4 FOR QUESTION OPTIONS
class OptionModel {
  final String optionId;
  final String text;

  OptionModel({required this.optionId, required this.text});

  factory OptionModel.fromJson(Map<String, dynamic> json) {
    try {
      return OptionModel(
        optionId: json['id'] ?? '',
        text: json['text'] ?? 'No option text',
      );
    } catch (e) {
      print("Error parsing OptionModel: $e");
      print("JSON data: $json");
      return OptionModel(
        optionId: '',
        text: 'Error loading option',
      );
    }
  }
}
