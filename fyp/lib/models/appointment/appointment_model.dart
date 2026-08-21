import 'package:fyp/utils/pakistan_time_helper.dart';

/// Model for patient appointments fetched from the API
///
/// M-4 FOR MANAGING APPOINTMENTS
class PatientAppointment {
  final String id;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String doctorImageUrl;
  final DateTime appointmentDate;
  final DateTime? slotStartTime;
  final DateTime? slotEndTime;
  final String status;
  final String diagnosis;
  final List<AppointmentSymptom> symptoms;
  final List<AppointmentMedicine> prescriptions;

  PatientAppointment({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorImageUrl,
    required this.appointmentDate,
    this.slotStartTime,
    this.slotEndTime,
    required this.status,
    required this.diagnosis,
    required this.symptoms,
    required this.prescriptions,
  });

  factory PatientAppointment.fromJson(Map<String, dynamic> json) {
    return PatientAppointment(
      id: json['id']?.toString() ?? '',
      doctorId: json['doctorId']?.toString() ?? '',
      doctorName: json['doctorName']?.toString() ?? 'Unknown Doctor',
      doctorSpecialty: json['doctorSpecialty']?.toString() ?? '',
      doctorImageUrl: json['doctorImageUrl']?.toString() ?? '',
      appointmentDate: PakistanTimeHelper.parseUtcNullable(
        json['appointmentDate']?.toString(),
        fallback: DateTime.now().toUtc(),
      ),
      slotStartTime: json['slotStartTime'] != null
          ? PakistanTimeHelper.parseUtcNullable(
              json['slotStartTime'].toString())
          : null,
      slotEndTime: json['slotEndTime'] != null
          ? PakistanTimeHelper.parseUtcNullable(json['slotEndTime'].toString())
          : null,
      status: json['status']?.toString() ?? '',
      diagnosis: json['diagnosis']?.toString() ?? '',
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((s) => AppointmentSymptom.fromJson(s))
              .toList() ??
          [],
      prescriptions: (json['prescriptions'] as List<dynamic>?)
              ?.map((p) => AppointmentMedicine.fromJson(p))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'doctorImageUrl': doctorImageUrl,
      'appointmentDate': appointmentDate.toIso8601String(),
      'slotStartTime': slotStartTime?.toIso8601String(),
      'slotEndTime': slotEndTime?.toIso8601String(),
      'status': status,
      'diagnosis': diagnosis,
      'symptoms': symptoms.map((s) => s.toJson()).toList(),
      'prescriptions': prescriptions.map((p) => p.toJson()).toList(),
    };
  }

  /// Check if appointment is upcoming (in the future).
  /// Uses slotStartTime (the actual appointment time) when available so morning
  /// slots stay "upcoming" until the actual start time, rather than flipping
  /// to past at 00:00 based on appointmentDate (stored as noon UTC).
  bool get isUpcoming {
    final reference =
        PakistanTimeHelper.toPakistanTime(slotStartTime ?? appointmentDate);
    return reference.isAfter(PakistanTimeHelper.nowPakistan());
  }

  /// Check if appointment is today
  bool get isToday {
    return PakistanTimeHelper.isSamePakistanDate(
      appointmentDate,
      PakistanTimeHelper.nowPakistan(),
    );
  }

  /// Check if appointment is completed
  bool get isCompleted => status.toLowerCase() == 'completed';

  /// Check if appointment is cancelled
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  /// Get formatted date string
  String get formattedDate {
    return PakistanTimeHelper.formatPakistanTime(
        appointmentDate, 'd MMM, yyyy');
  }

  /// Get formatted time string
  String get formattedTime {
    if (slotStartTime == null) return 'Time not set';
    return PakistanTimeHelper.formatPakistanTime(slotStartTime!, 'h:mm a');
  }
}

/// Model for appointment symptoms
class AppointmentSymptom {
  final String description;
  final String duration;

  AppointmentSymptom({
    required this.description,
    required this.duration,
  });

  factory AppointmentSymptom.fromJson(Map<String, dynamic> json) {
    return AppointmentSymptom(
      description: json['description']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'duration': duration,
    };
  }
}

/// Model for medicines prescribed in an appointment
class AppointmentMedicine {
  final String medicineName;
  final String dosage;
  final String frequency;
  final String duration;
  final String instructions;

  AppointmentMedicine({
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.instructions,
  });

  factory AppointmentMedicine.fromJson(Map<String, dynamic> json) {
    return AppointmentMedicine(
      medicineName: json['medicineName']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
    };
  }

  /// Parse frequency into morning/afternoon/evening/night schedule
  MedicineSchedule get schedule {
    final freq = frequency.toLowerCase();
    return MedicineSchedule(
      morning: freq.contains('morning') ||
          freq.contains('od') ||
          freq.contains('bid') ||
          freq.contains('tid') ||
          freq.contains('qid') ||
          freq.contains('daily') ||
          freq.contains('once'),
      afternoon: freq.contains('afternoon') ||
          freq.contains('bid') ||
          freq.contains('tid') ||
          freq.contains('qid'),
      evening: freq.contains('evening') ||
          freq.contains('tid') ||
          freq.contains('qid'),
      night: freq.contains('night') ||
          freq.contains('bed') ||
          freq.contains('hs') ||
          freq.contains('qid'),
    );
  }

  /// Parse duration to get end date from start date
  DateTime getEndDate(DateTime startDate) {
    final dur = duration.toLowerCase();
    int days = 7; // default 7 days

    // Try to extract number from duration
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(dur);
    if (match != null) {
      final number = int.tryParse(match.group(1)!) ?? 7;
      if (dur.contains('week')) {
        days = number * 7;
      } else if (dur.contains('month')) {
        days = number * 30;
      } else {
        days = number; // assume days
      }
    }

    return startDate.add(Duration(days: days));
  }

  /// Check if medicine is still active (should still be taken)
  bool isActive(DateTime prescriptionDate) {
    final endDate = getEndDate(prescriptionDate);
    return PakistanTimeHelper.nowPakistan().isBefore(
      PakistanTimeHelper.toPakistanTime(endDate),
    );
  }
}

/// Schedule model for medicine timing
class MedicineSchedule {
  final bool morning;
  final bool afternoon;
  final bool evening;
  final bool night;

  MedicineSchedule({
    this.morning = false,
    this.afternoon = false,
    this.evening = false,
    this.night = false,
  });

  String get displayText {
    List<String> times = [];
    if (morning) times.add('Morning');
    if (afternoon) times.add('Afternoon');
    if (evening) times.add('Evening');
    if (night) times.add('Night');
    return times.isEmpty ? 'As directed' : times.join(', ');
  }

  int get timesPerDay {
    int count = 0;
    if (morning) count++;
    if (afternoon) count++;
    if (evening) count++;
    if (night) count++;
    return count == 0 ? 1 : count;
  }
}

/// Response model for appointments API
class AppointmentsResponse {
  final bool isSuccess;
  final String message;
  final List<PatientAppointment> data;

  AppointmentsResponse({
    required this.isSuccess,
    required this.message,
    required this.data,
  });

  factory AppointmentsResponse.fromJson(Map<String, dynamic> json) {
    return AppointmentsResponse(
      isSuccess: json['isSuccess'] ?? false,
      message: json['message']?.toString() ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((a) => PatientAppointment.fromJson(a))
              .toList() ??
          [],
    );
  }
}

/// Model for active medication tracking on home screen
class ActiveMedication {
  final String medicineName;
  final String dosage;
  final MedicineSchedule schedule;
  final String instructions;
  final DateTime startDate;
  final DateTime endDate;
  final String doctorName;
  final String appointmentId;

  ActiveMedication({
    required this.medicineName,
    required this.dosage,
    required this.schedule,
    required this.instructions,
    required this.startDate,
    required this.endDate,
    required this.doctorName,
    required this.appointmentId,
  });

  /// Days remaining until medication ends
  int get daysRemaining {
    final remaining = PakistanTimeHelper.toPakistanTime(endDate)
        .difference(PakistanTimeHelper.nowPakistan())
        .inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// Progress percentage (0.0 to 1.0)
  double get progress {
    final totalDays = endDate.difference(startDate).inDays;
    final elapsed = PakistanTimeHelper.nowPakistan()
        .difference(PakistanTimeHelper.toPakistanTime(startDate))
        .inDays;
    if (totalDays <= 0) return 1.0;
    final prog = elapsed / totalDays;
    return prog > 1.0 ? 1.0 : (prog < 0 ? 0 : prog);
  }

  /// Check if medication is still active
  bool get isActive => PakistanTimeHelper.nowPakistan()
      .isBefore(PakistanTimeHelper.toPakistanTime(endDate));
}
