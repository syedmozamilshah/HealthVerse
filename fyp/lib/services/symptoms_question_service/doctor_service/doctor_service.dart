import 'package:fyp/models/doctor_data/doctor_data.dart';
import 'package:fyp/services/api_client/api_client.dart';

// M-4 CALLING THE TO GET DOCTOR INFO
class DoctorService {
  final ApiClient apiClient = ApiClient();

  Future<DoctorResponse> getAvailableDoctor(String speciality) async {
    try {
      print('DoctorService: Getting doctors for speciality: $speciality');

      // ApiClient automatically adds Bearer token via interceptor
      final response = await apiClient.client.get(
        '/api/DoctorBasicInfo/available/${Uri.encodeComponent(speciality)}',
      );

      print('DoctorService: Response status: ${response.statusCode}');
      print('DoctorService: Response body: ${response.data}');

      if (response.statusCode == 200) {
        final result = DoctorResponse.fromJson(response.data);
        print(
            'DoctorService: Parsed ${result.doctors.length} doctors, success: ${result.success}');
        return result;
      } else {
        print('DoctorService: Non-200 response: ${response.statusCode}');
        return const DoctorResponse(
          doctors: [],
          message: 'Failed to load doctors',
          success: false,
        );
      }
    } catch (e, stackTrace) {
      print('DoctorService: Error fetching doctors: $e');
      print(stackTrace);
      return const DoctorResponse(
        doctors: [],
        message: 'An error occurred while fetching doctors',
        success: false,
      );
    }
  }
}
