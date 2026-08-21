import 'package:dio/dio.dart';
import 'package:fyp/services/api_client/api_client.dart';

class ReferralService {
  final ApiClient _apiClient = ApiClient();

  Future<Response> createReferral(String patientId, String targetSpecialty, String notes) async {
    final payload = {
      'patientId': patientId,
      'targetSpecialty': targetSpecialty,
      'notes': notes,
    };
    return await _apiClient.client.post('/api/Referral/create', data: payload);
  }

  Future<List<dynamic>> getActiveReferrals(String patientId) async {
    try {
      final res = await _apiClient.client.get('/api/Referral/patient/$patientId/active');
      if (res.statusCode == 200 && res.data != null && res.data['isSuccess'] == true) {
        return res.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error getting active referrals: $e');
      return [];
    }
  }
}
