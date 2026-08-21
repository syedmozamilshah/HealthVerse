import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/appointment/appointment_model.dart';
import 'package:fyp/utils/pakistan_time_helper.dart';
import '../api_client/api_client.dart';

// M-4 CALLING API OF THE BACKEND
class AppointmentService {
  final ApiClient _apiClient = ApiClient();

  /// Get all appointments for the logged-in patient
  Future<AppointmentsResponse> getMyAppointments() async {
    try {
      debugPrint('=== AppointmentService: Fetching my appointments ===');
      final response = await _apiClient.client.get(
        '/api/Patient/my-appointments',
      );

      debugPrint('AppointmentService: Response status: ${response.statusCode}');
      debugPrint('AppointmentService: Response data: ${response.data}');

      if (response.statusCode == 200) {
        final result = AppointmentsResponse.fromJson(response.data);
        debugPrint(
            'AppointmentService: Parsed ${result.data.length} appointments');
        return result;
      } else {
        debugPrint('AppointmentService: Non-200 status code');
        return AppointmentsResponse(
          isSuccess: false,
          data: [],
          message: 'Failed to fetch appointments',
        );
      }
    } on DioException catch (e) {
      debugPrint('AppointmentService: DioException: ${e.message}');
      debugPrint('AppointmentService: Response: ${e.response?.data}');
      return AppointmentsResponse(
        isSuccess: false,
        data: [],
        message: e.response?.data?['message'] ?? 'Network error occurred',
      );
    } catch (e) {
      debugPrint('AppointmentService: Exception: $e');
      return AppointmentsResponse(
        isSuccess: false,
        data: [],
        message: 'An unexpected error occurred',
      );
    }
  }

  /// Get upcoming appointments (future appointments)
  Future<List<PatientAppointment>> getUpcomingAppointments() async {
    final response = await getMyAppointments();
    if (!response.isSuccess) return [];

    return response.data.where((a) => a.isUpcoming && !a.isCancelled).toList()
      ..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
  }

  /// Get past appointments (completed or past date)
  Future<List<PatientAppointment>> getPastAppointments() async {
    final response = await getMyAppointments();
    if (!response.isSuccess) return [];

    return response.data.where((a) => !a.isUpcoming || a.isCompleted).toList()
      ..sort((a, b) =>
          b.appointmentDate.compareTo(a.appointmentDate)); // newest first
  }

  /// Get today's appointments
  Future<List<PatientAppointment>> getTodayAppointments() async {
    final response = await getMyAppointments();
    if (!response.isSuccess) return [];

    return response.data.where((a) => a.isToday && !a.isCancelled).toList()
      ..sort((a, b) {
        if (a.slotStartTime == null || b.slotStartTime == null) return 0;
        return a.slotStartTime!.compareTo(b.slotStartTime!);
      });
  }

  /// Get active medications from recent appointments
  Future<List<ActiveMedication>> getActiveMedications() async {
    final now = PakistanTimeHelper.nowPakistan();
    final response = await getMyAppointments();
    if (!response.isSuccess) return [];

    final List<ActiveMedication> activeMeds = [];

    for (final appointment in response.data) {
      // Only check completed appointments with prescriptions
      if (appointment.prescriptions.isEmpty) continue;

      for (final prescription in appointment.prescriptions) {
        if (prescription.medicineName.isEmpty) continue;

        final endDate = prescription.getEndDate(appointment.appointmentDate);

        // Check if medication is still active
        if (PakistanTimeHelper.nowPakistan()
            .isBefore(PakistanTimeHelper.toPakistanTime(endDate))) {
          activeMeds.add(ActiveMedication(
            medicineName: prescription.medicineName,
            dosage: prescription.dosage,
            schedule: prescription.schedule,
            instructions: prescription.instructions,
            startDate: appointment.appointmentDate,
            endDate: endDate,
            doctorName: appointment.doctorName,
            appointmentId: appointment.id,
          ));
        }
      }
    }

    // Sort by end date (soonest ending first)
    activeMeds.sort((a, b) => a.endDate.compareTo(b.endDate));
    return activeMeds;
  }

  /// Get past medications (completed medication courses)
  Future<List<ActiveMedication>> getPastMedications() async {
    final response = await getMyAppointments();
    if (!response.isSuccess) return [];

    final List<ActiveMedication> pastMeds = [];

    for (final appointment in response.data) {
      if (appointment.prescriptions.isEmpty) continue;

      for (final prescription in appointment.prescriptions) {
        if (prescription.medicineName.isEmpty) continue;

        final endDate = prescription.getEndDate(appointment.appointmentDate);

        // Check if medication course has ended
        if (PakistanTimeHelper.nowPakistan()
            .isAfter(PakistanTimeHelper.toPakistanTime(endDate))) {
          pastMeds.add(ActiveMedication(
            medicineName: prescription.medicineName,
            dosage: prescription.dosage,
            schedule: prescription.schedule,
            instructions: prescription.instructions,
            startDate: appointment.appointmentDate,
            endDate: endDate,
            doctorName: appointment.doctorName,
            appointmentId: appointment.id,
          ));
        }
      }
    }

    // Sort by end date (most recent first)
    pastMeds.sort((a, b) => b.endDate.compareTo(a.endDate));
    return pastMeds;
  }

  /// Check if patient already has a booking with this doctor on the selected date
  Future<bool> hasExistingBookingForDate({
    required String doctorId,
    required DateTime selectedDate,
  }) async {
    try {
      final response = await getMyAppointments();
      if (!response.isSuccess) return false;

      // Check if there's any non-cancelled appointment with this doctor on the selected date
      final selectedDateOnly = PakistanTimeHelper.toPakistanTime(selectedDate);

      for (final appointment in response.data) {
        // Skip cancelled appointments
        if (appointment.isCancelled) continue;

        // Check if same doctor
        if (appointment.doctorId != doctorId) continue;

        // Check if same date
        if (PakistanTimeHelper.isSamePakistanDate(
            appointment.appointmentDate, selectedDateOnly)) {
          debugPrint(
              'Found existing booking for doctor $doctorId on $selectedDateOnly');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking existing booking: $e');
      return false;
    }
  }
}
