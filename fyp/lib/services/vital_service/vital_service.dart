import 'package:dio/dio.dart';
import 'package:fyp/models/vital_data/vital_data.dart';
import 'package:fyp/services/api_client/api_client.dart';

// M-6 CALLING ALL THE API ENDPOINTS RELATED TO VITALS
// M-7 API FOR GETTING THE DATA FROM DATABASE
class VitalService {
  final ApiClient apiClient = ApiClient();

  Future<VitalResponse> getPatientData() async {
    try {
      final response = await apiClient.client.get(
        '/api/Patient/patientData',
      );

      if (response.statusCode == 200) {
        final fullResponse = VitalResponse.fromJson((response.data));

        // Return ALL vitals history without filtering
        print('Total BP records: ${fullResponse.vitals.bloodPressure.length}');
        print('Total Sugar records: ${fullResponse.vitals.sugarLevel.length}');

        return fullResponse;
      } else {
        return VitalResponse(
          vitals: Vitals(
            bloodPressure: [],
            sugarLevel: [],
            lastUpdated: DateTime.now().toUtc(),
          ),
          message: 'failed to load patient data',
          success: false,
        );
      }
    } catch (e, stackTrace) {
      print('Error fetching vitals: $e');
      print(stackTrace);
      return VitalResponse(
        vitals: Vitals(
          bloodPressure: [],
          sugarLevel: [],
          lastUpdated: DateTime.now().toUtc(),
        ),
        message: 'An error occurred while fetching vitals',
        success: false,
      );
    }
  }

  Future<VitalResponse> updateVitals(BloodPressure bp, Sugar sugar) async {
    try {
      final response = await apiClient.client.post(
        '/api/Patient/addVitals',
        data: {
          "blood_pressure": bp.toJson(),
          "sugar": sugar.toJson(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Response body: ${response.data}');
        return VitalResponse.fromJson((response.data));
      } else {
        print('Response body: ${response.data}');
        return VitalResponse(
          vitals: Vitals(
              bloodPressure: [],
              sugarLevel: [],
              lastUpdated: DateTime.now().toUtc()),
          message: 'failed to load patient data',
          success: false,
        );
      }
    } catch (e, stackTrace) {
      print('Error updating vitals: $e');
      print(stackTrace);
      return VitalResponse(
        vitals: Vitals(
            bloodPressure: [],
            sugarLevel: [],
            lastUpdated: DateTime.now().toUtc()),
        message: 'An error occurred while updating vitals',
        success: false,
      );
    }
  }

  Future<VitalResponse> updateBp(BloodPressure bp) async {
    print("entering the vital - updateBp");
    print("BP data being sent: ${bp.toJson()}");
    try {
      final response = await apiClient.client.post(
        '/api/Patient/addBp',
        data: bp.toJson(),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Backend returns PatientResponse, need to extract vitals from patient
        final data = response.data;
        final isSuccess = data['isSuccess'] ?? false;
        final message = data['message'] ?? '';

        if (isSuccess &&
            data['patient'] != null &&
            data['patient']['vitals'] != null) {
          return VitalResponse(
            vitals: Vitals.fromJson(data['patient']['vitals']),
            message: message,
            success: true,
          );
        } else {
          return VitalResponse(
            vitals: Vitals(
                bloodPressure: [],
                sugarLevel: [],
                lastUpdated: DateTime.now().toUtc()),
            message: message.isNotEmpty ? message : 'Failed to parse response',
            success: isSuccess,
          );
        }
      } else {
        return VitalResponse(
          vitals: Vitals(
              bloodPressure: [],
              sugarLevel: [],
              lastUpdated: DateTime.now().toUtc()),
          message: response.data?['message'] ?? 'failed to update',
          success: false,
        );
      }
    } on DioException catch (e) {
      print('DioException in updating BP: ${e.type}');
      print('Error message: ${e.message}');
      print('Response: ${e.response?.data}');
      print('Status code: ${e.response?.statusCode}');
      return VitalResponse(
        vitals: Vitals(
            bloodPressure: [],
            sugarLevel: [],
            lastUpdated: DateTime.now().toUtc()),
        message: e.response?.data?['message'] ??
            'An error occurred while updating bp: ${e.message}',
        success: false,
      );
    } catch (e, stackTrace) {
      print('Error updating bp: $e');
      print(stackTrace);
      return VitalResponse(
        vitals: Vitals(
            bloodPressure: [],
            sugarLevel: [],
            lastUpdated: DateTime.now().toUtc()),
        message: 'An error occurred while updating bp',
        success: false,
      );
    }
  }

  Future<VitalResponse> updateSugar(Sugar sugar) async {
    print("entering the vital - updateSugar");
    print("Sugar data being sent: ${sugar.toJson()}");
    try {
      final response = await apiClient.client.post(
        '/api/Patient/addSugar',
        data: sugar.toJson(),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Backend returns PatientResponse, need to extract vitals from patient
        final data = response.data;
        final isSuccess = data['isSuccess'] ?? false;
        final message = data['message'] ?? '';

        if (isSuccess &&
            data['patient'] != null &&
            data['patient']['vitals'] != null) {
          return VitalResponse(
            vitals: Vitals.fromJson(data['patient']['vitals']),
            message: message,
            success: true,
          );
        } else {
          return VitalResponse(
            vitals: Vitals(
                bloodPressure: [],
                sugarLevel: [],
                lastUpdated: DateTime.now().toUtc()),
            message: message.isNotEmpty ? message : 'Failed to parse response',
            success: isSuccess,
          );
        }
      } else {
        return VitalResponse(
          vitals: Vitals(
              bloodPressure: [],
              sugarLevel: [],
              lastUpdated: DateTime.now().toUtc()),
          message: response.data?['message'] ?? 'failed to update',
          success: false,
        );
      }
    } on DioException catch (e) {
      print('DioException in updating sugar: ${e.type}');
      print('Error message: ${e.message}');
      print('Response: ${e.response?.data}');
      print('Status code: ${e.response?.statusCode}');
      return VitalResponse(
        vitals: Vitals(
            bloodPressure: [],
            sugarLevel: [],
            lastUpdated: DateTime.now().toUtc()),
        message: e.response?.data?['message'] ??
            'An error occurred in updating sugar: ${e.message}',
        success: false,
      );
    } catch (e, stackTrace) {
      print('error in updating sugar: $e');
      print(stackTrace);
      return VitalResponse(
        vitals: Vitals(
            bloodPressure: [],
            sugarLevel: [],
            lastUpdated: DateTime.now().toUtc()),
        message: 'An error occured in updating sugar',
        success: false,
      );
    }
  }
}
