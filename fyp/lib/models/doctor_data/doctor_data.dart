import 'package:fyp/utils/pakistan_time_helper.dart';

// M-4 FOR SHOWING DATA OF DOCTOR IN BOOKING APPOINTMENT

class DoctorData {
  final String id;
  final String fName;
  final String lName;
  final String email;
  final String number;
  final bool isAvaialble;
  final String speciality;
  final String experience;
  final String imageUrl;
  final String fee;
  final String clinicLocation;
  final String specialization;
  final String morningStartTime;
  final String morningEndTime;
  final List<DayAvailability> dailyAvailabilities;

  const DoctorData(
      {required this.id,
      required this.fName,
      required this.lName,
      required this.email,
      required this.number,
      required this.isAvaialble,
      required this.speciality,
      required this.experience,
      required this.morningStartTime,
      required this.morningEndTime,
      required this.imageUrl,
      required this.fee,
      required this.clinicLocation,
      required this.specialization,
      required this.dailyAvailabilities});

  DoctorData copyWith(
      {String? id,
      String? fName,
      String? lName,
      String? email,
      String? number,
      bool? isAvaialble,
      String? speciality,
      String? experience,
      String? morningStartTime,
      String? morningEndTime,
      String? imageUrl,
      String? fee,
      String? clinicLocation,
      String? specialization,
      List<DayAvailability>? dailyAvailabilities}) {
    return DoctorData(
        id: id ?? this.id,
        fName: fName ?? this.fName,
        lName: lName ?? this.lName,
        email: email ?? this.email,
        number: number ?? this.number,
        isAvaialble: isAvaialble ?? this.isAvaialble,
        speciality: speciality ?? this.speciality,
        experience: experience ?? this.experience,
        morningStartTime: morningStartTime ?? this.morningStartTime,
        morningEndTime: morningEndTime ?? this.morningEndTime,
        imageUrl: imageUrl ?? this.imageUrl,
        fee: fee ?? this.fee,
        clinicLocation: clinicLocation ?? this.clinicLocation,
        specialization: specialization ?? this.specialization,
        dailyAvailabilities: dailyAvailabilities ?? this.dailyAvailabilities);
  }

  factory DoctorData.fromJson(Map<String, dynamic> json) {
    return DoctorData(
        id: json['id'] ?? '',
        fName: json['firstName'] ?? '',
        lName: json['lastName'] ?? '',
        email: json['email'] ?? '',
        number: json['whatsappNo'] ?? '',
        isAvaialble: json['isAvailable'] ?? false,
        speciality: json['speciality'] ?? '',
        experience: json['experience'] ?? '',
        morningStartTime: json['morningStartTime'] ?? '',
        morningEndTime: json['morningEndTime'] ?? '',
        imageUrl: json['imageUrl'] ?? '',
        fee: json['fee'] ?? '',
        clinicLocation: json['clinicLocation'] ?? '',
        specialization: json['specialization'] ?? '',
        dailyAvailabilities: (json['dailyAvailabilities'] as List? ?? [])
            .map((e) => DayAvailability.fromJson(e))
            .toList());
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': fName,
      'lastName': lName,
      'email': email,
      'whatsappNo': number,
      'isAvailable': isAvaialble,
      'speciality': speciality,
      'experience': experience,
      'morningStartTime': morningStartTime,
      'morningEndTime': morningEndTime,
      'imageUrl': imageUrl,
      'fee': fee,
      'clinicLocation': clinicLocation,
      'specialization': specialization,
      'dailyAvailabilites': dailyAvailabilities
    };
  }
}

class DayAvailability {
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final List<Slot> slots;

  const DayAvailability({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.slots,
  });

  factory DayAvailability.fromJson(Map<String, dynamic> json) {
    print("DayAvailability fromJson: $json");
    // Parse dates as UTC from the API, then keep them as UTC instants.
    final dateStr = json['date'] as String;
    final startStr = json['startTime'] as String;
    final endStr = json['endTime'] as String;

    final parsedDate = PakistanTimeHelper.parseUtc(dateStr);
    final parsedStart = PakistanTimeHelper.parseUtc(startStr);
    final parsedEnd = PakistanTimeHelper.parseUtc(endStr);

    print(
        "DayAvailability parsed: date=$parsedDate, start=$parsedStart, end=$parsedEnd");

    return DayAvailability(
      date: parsedDate,
      startTime: parsedStart,
      endTime: parsedEnd,
      slots: (json['slots'] as List? ?? [])
          .map((slot) => Slot.fromJson(slot))
          .toList(),
    );
  }
}

class Slot {
  final DateTime startTime;
  final DateTime endTime;
  final bool isBooked;
  final String userId;

  const Slot({
    required this.startTime,
    required this.endTime,
    required this.isBooked,
    required this.userId,
  });

  factory Slot.fromJson(Map<String, dynamic> json) {
    print("slots will be $json");
    // Parse UTC time from the API.
    final startUtc = PakistanTimeHelper.parseUtc(json['startTime'] as String);
    final endUtc = PakistanTimeHelper.parseUtc(json['endTime'] as String);
    return Slot(
      startTime: startUtc,
      endTime: endUtc,
      isBooked: json['isBooked'] ?? false,
      userId: json['userId'] ?? '',
    );
  }
}

class DoctorResponse {
  final List<DoctorData> doctors;
  final String message;
  final bool success;

  const DoctorResponse({
    required this.doctors,
    required this.message,
    required this.success,
  });

  factory DoctorResponse.fromJson(Map<String, dynamic> json) {
    return DoctorResponse(
      doctors: (json['doctorDtos'] as List? ?? [])
          .map((doctor) => DoctorData.fromJson(doctor))
          .toList(),
      message: json['message'] ?? '',
      success: json['isSuccess'] ?? false,
    );
  }
}
