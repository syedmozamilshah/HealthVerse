import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/provider/future_provider/doctor_info_provider/doctor_info_provider.dart';
import 'package:fyp/views/appointment_screen/date_time_screen/date_time_screen.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import '../../color/colors.dart';
import '../../home_screen/home_screen.dart';
import 'widget/doctor_loading_tile.dart';
import 'widget/doctor_tile.dart';
import 'package:fyp/services/referral_service/referral_service.dart';
import 'package:fyp/provider/state_notifier_provider/user_provider.dart';

class DoctorViewScreen extends ConsumerStatefulWidget {
  final String speciality;
  const DoctorViewScreen({super.key, this.speciality = 'Ophthalmologist'});

  @override
  ConsumerState<DoctorViewScreen> createState() => _DoctorViewScreenState();
}

class _DoctorViewScreenState extends ConsumerState<DoctorViewScreen> {
  bool isLoading = false;
  List<dynamic> activeReferrals = [];
  bool isLoadingReferrals = true;

  @override
  void initState() {
    super.initState();
    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(doctorInfoProvider(widget.speciality));
      _fetchActiveReferrals();
    });
  }

  Future<void> _fetchActiveReferrals() async {
    final user = ref.read(userProvider);
    final referrals = await ReferralService().getActiveReferrals(user.id);
    if (mounted) {
      setState(() {
        activeReferrals = referrals;
        isLoadingReferrals = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);
    final contentMaxWidth = ResponsiveHelper.getContentWidth(context);

    return WillPopScope(
      onWillPop: () async {
        // Refresh when user navigates back
        // M-4 GETTING THE DOCTOR INFO AGAIN WHEN USER GOES BACK TO THE SCREEN
        ref.invalidate(doctorInfoProvider(widget.speciality));
        return true; // allow back navigation
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: loginGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header with back button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 24 : 4.w,
                    vertical: isWeb ? 16 : 2.h,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const HomeScreen()),
                            (route) => false,
                          );
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: EdgeInsets.all(isWeb ? 10 : 2.w),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.arrow_back,
                                color: Colors.white, size: isWeb ? 24 : 20.sp),
                          ),
                        ),
                      ),
                      SizedBox(width: isWeb ? 20 : 4.w),
                      Text(
                        'Available Doctors',
                        style: TextStyle(
                          fontSize: isWeb ? 28 : 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          ref.invalidate(doctorInfoProvider(widget.speciality));
                        },
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: isWeb ? 28 : 22.sp,
                        ),
                      ),
                    ],
                  ),
                ),

                if (!isLoadingReferrals && activeReferrals.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWeb ? 24 : 4.w,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You have an active referral to a ${activeReferrals.first['targetSpecialty']}.',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: isWeb ? 16 : 14.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Main Content
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: Consumer(
                        builder: (context, ref, child) {
                          final data =
                              ref.watch(doctorInfoProvider(widget.speciality));

                          return data.when(
                            data: (doctor) {
                              if (doctor.success && doctor.doctors.isNotEmpty) {
                                return RefreshIndicator(
                                  onRefresh: () async {
                                    ref.invalidate(
                                        doctorInfoProvider(widget.speciality));
                                  },
                                  color: tealColor,
                                  child: ListView.builder(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isWeb ? 24 : 4.w,
                                      vertical: isWeb ? 16 : 2.h,
                                    ),
                                    itemCount: doctor.doctors.length,
                                    itemBuilder: (context, index) {
                                      final doctorInfo = doctor.doctors[index];
                                      return DoctorTile(
                                        user: doctorInfo,
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  DateTimeScreen(
                                                      doctorData: doctorInfo),
                                            ),
                                          );
                                          // Refresh after returning from detail
                                          ref.invalidate(doctorInfoProvider(
                                              widget.speciality));
                                        },
                                      );
                                    },
                                  ),
                                );
                              } else {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.medical_services_outlined,
                                        size: isWeb ? 80 : 60.sp,
                                        color: tealColor.withOpacity(0.5),
                                      ),
                                      SizedBox(height: isWeb ? 16 : 2.h),
                                      Text(
                                        'No doctors available',
                                        style: TextStyle(
                                          fontSize: isWeb ? 20 : 18.sp,
                                          fontWeight: FontWeight.w600,
                                          color: tealColor,
                                        ),
                                      ),
                                      SizedBox(height: isWeb ? 8 : 1.h),
                                      Text(
                                        'Please try again later',
                                        style: TextStyle(
                                          fontSize: isWeb ? 16 : 14.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            error: (error, stack) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: isWeb ? 80 : 60.sp,
                                      color: Colors.red.withOpacity(0.5),
                                    ),
                                    SizedBox(height: isWeb ? 16 : 2.h),
                                    Text(
                                      'Error loading doctors',
                                      style: TextStyle(
                                        fontSize: isWeb ? 20 : 18.sp,
                                        fontWeight: FontWeight.w600,
                                        color: tealColor,
                                      ),
                                    ),
                                    SizedBox(height: isWeb ? 8 : 1.h),
                                    Text(
                                      '$error',
                                      style: TextStyle(
                                        fontSize: isWeb ? 14 : 12.sp,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                            loading: () {
                              return ListView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isWeb ? 24 : 4.w,
                                  vertical: isWeb ? 16 : 2.h,
                                ),
                                itemBuilder: (context, index) {
                                  return const DoctorLoadingTile();
                                },
                                itemCount: 6,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
