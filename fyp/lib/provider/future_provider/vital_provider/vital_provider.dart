import 'dart:core';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/services/vital_service/vital_service.dart';

final vitalInfoProvider = FutureProvider((ref) async {
  final patientService = VitalService();

  final result = await patientService.getPatientData();
  print(result.vitals.bloodPressure);
  print(result.vitals.sugarLevel);
  return result;
});
