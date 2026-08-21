import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/utils/pakistan_time_helper.dart';
import 'package:fyp/views/appointment_screen/date_time_screen/widget/date_slot.dart';
import 'package:fyp/views/appointment_screen/date_time_screen/widget/time_slot_chips.dart';
import 'package:fyp/views/color/colors.dart';
import 'package:fyp/views/home_screen/home_screen.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import '../../../../models/doctor_data/doctor_data.dart';
import '../../../../provider/state_notifier_provider/user_provider.dart';
import 'package:fyp/services/api_client/api_client.dart';
import 'package:fyp/provider/future_provider/doctor_info_provider/doctor_info_provider.dart';
import 'package:fyp/services/appointment_service/appointment_service.dart';

import '../../payment_screen.dart';

class DoctorDetailAppointmentTile extends ConsumerStatefulWidget {
  final DoctorData user;
  const DoctorDetailAppointmentTile({super.key, required this.user});

  @override
  ConsumerState<DoctorDetailAppointmentTile> createState() =>
      _DoctorDetailAppointmentScreenState();
}

class _DoctorDetailAppointmentScreenState
    extends ConsumerState<DoctorDetailAppointmentTile> {
  DateTime? selectedDate;
  Slot? selectedSlot;
  bool isBooking = false;
  DoctorData? _fetchedUser;

  @override
  void initState() {
    super.initState();
    _fetchedUser = widget.user;
    _initDates(_fetchedUser!);
    _fetchDoctorDetails();
  }

  Future<void> _fetchDoctorDetails() async {
    try {
      final response = await ApiClient()
          .client
          .get('/api/DoctorBasicInfo/get/${widget.user.id}');
      if (response.statusCode == 200) {
        final doctorResponse = DoctorResponse.fromJson(response.data);
        if (doctorResponse.success && doctorResponse.doctors.isNotEmpty) {
          if (mounted) {
            setState(() {
              _fetchedUser = doctorResponse.doctors.first;
              _initDates(_fetchedUser!);
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching doctor details: $e");
    }
  }

  void _initDates(DoctorData user) {
    if (user.dailyAvailabilities.isNotEmpty) {
      // Filter to get only today and future dates
      final now = PakistanTimeHelper.nowPakistan();
      final todayDateOnly = DateTime(now.year, now.month, now.day);

      print('DEBUG: Today is $todayDateOnly');
      print('DEBUG: Available dates count: ${user.dailyAvailabilities.length}');
      for (var avail in user.dailyAvailabilities) {
        print(
            'DEBUG: Available date: ${avail.date} -> DateOnly: ${DateTime(avail.date.year, avail.date.month, avail.date.day)}');
      }

      final futureDates = user.dailyAvailabilities.where((avail) {
        final pakDate = PakistanTimeHelper.toPakistanTime(avail.date);
        final dateOnly = DateTime(pakDate.year, pakDate.month, pakDate.day);
        final isValid = dateOnly.isAtSameMomentAs(todayDateOnly) ||
            dateOnly.isAfter(todayDateOnly);
        print('DEBUG: Checking $dateOnly >= $todayDateOnly = $isValid');
        return isValid;
      }).toList();

      print('DEBUG: Future dates count: ${futureDates.length}');

      if (futureDates.isNotEmpty) {
        if (selectedDate == null) {
          selectedDate = futureDates.first.date;
          print('DEBUG: Selected first date: $selectedDate');
        } else {
          // Check if selectedDate exists in new data
          bool exists = futureDates.any((d) =>
              d.date.year == selectedDate!.year &&
              d.date.month == selectedDate!.month &&
              d.date.day == selectedDate!.day);

          if (!exists) {
            selectedDate = futureDates.first.date;
            selectedSlot = null; // Reset slot
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _fetchedUser ?? widget.user;
    final isWeb = ResponsiveHelper.isWeb(context);

    DayAvailability? matchedDay;
    if (selectedDate != null) {
      matchedDay = currentUser.dailyAvailabilities.firstWhere(
        (availability) =>
            availability.date.year == selectedDate!.year &&
            availability.date.month == selectedDate!.month &&
            availability.date.day == selectedDate!.day,
        orElse: () => DayAvailability(
          date: selectedDate!,
          startTime: PakistanTimeHelper.nowPakistan(),
          endTime: PakistanTimeHelper.nowPakistan(),
          slots: [],
        ),
      );
    }

    final slotsForDay = matchedDay?.slots ?? [];
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isWeb ? 24 : 6.w)),
      elevation: 0.2,
      margin: EdgeInsets.symmetric(
          vertical: isWeb ? 12 : 2.h, horizontal: isWeb ? 16 : 4.w),
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 24 : 6.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: isWeb ? 40 : 9.w,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: NetworkImage(currentUser.imageUrl),
                ),
                SizedBox(width: isWeb ? 20 : 5.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Dr. ${currentUser.fName.toUpperCase()} ${currentUser.lName.toUpperCase()}",
                        style: TextStyle(
                          fontSize: isWeb ? 24 : 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Consultation",
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        currentUser.fee.isNotEmpty
                            ? "Fee: ${currentUser.fee} PKR"
                            : "Fee: Not Available",
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            DateSlot(
              availableDates: currentUser.dailyAvailabilities
                  .map((availability) => availability.date)
                  .where((date) {
                // Filter out past dates - only show today and future dates
                final pakNow = PakistanTimeHelper.nowPakistan();
                final todayDateOnly =
                    DateTime(pakNow.year, pakNow.month, pakNow.day);
                final pakDate = PakistanTimeHelper.toPakistanTime(date);
                final dateOnly =
                    DateTime(pakDate.year, pakDate.month, pakDate.day);
                return dateOnly.isAtSameMomentAs(todayDateOnly) ||
                    dateOnly.isAfter(todayDateOnly);
              }).toList(),
              onDateSelection: (date) {
                setState(() {
                  selectedDate = date;
                  selectedSlot = null; // Reset slot when date changes
                });
                print('Selected Date: $date');
              },
            ),
            SizedBox(height: 4.w),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(Icons.event_available_outlined,
                    color: tealColor, size: 20.sp),
                SizedBox(width: 2.w),
                Text(
                  "Consultation",
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            TimeSlotSelector(
              dailyOne: slotsForDay,
              onSlotSelected: (slot) {
                setState(() {
                  selectedSlot = slot;
                });
              },
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, color: tealColor, size: 20.sp),
                SizedBox(width: 2.w),
                Text(
                  currentUser.clinicLocation.isNotEmpty
                      ? currentUser.clinicLocation
                      : "Clinic Location Not Available",
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  fixedSize: Size(100.w, 7.h),
                  backgroundColor: tealColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: () async {
                  // Validate slot selection

                  if (selectedSlot == null) {
                    reusableSnackBar(context, "Please select a time slot");
                    return;
                  }

                  if (selectedDate == null) {
                    reusableSnackBar(context, "Please select a date");
                    return;
                  }

                  final user = ref.watch(userProvider);

                  // Validate user and doctor IDs
                  if (user.id.isEmpty) {
                    reusableSnackBar(
                        context, "User session expired. Please login again.");
                    return;
                  }

                  if (currentUser.id.isEmpty) {
                    reusableSnackBar(context,
                        "Invalid doctor information. Please try again.");
                    return;
                  }

                  // Show loading indicator
                  setState(() {
                    isBooking = true;
                  });

                  // Check if patient already has a booking with this doctor on selected date
                  final appointmentService = AppointmentService();
                  final hasExistingBooking =
                      await appointmentService.hasExistingBookingForDate(
                    doctorId: currentUser.id,
                    selectedDate: selectedDate!,
                  );

                  if (hasExistingBooking) {
                    setState(() {
                      isBooking = false;
                    });
                    if (context.mounted) {
                      reusableSnackBar(
                        context,
                        "You already have a booking with this doctor for the selected date. Please choose a different date.",
                      );
                    }
                    return;
                  }

                  setState(() {
                    isBooking = false;
                  });

                  // Parse the fee amount
                  int feeAmount = 0;
                  try {
                    final feeString =
                        currentUser.fee.replaceAll(RegExp(r'[^0-9]'), '');
                    feeAmount = int.tryParse(feeString) ?? 0;
                    debugPrint(
                        'Parsed fee amount: $feeAmount from ${currentUser.fee}');
                  } catch (e) {
                    debugPrint('Error parsing fee: $e');
                  }

                  if (feeAmount > 0) {
                    // Navigate to payment screen
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentScreen(
                            patientId: user.id,
                            doctorId: currentUser.id,
                            doctorName:
                                '${currentUser.fName} ${currentUser.lName}',
                            amount: feeAmount,
                            currency: 'pkr',
                            appointmentDate: selectedDate!,
                            slotStartTime: selectedSlot?.startTime,
                            slotEndTime: selectedSlot?.endTime,
                            onPaymentComplete: (success) async {
                              if (success) {
                                // Create appointment after successful payment
                                await _createAppointment(user.id);
                              }
                            },
                          ),
                        ),
                      );
                    }
                  } else {
                    // No fee, create appointment directly
                    await _createAppointment(user.id);
                  }
                },
                child: isBooking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        currentUser.fee.isNotEmpty && currentUser.fee != '0'
                            ? "Pay & Confirm (${currentUser.fee} PKR)"
                            : "Confirm Appointment",
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAppointment(String patientId) async {
    final currentUser = _fetchedUser ?? widget.user;
    setState(() {
      isBooking = true;
    });

    try {
      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(tealColor),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Booking Appointment...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }

      print('=== Booking Appointment ===');
      print('Patient ID: $patientId');
      print('Doctor ID: ${currentUser.id}');
      print('Selected Date Local: $selectedDate');
      print('Selected Slot Start Local: ${selectedSlot?.startTime}');

      // final prefs = await SharedPreferences.getInstance();
      // final token = prefs.getString('token');

      // if (token == null || token.isEmpty) {
      //   reusableSnackBar(
      //       context, "Session expired. Please login again.");
      //   return;
      // }

      // print('Token exists: ${token.substring(0, 20)}...');

      // Create appointment date at noon UTC to prevent date shifting
      final appointmentDateUtc = DateTime.utc(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        12, // noon
      );

      final slotStartUtc = selectedSlot!.startTime.toUtc();
      final slotEndUtc = selectedSlot!.endTime.toUtc();

      print('Sending Appointment Date UTC: $appointmentDateUtc');
      print('Sending Slot Start UTC: $slotStartUtc');
      print('Sending Slot End UTC: $slotEndUtc');

      final ApiClient apiClient = ApiClient();

      final response = await apiClient.client.post(
        '/api/Appointment/create',
        data: {
          'diagnosis': "",
          'assignedDoctor': currentUser.fName,
          'appointmentDate': appointmentDateUtc.toIso8601String(),
          'lastVisitDate': DateTime.now().toUtc().toIso8601String(),
          'doctorId': currentUser.id,
          'patientId': patientId,
          'status': 'confirmed',
          'slotStartTime': slotStartUtc.toIso8601String(),
          'slotEndTime': slotEndUtc.toIso8601String(),
          'symptoms': [
            {
              'description': '',
              'duration': '',
            },
            {
              'description': '',
              'duration': '',
            },
          ],
          'prescription': [
            {
              'medicineName': '',
              'dosage': '',
              'frequency': '',
              'duration': '',
              'instructions': '',
            }
          ],
        },
        options: Options(
          validateStatus: (status) {
            // Accept all status codes to handle them manually
            return status != null && status < 500;
          },
        ),
      );

      // final response = await HttpHelper.post(
      //   url,
      //   contentType: 'application/json',
      //   authorization: 'Bearer $token',
      //   body: jsonEncode({
      //     'diagnosis': "",
      //     'assignedDoctor': widget.user.fName,
      //     'appointmentDate': appointmentDateUtc.toIso8601String(),
      //     'lastVisitDate': DateTime.now().toUtc().toIso8601String(),
      //     'doctorId': widget.user.id,
      //     'patientId': user.id,
      //     'status': 'pending',
      //     'slotStartTime': slotStartUtc.toIso8601String(),
      //     'slotEndTime': slotEndUtc.toIso8601String(),
      //     'symptoms': [
      //       {
      //         'description': '',
      //         'duration': '',
      //       },
      //       {
      //         'description': '',
      //         'duration': '',
      //       },
      //     ],
      //     'prescription': [
      //       {
      //         'medicineName': '',
      //         'dosage': '',
      //         'frequency': '',
      //         'duration': '',
      //         'instructions': '',
      //       }
      //     ],
      //   }),
      // );

      // Check response for error messages
      if (response.statusCode == 400 ||
          response.statusCode == 404 ||
          response.statusCode == 401) {
        // Dismiss loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        String message = 'Booking failed';
        try {
          // Try to extract message from response
          if (response.data is String) {
            final responseBody = jsonDecode(response.data);
            message =
                responseBody['Message'] ?? responseBody['message'] ?? message;
          } else if (response.data is Map) {
            message =
                response.data['Message'] ?? response.data['message'] ?? message;
          }
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }

        if (context.mounted) {
          reusableSnackBar(context, message);
        }
        return;
      }

      // Check if appointment was created successfully
      if (response.statusCode != 200 && response.statusCode != 201) {
        // Dismiss loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        debugPrint(
            'Appointment creation failed: ${response.statusCode} - ${response.data}');
        if (context.mounted) {
          reusableSnackBar(context,
              'Failed to book appointment. Status: ${response.statusCode}');
        }
        return;
      }

      debugPrint('Appointment created successfully: ${response.data}');

      // Dismiss loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Invalidate doctor provider to refresh slot data
      ref.invalidate(doctorInfoProvider(currentUser.speciality));

      // Show success dialog
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: tealColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: tealColor,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Appointment Confirmed!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: tealColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your appointment with Dr. ${currentUser.fName} ${currentUser.lName} has been scheduled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    () {
                      final pakDate = selectedDate != null
                          ? PakistanTimeHelper.toPakistanTime(selectedDate!)
                          : null;
                      final pakSlot = selectedSlot?.startTime != null
                          ? PakistanTimeHelper.toPakistanTime(selectedSlot!.startTime)
                          : null;
                      final dateStr = pakDate != null
                          ? '${pakDate.day}/${pakDate.month}/${pakDate.year}'
                          : '';
                      final timeStr = pakSlot != null
                          ? '${pakSlot.hour}:${pakSlot.minute.toString().padLeft(2, '0')}'
                          : '';
                      return '$dateStr at $timeStr';
                    }(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true)
                            .pop(); // close dialog

                        Navigator.of(context, rootNavigator: true)
                            .pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
      print("Appointment Confirmed");
    } on DioException catch (dioError) {
      debugPrint('DioException creating appointment: ${dioError.message}');
      debugPrint('DioException response: ${dioError.response?.data}');
      debugPrint('DioException status: ${dioError.response?.statusCode}');

      // Dismiss loading dialog if it's showing
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
      }

      String errorMessage = 'Error creating appointment';

      // Extract error message from DioException
      if (dioError.response != null) {
        try {
          var responseData = dioError.response!.data;
          if (responseData is String) {
            final decoded = jsonDecode(responseData);
            errorMessage =
                decoded['Message'] ?? decoded['message'] ?? errorMessage;
          } else if (responseData is Map) {
            errorMessage = responseData['Message'] ??
                responseData['message'] ??
                errorMessage;
          }
        } catch (e) {
          errorMessage =
              'Status ${dioError.response!.statusCode}: ${dioError.response!.statusMessage ?? 'Unknown error'}';
        }
      } else if (dioError.message != null) {
        errorMessage = dioError.message!;
      }

      if (context.mounted) {
        reusableSnackBar(context, errorMessage);
      }
    } catch (e) {
      debugPrint('Error creating appointment: $e');

      // Dismiss loading dialog if it's showing
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
      }

      if (context.mounted) {
        reusableSnackBar(context, 'Error: $e');
      }
    } finally {
      setState(() {
        isBooking = false;
      });
    }
  }
}
