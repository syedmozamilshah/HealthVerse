import 'package:dio/dio.dart';
import '../../models/prescription/prescription_model.dart';
import '../api_client/api_client.dart';

// M-5 PRESCRIPTION SERVICE AND CALLING THE APIS
class PrescriptionService {
  final ApiClient _apiClient = ApiClient();

  /// Get all prescriptions for the current logged-in user (patient)
  Future<PrescriptionsResponse> getMyPrescriptions() async {
    try {
      print('=== PrescriptionService: Fetching my prescriptions ===');
      final response = await _apiClient.client.get(
        '/api/Prescription/my-prescriptions',
      );

      print('PrescriptionService: Response status: ${response.statusCode}');
      print('PrescriptionService: Response data: ${response.data}');

      if (response.statusCode == 200) {
        final result = PrescriptionsResponse.fromJson(response.data);
        print(
            'PrescriptionService: Parsed ${result.data.length} prescriptions');
        return result;
      } else {
        print('PrescriptionService: Non-200 status code');
        return PrescriptionsResponse(
          success: false,
          data: [],
          message: 'Failed to fetch prescriptions',
        );
      }
    } on DioException catch (e) {
      print('PrescriptionService: DioException: ${e.message}');
      print('PrescriptionService: Response: ${e.response?.data}');
      return PrescriptionsResponse(
        success: false,
        data: [],
        message: e.response?.data?['message'] ?? 'Network error occurred',
      );
    } catch (e) {
      print('PrescriptionService: Exception: $e');
      return PrescriptionsResponse(
        success: false,
        data: [],
        message: 'An unexpected error occurred',
      );
    }
  }

  /// Get prescriptions by patient ID (for doctors)
  Future<PrescriptionsResponse> getPatientPrescriptions(
      String patientId) async {
    try {
      final response = await _apiClient.client.get(
        '/api/Prescription/patient/$patientId',
      );

      if (response.statusCode == 200) {
        return PrescriptionsResponse.fromJson(response.data);
      } else {
        return PrescriptionsResponse(
          success: false,
          data: [],
          message: 'Failed to fetch prescriptions',
        );
      }
    } on DioException catch (e) {
      return PrescriptionsResponse(
        success: false,
        data: [],
        message: e.response?.data?['message'] ?? 'Network error occurred',
      );
    } catch (e) {
      return PrescriptionsResponse(
        success: false,
        data: [],
        message: 'An unexpected error occurred',
      );
    }
  }
}
