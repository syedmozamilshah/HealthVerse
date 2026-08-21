import 'package:fyp/utils/pakistan_time_helper.dart';

// M-6 USED IN VITALS PAGE TO DISPLAY VITALS DATA
class PatientRecord {
  final String id;
  final String allergy;
  final String history;
  final String initialConditions;
  final bool isVerified;
  final String personalInfoId;
  final Vitals vitals;

  PatientRecord({
    required this.id,
    required this.allergy,
    required this.history,
    required this.initialConditions,
    required this.isVerified,
    required this.personalInfoId,
    required this.vitals,
  });

  factory PatientRecord.fromJson(Map<String, dynamic> json) {
    return PatientRecord(
      id: json['_id'] ?? '',
      allergy: json['allergy'] ?? '',
      history: json['history'] ?? '',
      initialConditions: json['initial_conditions'] ?? '',
      isVerified: json['is_verified'] ?? false,
      personalInfoId: json['personal_info_id']?['\$oid'] ?? '',
      vitals: Vitals.fromJson(json['vitals'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'allergy': allergy,
      'history': history,
      'initial_conditions': initialConditions,
      'is_verified': isVerified,
      'personal_info_id': personalInfoId,
      'vitals': vitals.toJson(),
    };
  }
}

class Vitals {
  final List<BloodPressure> bloodPressure;
  final List<Sugar> sugarLevel;
  final DateTime lastUpdated;

  Vitals(
      {required this.bloodPressure,
      required this.sugarLevel,
      required this.lastUpdated});

  factory Vitals.fromJson(Map<String, dynamic> json) {
    print(json['lastUpdated']);
    return Vitals(
      bloodPressure: (json['bloodPressure'] as List<dynamic>? ?? [])
          .map((e) => BloodPressure.fromJson(e))
          .toList(),
      sugarLevel: (json['sugarLevel'] as List<dynamic>? ?? [])
          .map((e) => Sugar.fromJson(e))
          .toList(),
      lastUpdated: json['lastUpdated'] is Map
          ? PakistanTimeHelper.parseUtcNullable(
              json['lastUpdated']['\$date']?.toString(),
              fallback: DateTime.now().toUtc(),
            )
          : PakistanTimeHelper.parseUtcNullable(
              json['lastUpdated']?.toString(),
              fallback: DateTime.now().toUtc(),
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blood_pressure': bloodPressure.map((e) => e.toJson()).toList(),
      'sugar': sugarLevel.map((e) => e.toJson()).toList(),
    };
  }
}

class BloodPressure {
  int? systolic;
  int? diastolic;
  DateTime date;

  BloodPressure({
    this.systolic,
    this.diastolic,
    required this.date,
  });

  factory BloodPressure.fromJson(Map<String, dynamic> json) {
    return BloodPressure(
      systolic:
          json['systolic'] != null && json['systolic'].toString().isNotEmpty
              ? int.tryParse(json['systolic'].toString())
              : null,
      diastolic:
          json['diastolic'] != null && json['diastolic'].toString().isNotEmpty
              ? int.tryParse(json['diastolic'].toString())
              : null,
      date: json['date'] is Map
          ? PakistanTimeHelper.parseUtcNullable(
              json['date']['\$date']?.toString(),
              fallback: DateTime.now().toUtc(),
            )
          : PakistanTimeHelper.parseUtcNullable(
              json['date']?.toString(),
              fallback: DateTime.now().toUtc(),
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (systolic != null) 'systolic': systolic,
      if (diastolic != null) 'diastolic': diastolic,
      'date': date.toIso8601String(),
    };
  }
}

class Sugar {
  double? fasting;
  double? afterTwoHours;
  double? random;
  DateTime date;

  Sugar({
    this.fasting,
    this.afterTwoHours,
    this.random,
    required this.date,
  });

  factory Sugar.fromJson(Map<String, dynamic> json) {
    return Sugar(
      fasting: json['fasting'] != null && json['fasting'].toString().isNotEmpty
          ? double.tryParse(json['fasting'].toString())
          : null,
      afterTwoHours: json['after_two_hours'] != null &&
              json['after_two_hours'].toString().isNotEmpty
          ? double.tryParse(json['after_two_hours'].toString())
          : null,
      random: json['random'] != null && json['random'].toString().isNotEmpty
          ? double.tryParse(json['random'].toString())
          : null,
      date: json['date'] is Map
          ? PakistanTimeHelper.parseUtcNullable(
              json['date']['\$date']?.toString(),
              fallback: DateTime.now().toUtc(),
            )
          : PakistanTimeHelper.parseUtcNullable(
              json['date']?.toString(),
              fallback: DateTime.now().toUtc(),
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (fasting != null) 'fasting': fasting,
      if (afterTwoHours != null) 'after_two_hours': afterTwoHours,
      if (random != null) 'random': random,
      'date': date.toIso8601String(),
    };
  }
}

class PatientResponse {
  final PatientRecord patient;
  final String message;
  final bool success;

  const PatientResponse({
    required this.patient,
    required this.message,
    required this.success,
  });

  factory PatientResponse.fromJson(Map<String, dynamic> json) {
    return PatientResponse(
      patient: (json['patientModel']) != null
          ? PatientRecord.fromJson(json['patientModel'])
          : PatientRecord(
              id: '',
              allergy: '',
              history: '',
              initialConditions: '',
              isVerified: false,
              personalInfoId: '',
              vitals: Vitals(
                bloodPressure: [],
                sugarLevel: [],
                lastUpdated: DateTime.now().toUtc(),
              ),
            ),
      message: json['message'] ?? '',
      success: json['isSuccess'] ?? false,
    );
  }
}

class VitalResponse {
  final Vitals vitals;
  final String message;
  final bool success;

  const VitalResponse({
    required this.vitals,
    required this.message,
    required this.success,
  });

  factory VitalResponse.fromJson(Map<String, dynamic> json) {
    return VitalResponse(
      vitals: (json['vitals']) != null
          ? Vitals.fromJson(json['vitals'])
          : Vitals(
              bloodPressure: [],
              sugarLevel: [],
              lastUpdated: DateTime.now().toUtc(),
            ),
      message: json['message'] ?? '',
      success: json['isSuccess'] ?? false,
    );
  }
}
