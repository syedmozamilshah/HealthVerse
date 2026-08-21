// @Deprecated('Use String directly in QuestionModel instead')
// class InitialGuessModel {
//   final String specialist;
//   final List<String> possibleDiseases;
//   final double confidenceScore;

//   InitialGuessModel({
//     required this.specialist,
//     required this.possibleDiseases,
//     required this.confidenceScore,
//   });

//   factory InitialGuessModel.fromString(String guessString) {
//     return InitialGuessModel(
//       specialist: guessString,
//       possibleDiseases: <String>[],
//       confidenceScore: 0.0,
//     );
//   }
  
//   @Deprecated('API no longer returns objects for initial_guess')
//   factory InitialGuessModel.fromJson(Map<String, dynamic> json) {
//     try {
//       return InitialGuessModel(
//         specialist: json['specialist'] ?? 'Unknown',
//         possibleDiseases: json['possible_diseases'] != null 
//             ? List<String>.from(json['possible_diseases'])
//             : <String>[],
//         confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
//       );
//     } catch (e) {
//       print("Error parsing InitialGuessModel: $e");
//       print("JSON data: $json");
//       // Return default values if parsing fails
//       return InitialGuessModel(
//         specialist: 'Unknown',
//         possibleDiseases: <String>[],
//         confidenceScore: 0.0,
//       );
//     }
//   }
// }
