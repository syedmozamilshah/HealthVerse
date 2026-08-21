import 'package:fyp/utils/pakistan_time_helper.dart';

/// Represents a single medicine item in a prescription
/// M-5 PRESCRIPTION MODEL
class MedicineItem {
  final String name;
  final String dosage;
  final String frequency;
  final int durationDays;
  final bool morning;
  final bool afternoon;
  final bool evening;
  final bool night;
  final String morningTimeUtc;
  final String afternoonTimeUtc;
  final String eveningTimeUtc;
  final String nightTimeUtc;
  final DateTime startDate;
  final DateTime endDate;
  final String instructions;

  MedicineItem({
    required this.name,
    this.dosage = '',
    this.frequency = '',
    this.durationDays = 7,
    this.morning = false,
    this.afternoon = false,
    this.evening = false,
    this.night = false,
    this.morningTimeUtc = '',
    this.afternoonTimeUtc = '',
    this.eveningTimeUtc = '',
    this.nightTimeUtc = '',
    DateTime? startDate,
    DateTime? endDate,
    this.instructions = '',
  })  : startDate = startDate ?? DateTime.now().toUtc(),
        endDate = endDate ?? DateTime.now().toUtc().add(Duration(days: 7));

  factory MedicineItem.fromJson(Map<String, dynamic> json) {
    return MedicineItem(
      name: json['name']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      durationDays: json['durationDays'] ?? 7,
      morning: json['morning'] ?? false,
      afternoon: json['afternoon'] ?? false,
      evening: json['evening'] ?? false,
      night: json['night'] ?? false,
      morningTimeUtc: json['morningTimeUtc']?.toString() ?? '',
      afternoonTimeUtc: json['afternoonTimeUtc']?.toString() ?? '',
      eveningTimeUtc: json['eveningTimeUtc']?.toString() ?? '',
      nightTimeUtc: json['nightTimeUtc']?.toString() ?? '',
      startDate: json['startDate'] != null
          ? PakistanTimeHelper.parseUtcNullable(json['startDate'].toString())
          : null,
      endDate: json['endDate'] != null
          ? PakistanTimeHelper.parseUtcNullable(json['endDate'].toString())
          : null,
      instructions: json['instructions']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'durationDays': durationDays,
      'morning': morning,
      'afternoon': afternoon,
      'evening': evening,
      'night': night,
      'morningTimeUtc': morningTimeUtc,
      'afternoonTimeUtc': afternoonTimeUtc,
      'eveningTimeUtc': eveningTimeUtc,
      'nightTimeUtc': nightTimeUtc,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'instructions': instructions,
    };
  }
}

/// Tracks medication taken status for a day
class MedicationTracking {
  final String? id;
  final String prescriptionId;
  final String patientId;
  final String medicineName;
  final DateTime date;
  final bool morningTaken;
  final DateTime? morningTime;
  final bool afternoonTaken;
  final DateTime? afternoonTime;
  final bool eveningTaken;
  final DateTime? eveningTime;
  final bool nightTaken;
  final DateTime? nightTime;
  final String notes;

  MedicationTracking({
    this.id,
    required this.prescriptionId,
    required this.patientId,
    required this.medicineName,
    required this.date,
    this.morningTaken = false,
    this.morningTime,
    this.afternoonTaken = false,
    this.afternoonTime,
    this.eveningTaken = false,
    this.eveningTime,
    this.nightTaken = false,
    this.nightTime,
    this.notes = '',
  });

  factory MedicationTracking.fromJson(Map<String, dynamic> json) {
    return MedicationTracking(
      id: json['id']?.toString(),
      prescriptionId: json['prescriptionId']?.toString() ?? '',
      patientId: json['patientId']?.toString() ?? '',
      medicineName: json['medicineName']?.toString() ?? '',
      date: json['date'] != null
          ? PakistanTimeHelper.parseUtcNullable(json['date'].toString())
          : DateTime.now().toUtc(),
      morningTaken: json['morningTaken'] ?? false,
      morningTime: json['morningTime'] != null
          ? PakistanTimeHelper.parseUtcNullable(json['morningTime'].toString())
          : null,
      afternoonTaken: json['afternoonTaken'] ?? false,
      afternoonTime: json['afternoonTime'] != null
          ? PakistanTimeHelper.parseUtcNullable(
              json['afternoonTime'].toString())
          : null,
      eveningTaken: json['eveningTaken'] ?? false,
      eveningTime: json['eveningTime'] != null
          ? PakistanTimeHelper.parseUtcNullable(json['eveningTime'].toString())
          : null,
      nightTaken: json['nightTaken'] ?? false,
      nightTime: json['nightTime'] != null
          ? PakistanTimeHelper.parseUtcNullable(json['nightTime'].toString())
          : null,
      notes: json['notes']?.toString() ?? '',
    );
  }
}

/// Active medication with today's tracking status
class ActiveMedication {
  final String prescriptionId;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String medicineName;
  final String dosage;
  final String instructions;
  final bool morning;
  final bool afternoon;
  final bool evening;
  final bool night;
  final String morningTimeUtc;
  final String afternoonTimeUtc;
  final String eveningTimeUtc;
  final String nightTimeUtc;
  final DateTime startDate;
  final DateTime endDate;
  final int daysRemaining;
  final DateTime? nextAppointmentDate;
  final MedicationTracking? todayTracking;

  ActiveMedication({
    required this.prescriptionId,
    this.doctorId = '',
    required this.doctorName,
    required this.doctorSpecialty,
    required this.medicineName,
    this.dosage = '',
    this.instructions = '',
    this.morning = false,
    this.afternoon = false,
    this.evening = false,
    this.night = false,
    this.morningTimeUtc = '',
    this.afternoonTimeUtc = '',
    this.eveningTimeUtc = '',
    this.nightTimeUtc = '',
    required this.startDate,
    required this.endDate,
    this.daysRemaining = 0,
    this.nextAppointmentDate,
    this.todayTracking,
  });

  factory ActiveMedication.fromJson(Map<String, dynamic> json) {
    return ActiveMedication(
      prescriptionId: json['prescriptionId']?.toString() ?? '',
      doctorId: json['doctorId']?.toString() ?? '',
      doctorName: json['doctorName']?.toString() ?? '',
      doctorSpecialty: json['doctorSpecialty']?.toString() ?? '',
      medicineName: json['medicineName']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
      morning: json['morning'] ?? false,
      afternoon: json['afternoon'] ?? false,
      evening: json['evening'] ?? false,
      night: json['night'] ?? false,
      morningTimeUtc: json['morningTimeUtc']?.toString() ?? '',
      afternoonTimeUtc: json['afternoonTimeUtc']?.toString() ?? '',
      eveningTimeUtc: json['eveningTimeUtc']?.toString() ?? '',
      nightTimeUtc: json['nightTimeUtc']?.toString() ?? '',
      startDate: json['startDate'] != null
          ? PakistanTimeHelper.parseUtcNullable(json['startDate'].toString())
          : DateTime.now().toUtc(),
      endDate: json['endDate'] != null
          ? PakistanTimeHelper.parseUtcNullable(json['endDate'].toString())
          : DateTime.now().toUtc(),
      daysRemaining: json['daysRemaining'] ?? 0,
      nextAppointmentDate: json['nextAppointmentDate'] != null
          ? PakistanTimeHelper.parseUtcNullable(
              json['nextAppointmentDate'].toString())
          : null,
      todayTracking: json['todayTracking'] != null
          ? MedicationTracking.fromJson(json['todayTracking'])
          : null,
    );
  }
}

class ActiveMedicationsResponse {
  final bool success;
  final String message;
  final List<ActiveMedication> data;

  ActiveMedicationsResponse({
    required this.success,
    this.message = '',
    required this.data,
  });

  factory ActiveMedicationsResponse.fromJson(Map<String, dynamic> json) {
    return ActiveMedicationsResponse(
      success: json['success'] ?? false,
      message: json['message']?.toString() ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => ActiveMedication.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SavedPrescription {
  final String? id;
  final String? patientId;
  final String? doctorId;
  final String? doctorName;
  final String? doctorSpecialty;
  final String? patientName;
  final String? prescriptionUrl;
  final String? fileType;
  final String? diagnosis;
  final String? medicines;
  final String? advice;
  final String? followUp;
  final String? prescriptionDate;
  final DateTime? createdAt;
  final List<MedicineItem> medicineItems;
  final bool isActive;

  SavedPrescription({
    this.id,
    this.patientId,
    this.doctorId,
    this.doctorName,
    this.doctorSpecialty,
    this.patientName,
    this.prescriptionUrl,
    this.fileType,
    this.diagnosis,
    this.medicines,
    this.advice,
    this.followUp,
    this.prescriptionDate,
    this.createdAt,
    this.medicineItems = const [],
    this.isActive = true,
  });

  factory SavedPrescription.fromJson(Map<String, dynamic> json) {
    return SavedPrescription(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      patientId: json['patientId']?.toString(),
      doctorId: json['doctorId']?.toString(),
      doctorName: json['doctorName']?.toString(),
      doctorSpecialty: json['doctorSpecialty']?.toString(),
      patientName: json['patientName']?.toString(),
      prescriptionUrl: json['prescriptionUrl']?.toString(),
      fileType: json['fileType']?.toString(),
      diagnosis: json['diagnosis']?.toString(),
      medicines: json['medicines']?.toString(),
      advice: json['advice']?.toString(),
      followUp: json['followUp']?.toString(),
      prescriptionDate: json['prescriptionDate']?.toString(),
      createdAt: json['createdAt'] != null
          ? PakistanTimeHelper.parseUtcNullable(json['createdAt'].toString())
          : null,
      medicineItems: (json['medicineItems'] as List<dynamic>?)
              ?.map((e) => MedicineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'patientName': patientName,
      'prescriptionUrl': prescriptionUrl,
      'fileType': fileType,
      'diagnosis': diagnosis,
      'medicines': medicines,
      'advice': advice,
      'followUp': followUp,
      'prescriptionDate': prescriptionDate,
      'createdAt': createdAt?.toIso8601String(),
      'medicineItems': medicineItems.map((e) => e.toJson()).toList(),
      'isActive': isActive,
    };
  }
}

class PrescriptionsResponse {
  final bool success;
  final List<SavedPrescription> data;
  final String? message;

  PrescriptionsResponse({
    required this.success,
    required this.data,
    this.message,
  });

  factory PrescriptionsResponse.fromJson(Map<String, dynamic> json) {
    return PrescriptionsResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List<dynamic>?)
              ?.map(
                  (e) => SavedPrescription.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      message: json['message']?.toString(),
    );
  }
}
