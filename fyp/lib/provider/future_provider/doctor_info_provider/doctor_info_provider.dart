import 'dart:core';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/models/doctor_data/doctor_data.dart';

import '../../../services/symptoms_question_service/doctor_service/doctor_service.dart';

// M-4 USED IN STORING DOCTOR INFO IN THE APP

final doctorInfoProvider =
    FutureProvider.family<DoctorResponse, String>((ref, speciality) async {
  final doctorService = DoctorService();

  print(speciality);
  final result = await doctorService.getAvailableDoctor(speciality);
  return result;
});
