import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fyp/models/vital_data/vital_data.dart';
import 'package:fyp/services/api_client/api_client.dart';
import 'package:fyp/views/links/base_url_link/base_url_link.dart';
import 'package:http/http.dart' as http;

// M-4 FOR PYTHON APIs CALLING
class SymptomQuestionService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>?> triageQuestionStart(
      String symptoms, Function(bool) setLoading) async {
    try {
      setLoading(true);

      print("=== Starting symptom triage ===");
      print("Symptoms: $symptoms");

      // Use ApiClient (Dio) for backend calls - has automatic token refresh
      print("Fetching patient data...");
      final patientResponse = await _apiClient.client.get(
        '/api/Patient/patientAllData',
        options: _getDioOptions(),
      );

      print("Patient API Status: ${patientResponse.statusCode}");

      if (patientResponse.statusCode != 200) {
        print("Failed to get patient data: ${patientResponse.statusCode}");
        return null;
      }

      print("Patient data received, parsing...");
      final fullPatientData = PatientResponse.fromJson(patientResponse.data);

      final history = fullPatientData.patient.history.isNotEmpty
          ? fullPatientData.patient.history
          : "";

      // AI API doesn't need token refresh, use http directly
      final String aiBaseUrl = ai_base_url;
      final Uri url = Uri.parse('$aiBaseUrl/health-assessment/start');

      print("Calling AI server at: $url");

      final response = await http
          .post(url,
              headers: {
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'symptoms': symptoms,
                'user_history': history.isNotEmpty ? history : null
              }))
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print("AI server timeout after 30 seconds");
          throw Exception('AI server timeout');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("AI server response success!");
        final responseData = jsonDecode(response.body);
        return responseData;
      } else {
        print("AI Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e, stackTrace) {
      print("=== triageQuestionStart failed ===");
      print("Error: $e");
      print("Stack: $stackTrace");
      return null;
    } finally {
      setLoading(false);
    }
  }

  /// Helper to create Dio options with ngrok header
  Options _getDioOptions() {
    return Options(
      headers: {
        'ngrok-skip-browser-warning': 'true',
      },
    );
  }

  Future<Map<String, dynamic>?> sendAnswer(String sessionid, String questionId,
      String optionId, Function(bool) setLoading,
      {String? customText}) async {
    try {
      setLoading(true);
      final String baseUrl = ai_base_url;
      final Uri url = Uri.parse('$baseUrl/health-assessment/answer');

      final requestBody = {
        "session_id": sessionid,
        "question_id": questionId,
        "option_id": optionId,
      };

      if (customText != null && customText.isNotEmpty) {
        requestBody["custom_text"] = customText;
      }

      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        if (responseData['is_completed'] == false) {
          print("More questions will follow...");
        } else {
          print("Assessment complete - showing final result");
        }

        return responseData;
      } else {
        print("Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Request failed: $e");
      return null;
    } finally {
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> getInitialSummary(String sessionId) async {
    try {
      final String baseUrl = ai_base_url;
      final Uri aiUrl =
          Uri.parse('$baseUrl/health-assessment/initial-condition');

      // AI API call (no auth needed for AI)
      final aiResponse = await http.post(
        aiUrl,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"session_id": sessionId}),
      );

      if (aiResponse.statusCode == 200 || aiResponse.statusCode == 201) {
        final responseData = jsonDecode(aiResponse.body);

        // Extract the comprehensive English clinical summary
        final initialCondition = responseData['initial_condition_summary'];
        final doctorRecommendation = responseData['doctor_recommendation'];
        final chiefComplaint = responseData['chief_complaint'];
        final urgencyLevel = responseData['urgency_level'];
        final reasoning = responseData['reasoning'];
        final recommendedActions = responseData['recommended_actions'];

        print('Clinical Summary: $initialCondition');
        print('Recommended Specialist: $doctorRecommendation');
        print('Urgency: $urgencyLevel');

        // Use ApiClient for backend call - has automatic token refresh
        final backendResponse = await _apiClient.client.post(
          '/api/Appointment/addInitialCondition',
          data: {
            "initialCondition": initialCondition,
            "doctorRecommendation": doctorRecommendation,
            "chiefComplaint": chiefComplaint,
            "urgencyLevel": urgencyLevel,
            "reasoning": reasoning,
            "recommendedActions": recommendedActions,
          },
          options: _getDioOptions(),
        );

        print('Backend response: ${backendResponse.data}');
        return responseData;
      } else {
        print("AI API Error: ${aiResponse.statusCode} - ${aiResponse.body}");
        return null;
      }
    } catch (e) {
      print("Request failed: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateUserHistory(String sessionId,
      String medicalHistory, Function(bool) setLoading) async {
    try {
      setLoading(true);
      final String baseUrl = ai_base_url;
      final Uri url = Uri.parse('$baseUrl/health-assessment/history');

      final requestBody = {
        "session_id": sessionId,
        "medical_history": medicalHistory,
      };

      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return responseData;
      } else {
        print("Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Request failed: $e");
      return null;
    } finally {
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> getSessionStatus(
      String sessionId, Function(bool) setLoading) async {
    try {
      setLoading(true);
      final String baseUrl = ai_base_url;
      final Uri url =
          Uri.parse('$baseUrl/health-assessment/session/$sessionId');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData;
      } else {
        print("Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Request failed: $e");
      return null;
    } finally {
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> getConversationHistory(
      String sessionId, Function(bool) setLoading) async {
    try {
      setLoading(true);
      final String baseUrl = ai_base_url;
      final Uri url =
          Uri.parse('$baseUrl/health-assessment/session/$sessionId/history');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData;
      } else {
        print("Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Request failed: $e");
      return null;
    } finally {
      setLoading(false);
    }
  }
}
