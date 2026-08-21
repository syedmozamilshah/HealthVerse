import 'package:fyp/models/prescription/prescription_model.dart';
import 'package:fyp/services/api_client/api_client.dart';

// M-5 MEDICATION TRACKING AND CALLING THE APIS FOR UPDATING OF THE INTAKES
class MedicationTrackingService {
  final ApiClient apiClient = ApiClient();

  /// Get active medications for a patient with today's tracking status
  Future<ActiveMedicationsResponse> getActiveMedications(
      String patientId) async {
    try {
      print(
          '[MedicationTrackingService] Getting active medications for patientId: $patientId');

      // ApiClient automatically adds Bearer token via interceptor
      final response = await apiClient.client.get(
        '/api/MedicationTracking/active/$patientId',
      );

      print(
          '[MedicationTrackingService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = ActiveMedicationsResponse.fromJson(response.data);
        print(
            '[MedicationTrackingService] Parsed ${result.data.length} active medications');
        return result;
      } else {
        return ActiveMedicationsResponse(
          success: false,
          message: 'Failed to load medications',
          data: [],
        );
      }
    } catch (e) {
      print('[MedicationTrackingService] Error getting active medications: $e');
      return ActiveMedicationsResponse(
        success: false,
        message: 'Error: $e',
        data: [],
      );
    }
  }

  /// Mark medication as taken/not taken for a specific time slot
  Future<bool> markMedicationTaken({
    required String prescriptionId,
    required String medicineName,
    required String timeSlot, // "morning", "afternoon", "evening", "night"
    required bool taken,
    String notes = '',
  }) async {
    try {
      print(
          '[MedicationTrackingService] Marking medication: $medicineName ($timeSlot) as $taken');

      // ApiClient automatically adds Bearer token via interceptor
      final response = await apiClient.client.post(
        '/api/MedicationTracking/mark',
        data: {
          'prescriptionId': prescriptionId,
          'medicineName': medicineName,
          'timeSlot': timeSlot,
          'taken': taken,
          'notes': notes,
        },
      );

      print(
          '[MedicationTrackingService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = response.data;
        return result['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('[MedicationTrackingService] Error marking medication: $e');
      return false;
    }
  }

  /// Get medication adherence for a patient (for doctor view)
  Future<List<Map<String, dynamic>>> getMedicationAdherence(
      String patientId) async {
    try {
      print(
          '[MedicationTrackingService] Getting medication adherence for patientId: $patientId');

      // ApiClient automatically adds Bearer token via interceptor
      final response = await apiClient.client.get(
        '/api/MedicationTracking/adherence/$patientId',
      );

      print(
          '[MedicationTrackingService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = response.data;
        if (result['success'] == true && result['data'] != null) {
          return List<Map<String, dynamic>>.from(result['data']);
        }
      }
      return [];
    } catch (e) {
      print('[MedicationTrackingService] Error getting adherence: $e');
      return [];
    }
  }

  /// Get daily medication history for graph display
  // M-7 GETTING THE TRACKING HISTORY(DAILY)
  Future<DailyHistoryResponse> getDailyHistory(String patientId,
      {int days = 7}) async {
    try {
      print(
          '[MedicationTrackingService] Getting daily history for patientId: $patientId, days: $days');

      // ApiClient automatically adds Bearer token via interceptor
      final response = await apiClient.client.get(
        '/api/MedicationTracking/daily-history/$patientId',
        queryParameters: {'days': days},
      );

      print(
          '[MedicationTrackingService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return DailyHistoryResponse.fromJson(response.data);
      } else {
        return DailyHistoryResponse(
          success: false,
          message: 'Failed to load history',
          data: [],
        );
      }
    } catch (e) {
      print('[MedicationTrackingService] Error getting daily history: $e');
      return DailyHistoryResponse(
        success: false,
        message: 'Error: $e',
        data: [],
      );
    }
  }
}

/// Daily history response model
class DailyHistoryResponse {
  final bool success;
  final String message;
  final List<DailyHistoryStat> data;

  DailyHistoryResponse({
    required this.success,
    this.message = '',
    required this.data,
  });

  factory DailyHistoryResponse.fromJson(Map<String, dynamic> json) {
    return DailyHistoryResponse(
      success: json['success'] ?? false,
      message: json['message']?.toString() ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => DailyHistoryStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Daily history statistic for one day
class DailyHistoryStat {
  final String date;
  final String dayName;
  final int scheduledDoses;
  final int takenDoses;
  final int missedDoses;
  final double adherencePercentage;

  DailyHistoryStat({
    required this.date,
    required this.dayName,
    this.scheduledDoses = 0,
    this.takenDoses = 0,
    this.missedDoses = 0,
    this.adherencePercentage = 0,
  });

  factory DailyHistoryStat.fromJson(Map<String, dynamic> json) {
    return DailyHistoryStat(
      date: json['date']?.toString() ?? '',
      dayName: json['dayName']?.toString() ?? '',
      scheduledDoses: json['scheduledDoses'] ?? 0,
      takenDoses: json['takenDoses'] ?? 0,
      missedDoses: json['missedDoses'] ?? 0,
      adherencePercentage: (json['adherencePercentage'] ?? 0).toDouble(),
    );
  }
}
