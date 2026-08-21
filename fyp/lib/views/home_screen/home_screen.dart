import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/models/appointment/appointment_model.dart';
import 'package:fyp/models/vital_data/vital_data.dart';
import 'package:fyp/provider/state_notifier_provider/user_provider.dart';
import 'package:fyp/services/appointment_service/appointment_service.dart';
import 'package:fyp/services/vital_service/vital_service.dart';
import 'package:fyp/views/appointment_screen/appointment_symptoms.dart';
import 'package:fyp/views/profile_screen/profile_screen.dart';
import 'package:fyp/views/vital_screen/log_vitals_screen.dart';
import 'package:fyp/views/vital_screen/vitals_history_screen.dart';
import 'package:fyp/views/prescriptions_screen/prescriptions_screen.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:fyp/services/referral_service/referral_service.dart';
import 'package:fyp/widgets/medication_tracking_widget.dart';
import 'package:fyp/widgets/medication_history_graph.dart';
import 'package:fyp/views/appointment_screen/doctor_view_screen/doctor_view_screen.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import '../color/colors.dart';
import '../navigation/main_navigation.dart';

// This is the main HomeScreen that wraps with navigation
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigation(initialIndex: 0);
  }
}

// This is the actual home content without navigation wrapper
class HomeScreenContent extends ConsumerStatefulWidget {
  const HomeScreenContent({super.key});

  @override
  ConsumerState<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends ConsumerState<HomeScreenContent>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final AppointmentService _appointmentService = AppointmentService();
  final VitalService _vitalService = VitalService();

  // Data states
  List<PatientAppointment> _upcomingAppointments = [];
  List<PatientAppointment> _pastAppointments = [];
  List<ActiveMedication> _activeMedications = [];
  List<ActiveMedication> _pastMedications = [];
  List<dynamic> _activeReferrals = [];
  Vitals? _vitals;
  bool _isLoading = true;
  // ignore_for_file: unused_field
  String? _error;
  AnimationController? _shimmerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _shimmerController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = ref.read(userProvider);
      final results = await Future.wait([
        _appointmentService.getUpcomingAppointments(),
        _appointmentService.getPastAppointments(),
        _appointmentService.getActiveMedications(),
        _appointmentService.getPastMedications(),
        _vitalService.getPatientData(),
        ReferralService().getActiveReferrals(user.id),
      ]);

      setState(() {
        _upcomingAppointments = results[0] as List<PatientAppointment>;
        _pastAppointments = results[1] as List<PatientAppointment>;
        _activeMedications = results[2] as List<ActiveMedication>;
        _pastMedications = results[3] as List<ActiveMedication>;
        final vitalResponse = results[4] as VitalResponse;
        if (vitalResponse.success) {
          _vitals = vitalResponse.vitals;
        }
        _activeReferrals = results[5] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void navigateToAppointment() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const AppointmentSymptoms()));
  }

  void navigateToVitalScreen() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const LogVitalsScreen()));
  }

  void navigateToPrescriptions() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const PrescriptionsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);
    final contentMaxWidth = ResponsiveHelper.getContentWidth(context);

    return Scaffold(
      backgroundColor: lightTealColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isWeb ? 70 : 60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: tealColor.withOpacity(0.9),
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tealColor,
                      tealColor.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              title: Consumer(
                builder: (context, ref, child) {
                  final user = ref.watch(userProvider);
                  return Text(
                    "Welcome ${user.fName}",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: isWeb ? 18 : 17.sp,
                      letterSpacing: 0.3,
                    ),
                  );
                },
              ),
              actions: [
                Consumer(
                  builder: (context, ref, child) {
                    final user = ref.watch(userProvider);
                    return Padding(
                      padding: EdgeInsets.only(right: isWeb ? 16 : 3.w),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: isWeb ? 18 : 4.w,
                            backgroundColor: Colors.white,
                            backgroundImage: user.imageUrl.isNotEmpty
                                ? NetworkImage(user.imageUrl)
                                : null,
                            child: user.imageUrl.isEmpty
                                ? Icon(Icons.person,
                                    size: isWeb ? 20 : 4.w, color: tealColor)
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: tealColor,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child:
                  _isLoading ? _buildLoadingState(isWeb) : _buildContent(isWeb),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isWeb) {
    Widget shimmerBox({double? height, double? width, double radius = 8}) {
      final anim = _shimmerController ?? AlwaysStoppedAnimation(0.0);
      return AnimatedBuilder(
        animation: anim,
        builder: (context, child) {
          final value = anim.value;
          final baseColor = Theme.of(context).cardColor.withOpacity(0.95);
          final highlightColor = Theme.of(context).cardColor.withOpacity(0.7);
          final effectiveRadius =
              (height != null && height > 0) ? height / 2 : radius;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(effectiveRadius),
            ),
            child: ShaderMask(
              shaderCallback: (rect) {
                final dx = rect.width * (-1 + 2 * value);
                return LinearGradient(
                  colors: [baseColor, highlightColor, baseColor],
                  stops: const [0.1, 0.5, 0.9],
                ).createShader(
                    Rect.fromLTWH(dx, 0, rect.width * 2, rect.height));
              },
              blendMode: BlendMode.srcATop,
              child: Container(color: baseColor),
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(
          left: isWeb ? 24 : 4.w,
          right: isWeb ? 24 : 4.w,
          top: isWeb ? 24 : 8.h,
          bottom: isWeb ? 24 : 4.w,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Access (three shimmer cards)
            Row(
              children: [
                Expanded(
                    child: shimmerBox(height: isWeb ? 110 : 12.h, radius: 16)),
                SizedBox(width: isWeb ? 12 : 2.w),
                Expanded(
                    child: shimmerBox(height: isWeb ? 110 : 12.h, radius: 16)),
                SizedBox(width: isWeb ? 12 : 2.w),
                Expanded(
                    child: shimmerBox(height: isWeb ? 110 : 12.h, radius: 16)),
              ],
            ),
            SizedBox(height: isWeb ? 28 : 3.h),

            // Vitals tile (two small boxes)
            Row(
              children: [
                Expanded(
                    child: shimmerBox(height: isWeb ? 120 : 12.h, radius: 12)),
                SizedBox(width: isWeb ? 12 : 3.w),
                Expanded(
                    child: shimmerBox(height: isWeb ? 120 : 12.h, radius: 12)),
              ],
            ),
            SizedBox(height: isWeb ? 28 : 3.h),

            // Upcoming appointments (three list item placeholders)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shimmerBox(
                    height: isWeb ? 20 : 3.h,
                    width: isWeb ? 200 : null,
                    radius: 6),
                SizedBox(height: isWeb ? 12 : 1.5.h),
                ...List.generate(
                    3,
                    (i) => Padding(
                          padding: EdgeInsets.only(bottom: isWeb ? 12 : 1.5.h),
                          child:
                              shimmerBox(height: isWeb ? 88 : 12.h, radius: 16),
                        )),
              ],
            ),
            SizedBox(height: isWeb ? 28 : 3.h),

            // Active medications (two cards)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shimmerBox(
                    height: isWeb ? 20 : 3.h,
                    width: isWeb ? 200 : null,
                    radius: 6),
                SizedBox(height: isWeb ? 12 : 1.5.h),
                ...List.generate(
                    2,
                    (i) => Padding(
                          padding: EdgeInsets.only(bottom: isWeb ? 12 : 1.5.h),
                          child:
                              shimmerBox(height: isWeb ? 88 : 12.h, radius: 16),
                        )),
              ],
            ),
            SizedBox(height: isWeb ? 28 : 3.h),

            // Past appointments (two small placeholders)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shimmerBox(
                    height: isWeb ? 20 : 3.h,
                    width: isWeb ? 200 : null,
                    radius: 6),
                SizedBox(height: isWeb ? 12 : 1.5.h),
                ...List.generate(
                    2,
                    (i) => Padding(
                          padding: EdgeInsets.only(bottom: isWeb ? 12 : 1.5.h),
                          child:
                              shimmerBox(height: isWeb ? 88 : 12.h, radius: 16),
                        )),
              ],
            ),

            SizedBox(height: isWeb ? 100 : 14.h),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isWeb) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(
          left: isWeb ? 24 : 4.w,
          right: isWeb ? 24 : 4.w,
          top: isWeb ? 24 : 8.h,
          bottom: isWeb ? 24 : 4.w,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_activeReferrals.isNotEmpty) ...[
              SizedBox(height: isWeb ? 28 : 5.h),
              _buildReferralBanner(isWeb, _activeReferrals.first),
              SizedBox(height: isWeb ? 28 : 3.h),
            ],

            // Quick Access Cards
            _buildQuickAccessSection(isWeb),
            SizedBox(height: isWeb ? 28 : 3.h),

            // Health Vitals Graph Section
            _buildVitalsGraphSection(isWeb),
            SizedBox(height: isWeb ? 28 : 3.h),

            // Upcoming Appointments Section
            _buildUpcomingAppointmentsSection(isWeb),
            SizedBox(height: isWeb ? 28 : 3.h),

            // Active Medications Section with Tracking
            Consumer(
              builder: (context, ref, child) {
                final user = ref.watch(userProvider);
                return MedicationTrackingWidget(
                  patientId: user.id,
                  primaryColor: tealColor,
                  darkColor: darkTealColor,
                );
              },
            ),
            SizedBox(height: isWeb ? 28 : 3.h),

            // Medication History Graph
            Consumer(
              builder: (context, ref, child) {
                final user = ref.watch(userProvider);
                return MedicationHistoryGraph(
                  patientId: user.id,
                  primaryColor: tealColor,
                  darkColor: darkTealColor,
                  days: 7,
                );
              },
            ),
            SizedBox(height: isWeb ? 28 : 3.h),

            // Past Appointments Section
            _buildPastAppointmentsSection(isWeb),

            // Bottom padding for nav bar
            SizedBox(height: isWeb ? 100 : 14.h),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralBanner(bool isWeb, dynamic referral) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DoctorViewScreen(
                speciality: referral['targetSpecialty'] ?? 'Optometrist'),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade400, width: 2),
        ),
        child: Row(
          children: [
            Icon(Icons.assignment_ind, color: Colors.amber.shade800, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Referral',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: isWeb ? 16 : 16.sp,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You have been referred to a ${referral['targetSpecialty']}. Tap to book your appointment.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: isWeb ? 14 : 14.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.amber.shade800, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessSection(bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Access",
          style: TextStyle(
            fontSize: isWeb ? 22 : 18.sp,
            fontWeight: FontWeight.bold,
            color: darkTealColor,
          ),
        ),
        SizedBox(height: isWeb ? 16 : 1.5.h),
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessCard(
                icon: Icons.calendar_month,
                label: 'Book',
                onTap: navigateToAppointment,
                isWeb: isWeb,
              ),
            ),
            SizedBox(width: isWeb ? 12 : 2.w),
            Expanded(
              child: _buildQuickAccessCard(
                icon: Icons.favorite_outline,
                label: 'Vitals',
                onTap: navigateToVitalScreen,
                isWeb: isWeb,
              ),
            ),
            SizedBox(width: isWeb ? 12 : 2.w),
            Expanded(
              child: _buildQuickAccessCard(
                icon: Icons.description_outlined,
                label: 'Prescriptions',
                onTap: navigateToPrescriptions,
                isWeb: isWeb,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isWeb = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: isWeb ? 20 : 2.5.h,
              horizontal: isWeb ? 12 : 3.w,
            ),
            constraints: BoxConstraints(
              minHeight: isWeb ? 100 : 12.h,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tealColor.withOpacity(0.9),
                  tealColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: tealColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(isWeb ? 10 : 2.5.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isWeb ? 28 : 20.sp,
                  ),
                ),
                SizedBox(height: isWeb ? 8 : 1.h),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isWeb ? 15 : 15.sp,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// M-7 ALSO SHOWING ON THE HOME PAGE
  Widget _buildVitalsGraphSection(bool isWeb) {
    final hasVitals = _vitals != null &&
        (_vitals!.bloodPressure.isNotEmpty || _vitals!.sugarLevel.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Health Vitals",
              style: TextStyle(
                fontSize: isWeb ? 22 : 18.sp,
                fontWeight: FontWeight.bold,
                color: darkTealColor,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VitalsHistoryScreen(),
                  ),
                );
              },
              child: Text(
                "View All",
                style: TextStyle(
                  fontSize: isWeb ? 14 : 13.5.sp,
                  color: tealColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isWeb ? 16 : 1.5.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(isWeb ? 20 : 4.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.8),
                    Colors.white.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tealColor.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: hasVitals
                  ? _buildVitalsTile(isWeb)
                  : _buildNoVitalsState(isWeb),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsTile(bool isWeb) {
    // Sort by date descending to get the most recent records
    BloodPressure? bp;
    if (_vitals!.bloodPressure.isNotEmpty) {
      final sortedBp = List<BloodPressure>.from(_vitals!.bloodPressure)
        ..sort((a, b) => b.date.compareTo(a.date));
      bp = sortedBp.first;
    }

    Sugar? sugar;
    if (_vitals!.sugarLevel.isNotEmpty) {
      final sortedSugar = List<Sugar>.from(_vitals!.sugarLevel)
        ..sort((a, b) => b.date.compareTo(a.date));
      sugar = sortedSugar.first;
    }

    Widget _buildBpSection() {
      if (bp == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blood Pressure',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: darkTealColor,
                    fontSize: isWeb ? 16 : 15.sp)),
            SizedBox(height: isWeb ? 8 : 1.h),
            Text('No data',
                style: TextStyle(
                    color: Colors.grey[600], fontSize: isWeb ? 14 : 13.sp)),
          ],
        );
      }

      final bpText = '${bp.systolic ?? '-'} / ${bp.diastolic ?? '-'} mmHg';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Blood Pressure',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: darkTealColor,
                  fontSize: isWeb ? 16 : 15.sp)),
          SizedBox(height: isWeb ? 8 : 1.h),
          Text(bpText,
              style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: isWeb ? 15 : 14.sp,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: isWeb ? 8 : 1.h),
          _buildBPStatus(bp, isWeb),
        ],
      );
    }

    Widget _buildSugarSection() {
      if (sugar == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blood Sugar',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: darkTealColor,
                    fontSize: isWeb ? 16 : 15.sp)),
            SizedBox(height: isWeb ? 8 : 1.h),
            Text('No data',
                style: TextStyle(
                    color: Colors.grey[600], fontSize: isWeb ? 14 : 13.sp)),
          ],
        );
      }

      final avg = _computeSugarAverage(sugar);
      final sugarVal = avg != null
          ? '${avg.toStringAsFixed(0)} mg/dL'
          : (sugar.random != null
              ? '${sugar.random!.toStringAsFixed(0)} mg/dL'
              : '—');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Blood Sugar',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: darkTealColor,
                  fontSize: isWeb ? 16 : 15.sp)),
          SizedBox(height: isWeb ? 8 : 1.h),
          Text(sugarVal,
              style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: isWeb ? 15 : 14.sp,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: isWeb ? 8 : 1.h),
          if (avg != null)
            _buildSugarAverageIndicator(sugar, isWeb)
          else
            _buildSugarStatus(sugar, isWeb),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(isWeb ? 16 : 3.5.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isWeb ? 12 : 2.5.w),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.favorite,
                      color: Colors.red, size: isWeb ? 24 : 18.sp),
                ),
                SizedBox(width: isWeb ? 12 : 3.w),
                Expanded(child: _buildBpSection()),
              ],
            ),
          ),
        ),
        SizedBox(width: isWeb ? 12 : 3.w),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(isWeb ? 16 : 3.5.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isWeb ? 12 : 2.5.w),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.water_drop,
                      color: Colors.blue, size: isWeb ? 24 : 18.sp),
                ),
                SizedBox(width: isWeb ? 12 : 3.w),
                Expanded(child: _buildSugarSection()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Widget _buildVitalsChart(bool isWeb) {
  //   // Show most recent vitals first (data is already sorted newest first from API)
  //   final bpData = _vitals!.bloodPressure.take(7).toList();
  //   final sugarData = _vitals!.sugarLevel.take(7).toList();

  //   return Column(
  //     children: [
  //       if (bpData.isNotEmpty) ...[
  //         Row(
  //           children: [
  //             Container(
  //               padding: EdgeInsets.all(isWeb ? 8 : 2.w),
  //               decoration: BoxDecoration(
  //                 color: Colors.red.withOpacity(0.1),
  //                 borderRadius: BorderRadius.circular(10),
  //               ),
  //               child: Icon(Icons.favorite,
  //                   color: Colors.red, size: isWeb ? 20 : 16.sp),
  //             ),
  //             SizedBox(width: isWeb ? 12 : 2.w),
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text('Blood Pressure',
  //                       style: TextStyle(
  //                           fontWeight: FontWeight.w600,
  //                           fontSize: isWeb ? 16 : 15.sp,
  //                           color: darkTealColor)),
  //                   // Text(
  //                   //     'Latest: ${bpData.first.systolic ?? '-'}/${bpData.first.diastolic ?? '-'} mmHg',
  //                   //     style: TextStyle(
  //                   //         fontSize: isWeb ? 13 : 13.sp,
  //                   //         color: Colors.grey[600])),
  //                 ],
  //               ),
  //             ),
  //             _buildBPStatus(bpData.first, isWeb),
  //           ],
  //         ),
  //         SizedBox(height: isWeb ? 16 : 2.h),
  //         SizedBox(
  //             height: isWeb ? 100 : 10.h,
  //             child: _buildSimpleLineChart(
  //                 bpData.map((e) => (e.systolic ?? 0).toDouble()).toList(),
  //                 bpData.map((e) => e.date).toList(),
  //                 Colors.red,
  //                 isWeb)),
  //       ],
  //       if (bpData.isNotEmpty && sugarData.isNotEmpty)
  //         Divider(height: isWeb ? 32 : 4.h),
  //       if (sugarData.isNotEmpty) ...[
  //         Row(
  //           children: [
  //             Container(
  //               padding: EdgeInsets.all(isWeb ? 8 : 2.w),
  //               decoration: BoxDecoration(
  //                   color: Colors.blue.withOpacity(0.1),
  //                   borderRadius: BorderRadius.circular(10)),
  //               child: Icon(Icons.water_drop,
  //                   color: Colors.blue, size: isWeb ? 20 : 16.sp),
  //             ),
  //             SizedBox(width: isWeb ? 12 : 2.w),
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text('Blood Sugar',
  //                       style: TextStyle(
  //                           fontWeight: FontWeight.w600,
  //                           fontSize: isWeb ? 16 : 15.sp,
  //                           color: darkTealColor)),
  //                   Text(
  //                       'Avg: ${_computeSugarAverage(sugarData.first)?.toStringAsFixed(0) ?? '-'} mg/dL',
  //                       style: TextStyle(
  //                           fontSize: isWeb ? 13 : 13.sp,
  //                           color: Colors.grey[600])),
  //                 ],
  //               ),
  //             ),
  //             _buildSugarAverageIndicator(sugarData.first, isWeb),
  //           ],
  //         ),
  //         SizedBox(height: isWeb ? 16 : 2.h),
  //         SizedBox(
  //             height: isWeb ? 100 : 10.h,
  //             child: _buildSimpleLineChart(
  //                 sugarData.map((e) => (e.random ?? 0).toDouble()).toList(),
  //                 sugarData.map((e) => e.date).toList(),
  //                 Colors.blue,
  //                 isWeb)),
  //       ],
  //     ],
  //   );
  // }

  // Widget _buildSimpleLineChart(
  //     List<double> data, List<DateTime> labels, Color color, bool isWeb) {
  //   if (data.isEmpty) return const SizedBox();
  //   return CustomPaint(
  //       size: Size(double.infinity, isWeb ? 100 : 80),
  //       painter:
  //           SimpleLineChartPainter(data: data, labels: labels, color: color));
  // }

  Widget _buildBPStatus(BloodPressure bp, bool isWeb) {
    final systolic = bp.systolic ?? 0;
    String status = 'Normal';
    Color statusColor = Colors.green;
    if (systolic < 90) {
      status = 'Low';
      statusColor = Colors.orange;
    } else if (systolic > 140) {
      status = 'High';
      statusColor = Colors.red;
    } else if (systolic > 120) {
      status = 'Elevated';
      statusColor = Colors.amber;
    }
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 12 : 2.5.w, vertical: isWeb ? 6 : 0.8.h),
      decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(
              color: statusColor,
              fontSize: isWeb ? 12.5 : 12.5.sp,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSugarStatus(Sugar sugar, bool isWeb) {
    final fasting = sugar.fasting ?? 0;
    String status = 'Normal';
    Color statusColor = Colors.green;
    if (fasting < 70) {
      status = 'Low';
      statusColor = Colors.orange;
    } else if (fasting > 126) {
      status = 'High';
      statusColor = Colors.red;
    } else if (fasting > 100) {
      status = 'Pre-diabetic';
      statusColor = Colors.amber;
    }
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 12 : 2.5.w, vertical: isWeb ? 6 : 0.8.h),
      decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(
              color: statusColor,
              fontSize: isWeb ? 12.5 : 12.5.sp,
              fontWeight: FontWeight.w600)),
    );
  }

  double? _computeSugarAverage(Sugar sugar) {
    final values = <double>[];
    if (sugar.fasting != null) values.add(sugar.fasting!);
    if (sugar.afterTwoHours != null) values.add(sugar.afterTwoHours!);
    if (sugar.random != null) values.add(sugar.random!);
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Widget _buildSugarAverageIndicator(Sugar sugar, bool isWeb) {
    final avg = _computeSugarAverage(sugar);
    if (avg == null) return _buildSugarStatus(sugar, isWeb);

    String status = 'Normal';
    Color statusColor = Colors.green;
    if (avg < 70) {
      status = 'Low';
      statusColor = Colors.orange;
    } else if (avg > 126) {
      status = 'High';
      statusColor = Colors.red;
    } else if (avg > 100) {
      status = 'Pre-diabetic';
      statusColor = Colors.amber;
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 12 : 2.5.w, vertical: isWeb ? 6 : 0.8.h),
      decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text(status,
              style: TextStyle(
                  color: statusColor,
                  fontSize: isWeb ? 12.5 : 12.5.sp,
                  fontWeight: FontWeight.w600)),
          // SizedBox(height: isWeb ? 2 : 0.2.h),
          // Text('${avg.toStringAsFixed(0)}',
          //     style: TextStyle(
          //         color: statusColor,
          //         fontSize: isWeb ? 11 : 11.sp,
          //         fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNoVitalsState(bool isWeb) {
    return Column(
      children: [
        Icon(Icons.show_chart,
            size: isWeb ? 60 : 40.sp, color: tealColor.withOpacity(0.5)),
        SizedBox(height: isWeb ? 16 : 2.h),
        Text('No vitals recorded yet',
            style: TextStyle(
                fontSize: isWeb ? 16 : 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
        SizedBox(height: isWeb ? 8 : 1.h),
        Text('Start tracking your health by logging your vitals',
            style: TextStyle(
                fontSize: isWeb ? 14 : 12.sp, color: Colors.grey[500]),
            textAlign: TextAlign.center),
        SizedBox(height: isWeb ? 16 : 2.h),
        ElevatedButton.icon(
          onPressed: navigateToVitalScreen,
          icon: Icon(Icons.add, size: isWeb ? 18 : 14.sp),
          label: Text('Log Vitals',
              style: TextStyle(fontSize: isWeb ? 14 : 12.sp)),
          style: ElevatedButton.styleFrom(
              backgroundColor: tealColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 24 : 5.w, vertical: isWeb ? 12 : 1.5.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ],
    );
  }

  Widget _buildUpcomingAppointmentsSection(bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Upcoming Appointments",
                style: TextStyle(
                    fontSize: isWeb ? 22 : 18.sp,
                    fontWeight: FontWeight.bold,
                    color: darkTealColor)),
            if (_upcomingAppointments.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 10 : 2.w, vertical: isWeb ? 4 : 0.5.h),
                decoration: BoxDecoration(
                    color: tealColor, borderRadius: BorderRadius.circular(12)),
                child: Text('${_upcomingAppointments.length}',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isWeb ? 18 : 14.sp,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        SizedBox(height: isWeb ? 8 : 2.h),
        if (_upcomingAppointments.isEmpty)
          _buildEmptyAppointmentState(isWeb, true)
        else
          ListView.builder(
            padding: EdgeInsets
                .zero, // Yeh zaroori line hai extra space hatane ke liye
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _upcomingAppointments.length > 3
                ? 3
                : _upcomingAppointments.length,
            itemBuilder: (context, index) => _buildAppointmentCard(
                _upcomingAppointments[index], isWeb, true),
          ),
      ],
    );
  }

  Widget _buildPastAppointmentsSection(bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Appointment History",
                style: TextStyle(
                    fontSize: isWeb ? 22 : 18.sp,
                    fontWeight: FontWeight.bold,
                    color: darkTealColor)),
            // if (_pastAppointments.isNotEmpty)
            //   GestureDetector(
            //       onTap: () {},
            //       child: Text("View All",
            //           style: TextStyle(
            //               fontSize: isWeb ? 14 : 12.sp,
            //               color: tealColor,
            //               fontWeight: FontWeight.w600))),
          ],
        ),
        SizedBox(height: isWeb ? 16 : 1.5.h),
        if (_pastAppointments.isEmpty)
          _buildEmptyAppointmentState(isWeb, false)
        else
          _buildPastAppointmentsByDoctor(isWeb),
      ],
    );
  }

  /// Group past appointments by doctor and render each as an ExpansionTile
  /// listing all visit dates under that doctor.
  Widget _buildPastAppointmentsByDoctor(bool isWeb) {
    // Preserve recency - list is already sorted desc from service; stable group
    final Map<String, List<PatientAppointment>> grouped = {};
    final List<String> order = [];
    for (final appt in _pastAppointments) {
      final key = appt.doctorId.isNotEmpty ? appt.doctorId : appt.doctorName;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
        order.add(key);
      }
      grouped[key]!.add(appt);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: order.map((key) {
        final visits = grouped[key]!;
        final first = visits.first;
        return Container(
          margin: EdgeInsets.only(bottom: isWeb ? 12 : 1.5.h),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.grey.withOpacity(0.2), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: tealColor.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.symmetric(
                        horizontal: isWeb ? 16 : 3.5.w,
                        vertical: isWeb ? 8 : 0.5.h),
                    childrenPadding: EdgeInsets.fromLTRB(isWeb ? 16 : 3.5.w, 0,
                        isWeb ? 16 : 3.5.w, isWeb ? 12 : 1.5.h),
                    leading: Container(
                      width: isWeb ? 48 : 11.w,
                      height: isWeb ? 48 : 11.w,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [tealColor, tealColor.withOpacity(0.7)]),
                          borderRadius: BorderRadius.circular(12)),
                      child: first.doctorImageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(first.doctorImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: isWeb ? 24 : 18.sp)))
                          : Icon(Icons.person,
                              color: Colors.white, size: isWeb ? 24 : 18.sp),
                    ),
                    title: Text(first.doctorName,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isWeb ? 16 : 15.sp,
                            color: darkTealColor)),
                    subtitle: Padding(
                      padding: EdgeInsets.only(top: isWeb ? 4 : 0.4.h),
                      child: Text(
                          '${first.doctorSpecialty.isEmpty ? "Consultation" : first.doctorSpecialty} • ${visits.length} visit${visits.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: isWeb ? 13 : 14.sp, color: tealColor)),
                    ),
                    children:
                        visits.map((v) => _buildVisitRow(v, isWeb)).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVisitRow(PatientAppointment visit, bool isWeb) {
    final hasPrescription = visit.prescriptions.isNotEmpty;
    return InkWell(
      onTap: hasPrescription
          ? () => _showPrescriptionBottomSheet(visit, isWeb)
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 8 : 1.w, vertical: isWeb ? 8 : 1.h),
        child: Row(
          children: [
            Icon(Icons.event_note, size: isWeb ? 18 : 14.sp, color: tealColor),
            SizedBox(width: isWeb ? 10 : 2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visit.formattedDate,
                      style: TextStyle(
                          fontSize: isWeb ? 14 : 14.sp,
                          fontWeight: FontWeight.w600,
                          color: darkTealColor)),
                  SizedBox(height: isWeb ? 2 : 0.3.h),
                  Text(visit.formattedTime,
                      style: TextStyle(
                          fontSize: isWeb ? 12 : 13.sp,
                          color: Colors.grey[600])),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 10 : 2.w, vertical: isWeb ? 4 : 0.4.h),
              decoration: BoxDecoration(
                  color: _getStatusColor(visit.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(visit.status.isEmpty ? 'Completed' : visit.status,
                  style: TextStyle(
                      color: _getStatusColor(visit.status),
                      fontSize: isWeb ? 12 : 14.sp,
                      fontWeight: FontWeight.w600)),
            ),
            if (hasPrescription) ...[
              SizedBox(width: isWeb ? 8 : 2.w),
              Icon(Icons.description,
                  color: tealColor, size: isWeb ? 18 : 15.sp),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAppointmentState(bool isWeb, bool isUpcoming) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isWeb ? 24 : 5.w),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.5))),
          child: Column(
            children: [
              Icon(isUpcoming ? Icons.calendar_today : Icons.history,
                  size: isWeb ? 48 : 35.sp, color: tealColor.withOpacity(0.5)),
              SizedBox(height: isWeb ? 12 : 1.5.h),
              Text(
                  isUpcoming
                      ? 'No upcoming appointments'
                      : 'No appointment history',
                  style: TextStyle(
                      fontSize: isWeb ? 16 : 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600])),
              if (isUpcoming) ...[
                SizedBox(height: isWeb ? 12 : 1.5.h),
                ElevatedButton.icon(
                  onPressed: navigateToAppointment,
                  icon: Icon(Icons.add, size: isWeb ? 18 : 14.sp),
                  label: Text('Book Now',
                      style: TextStyle(fontSize: isWeb ? 14 : 13.5.sp)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: tealColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: isWeb ? 20 : 4.w,
                          vertical: isWeb ? 10 : 1.2.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(
      PatientAppointment appointment, bool isWeb, bool isUpcoming) {
    return GestureDetector(
      onTap: () {
        if (!isUpcoming && appointment.prescriptions.isNotEmpty) {
          _showPrescriptionBottomSheet(appointment, isWeb);
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isWeb ? 12 : 1.5.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(isWeb ? 16 : 3.5.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isUpcoming
                        ? tealColor.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: tealColor.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: isWeb ? 56 : 12.w,
                    height: isWeb ? 56 : 12.w,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [tealColor, tealColor.withOpacity(0.7)]),
                        borderRadius: BorderRadius.circular(14)),
                    child: appointment.doctorImageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(appointment.doctorImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.person,
                                    color: Colors.white,
                                    size: isWeb ? 28 : 20.sp)))
                        : Icon(Icons.person,
                            color: Colors.white, size: isWeb ? 28 : 20.sp),
                  ),
                  SizedBox(width: isWeb ? 16 : 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appointment.doctorName,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isWeb ? 16 : 16.sp,
                                color: darkTealColor)),
                        SizedBox(height: isWeb ? 4 : 0.5.h),
                        Text(appointment.doctorSpecialty,
                            style: TextStyle(
                                fontSize: isWeb ? 15 : 14.sp,
                                color: tealColor)),
                        SizedBox(height: isWeb ? 8 : 1.h),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: isWeb ? 15 : 14.sp,
                                color: Colors.grey[600]),
                            SizedBox(width: isWeb ? 4 : 1.w),
                            Text(appointment.formattedDate,
                                style: TextStyle(
                                    fontSize: isWeb ? 12 : 14.sp,
                                    color: Colors.grey[600])),
                            SizedBox(width: isWeb ? 12 : 3.w),
                            Icon(Icons.access_time,
                                size: isWeb ? 14 : 14.sp,
                                color: Colors.grey[600]),
                            SizedBox(width: isWeb ? 4 : 1.w),
                            Text(appointment.formattedTime,
                                style: TextStyle(
                                    fontSize: isWeb ? 12 : 14.sp,
                                    color: Colors.grey[600])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isWeb ? 10 : 2.w,
                            vertical: isWeb ? 4 : 0.5.h),
                        decoration: BoxDecoration(
                            color: _getStatusColor(appointment.status)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                            appointment.status.isEmpty
                                ? (isUpcoming ? 'Scheduled' : 'Completed')
                                : appointment.status,
                            style: TextStyle(
                                color: _getStatusColor(appointment.status),
                                fontSize: isWeb ? 14 : 14.sp,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (!isUpcoming && appointment.prescriptions.isNotEmpty)
                        Padding(
                            padding: EdgeInsets.only(top: isWeb ? 8 : 1.h),
                            child: Icon(Icons.description,
                                color: tealColor, size: isWeb ? 20 : 16.sp)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      case 'scheduled':
        return Colors.orange;
      default:
        return tealColor;
    }
  }

  void _showPrescriptionBottomSheet(
      PatientAppointment appointment, bool isWeb) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
            color: lightTealColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            Container(
                margin: EdgeInsets.only(top: isWeb ? 12 : 1.5.h),
                width: isWeb ? 40 : 10.w,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: EdgeInsets.all(isWeb ? 20 : 4.w),
              child: Row(
                children: [
                  Container(
                      padding: EdgeInsets.all(isWeb ? 10 : 2.w),
                      decoration: BoxDecoration(
                          color: tealColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.description,
                          color: tealColor, size: isWeb ? 24 : 20.sp)),
                  SizedBox(width: isWeb ? 12 : 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prescription Details',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isWeb ? 18 : 17.sp,
                                color: darkTealColor)),
                        Text('From ${appointment.doctorName}',
                            style: TextStyle(
                                fontSize: isWeb ? 14 : 15.sp,
                                color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: isWeb ? 24 : 20.sp)),
                ],
              ),
            ),
            Divider(color: Colors.grey[300]),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(isWeb ? 20 : 4.w),
                children: [
                  _buildInfoRow('Date', appointment.formattedDate,
                      Icons.calendar_today, isWeb),
                  _buildInfoRow('Time', appointment.formattedTime,
                      Icons.access_time, isWeb),
                  if (appointment.diagnosis.isNotEmpty)
                    _buildInfoRow('Diagnosis', appointment.diagnosis,
                        Icons.medical_information, isWeb),
                  SizedBox(height: isWeb ? 16 : 2.h),
                  Text('Medications',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isWeb ? 16 : 14.sp,
                          color: darkTealColor)),
                  SizedBox(height: isWeb ? 12 : 1.5.h),
                  ...appointment.prescriptions
                      .map((med) => _buildMedicineCard(med, isWeb)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isWeb) {
    return Padding(
      padding: EdgeInsets.only(bottom: isWeb ? 12 : 1.5.h),
      child: Row(
        children: [
          Icon(icon, size: isWeb ? 18 : 14.sp, color: tealColor),
          SizedBox(width: isWeb ? 8 : 2.w),
          Text('$label: ',
              style: TextStyle(
                  fontSize: isWeb ? 14 : 13.sp, color: Colors.grey[600])),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: isWeb ? 14 : 13.sp,
                      fontWeight: FontWeight.w500,
                      color: darkTealColor))),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(AppointmentMedicine medicine, bool isWeb) {
    return Container(
      margin: EdgeInsets.only(bottom: isWeb ? 12 : 1.5.h),
      padding: EdgeInsets.all(isWeb ? 16 : 3.w),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tealColor.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: EdgeInsets.all(isWeb ? 8 : 2.w),
                  decoration: BoxDecoration(
                      color: tealColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.medication,
                      color: tealColor, size: isWeb ? 20 : 16.sp)),
              SizedBox(width: isWeb ? 12 : 2.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(medicine.medicineName,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isWeb ? 15 : 14.sp,
                            color: darkTealColor)),
                    if (medicine.dosage.isNotEmpty)
                      Text(medicine.dosage,
                          style: TextStyle(
                              fontSize: isWeb ? 13 : 14.sp,
                              color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          if (medicine.frequency.isNotEmpty ||
              medicine.duration.isNotEmpty ||
              medicine.instructions.isNotEmpty) ...[
            SizedBox(height: isWeb ? 12 : 1.5.h),
            Divider(color: Colors.grey[200]),
            SizedBox(height: isWeb ? 8 : 1.h),
            if (medicine.frequency.isNotEmpty)
              _buildMedDetail('Frequency', medicine.frequency, isWeb),
            if (medicine.duration.isNotEmpty)
              _buildMedDetail('Duration', medicine.duration, isWeb),
            if (medicine.instructions.isNotEmpty)
              _buildMedDetail('Instructions', medicine.instructions, isWeb),
          ],
        ],
      ),
    );
  }

  Widget _buildMedDetail(String label, String value, bool isWeb) {
    return Padding(
      padding: EdgeInsets.only(bottom: isWeb ? 6 : 0.8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: isWeb ? 100 : 22.w,
              child: Text(label,
                  style: TextStyle(
                      fontSize: isWeb ? 12 : 14.sp, color: Colors.grey[600]))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: isWeb ? 12 : 14.sp,
                      fontWeight: FontWeight.w500,
                      color: darkTealColor))),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMedicationsSection(bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Active Medications",
                style: TextStyle(
                    fontSize: isWeb ? 22 : 18.sp,
                    fontWeight: FontWeight.bold,
                    color: darkTealColor)),
            if (_activeMedications.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 10 : 2.w, vertical: isWeb ? 4 : 0.5.h),
                decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('${_activeMedications.length} active',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isWeb ? 11 : 9.sp,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        SizedBox(height: isWeb ? 16 : 1.5.h),
        if (_activeMedications.isEmpty)
          _buildEmptyMedicationState(isWeb)
        else
          Column(
            children: [
              ..._activeMedications
                  .take(4)
                  .map((med) => _buildActiveMedicationCard(med, isWeb)),
              if (_pastMedications.isNotEmpty) ...[
                SizedBox(height: isWeb ? 16 : 2.h),
                _buildPastMedicationsPreview(isWeb),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyMedicationState(bool isWeb) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isWeb ? 24 : 5.w),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.5))),
          child: Column(
            children: [
              Icon(Icons.medication_outlined,
                  size: isWeb ? 48 : 35.sp, color: tealColor.withOpacity(0.5)),
              SizedBox(height: isWeb ? 12 : 1.5.h),
              Text('No active medications',
                  style: TextStyle(
                      fontSize: isWeb ? 16 : 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600])),
              SizedBox(height: isWeb ? 6 : 0.8.h),
              // Text('Your prescribed medications will appear here',
              //     style: TextStyle(
              //         fontSize: isWeb ? 13 : 11.sp, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveMedicationCard(ActiveMedication medication, bool isWeb) {
    return Container(
      margin: EdgeInsets.only(bottom: isWeb ? 12 : 1.5.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(isWeb ? 16 : 3.5.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tealColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                    color: tealColor.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isWeb ? 10 : 2.5.w),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [tealColor, tealColor.withOpacity(0.7)]),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.medication,
                          color: Colors.white, size: isWeb ? 24 : 18.sp),
                    ),
                    SizedBox(width: isWeb ? 12 : 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(medication.medicineName,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isWeb ? 16 : 14.sp,
                                  color: darkTealColor)),
                          SizedBox(height: isWeb ? 2 : 0.3.h),
                          Text(medication.dosage,
                              style: TextStyle(
                                  fontSize: isWeb ? 13 : 11.sp,
                                  color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isWeb ? 10 : 2.w,
                          vertical: isWeb ? 4 : 0.5.h),
                      decoration: BoxDecoration(
                          color: medication.daysRemaining <= 2
                              ? Colors.orange.withOpacity(0.1)
                              : tealColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${medication.daysRemaining} days left',
                          style: TextStyle(
                              color: medication.daysRemaining <= 2
                                  ? Colors.orange
                                  : tealColor,
                              fontSize: isWeb ? 11 : 9.sp,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                SizedBox(height: isWeb ? 12 : 1.5.h),
                Row(
                  children: [
                    _buildTimePill(
                        'Morning', medication.schedule.morning, isWeb),
                    SizedBox(width: isWeb ? 8 : 1.5.w),
                    _buildTimePill(
                        'Afternoon', medication.schedule.afternoon, isWeb),
                    SizedBox(width: isWeb ? 8 : 1.5.w),
                    _buildTimePill(
                        'Evening', medication.schedule.evening, isWeb),
                    SizedBox(width: isWeb ? 8 : 1.5.w),
                    _buildTimePill('Night', medication.schedule.night, isWeb),
                  ],
                ),
                SizedBox(height: isWeb ? 12 : 1.5.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: medication.progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                          medication.progress > 0.8 ? Colors.green : tealColor),
                      minHeight: isWeb ? 6 : 1.h),
                ),
                SizedBox(height: isWeb ? 8 : 1.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Prescribed by ${medication.doctorName}',
                        style: TextStyle(
                            fontSize: isWeb ? 11 : 9.sp,
                            color: Colors.grey[500])),
                    Text('${(medication.progress * 100).toInt()}% complete',
                        style: TextStyle(
                            fontSize: isWeb ? 11 : 9.sp,
                            color: tealColor,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePill(String label, bool isActive, bool isWeb) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isWeb ? 6 : 0.8.h),
        decoration: BoxDecoration(
          color: isActive
              ? tealColor.withOpacity(0.15)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isActive
                  ? tealColor.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(_getTimeIcon(label),
                size: isWeb ? 16 : 12.sp,
                color: isActive ? tealColor : Colors.grey[400]),
            SizedBox(height: isWeb ? 2 : 0.3.h),
            Text(label.substring(0, 3),
                style: TextStyle(
                    fontSize: isWeb ? 10 : 8.sp,
                    color: isActive ? tealColor : Colors.grey[400],
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  IconData _getTimeIcon(String time) {
    switch (time.toLowerCase()) {
      case 'morning':
        return Icons.wb_sunny_outlined;
      case 'afternoon':
        return Icons.wb_sunny;
      case 'evening':
        return Icons.wb_twilight;
      case 'night':
        return Icons.nightlight_round;
      default:
        return Icons.schedule;
    }
  }

  Widget _buildPastMedicationsPreview(bool isWeb) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(isWeb ? 16 : 3.w),
          decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2))),
          child: Row(
            children: [
              Icon(Icons.history,
                  color: Colors.grey[600], size: isWeb ? 20 : 16.sp),
              SizedBox(width: isWeb ? 12 : 2.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Past Medications',
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: isWeb ? 14 : 12.sp,
                            color: Colors.grey[700])),
                    Text(
                        '${_pastMedications.length} completed medication courses',
                        style: TextStyle(
                            fontSize: isWeb ? 12 : 10.sp,
                            color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey[500], size: isWeb ? 24 : 20.sp),
            ],
          ),
        ),
      ),
    );
  }
}

// class SimpleLineChartPainter extends CustomPainter {
//   final List<double> data;
//   final List<DateTime>? labels;
//   final Color color;

//   SimpleLineChartPainter(
//       {required this.data, required this.color, this.labels});

//   @override
//   void paint(Canvas canvas, Size size) {
//     if (data.isEmpty) return;

//     // Plot oldest -> newest left to right for natural timeline
//     final plotData = data.reversed.toList();
//     final plotLabels = labels != null ? labels!.reversed.toList() : null;

//     final paint = Paint()
//       ..color = color
//       ..strokeWidth = 1.5
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round;

//     final fillPaint = Paint()
//       ..shader = LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [color.withOpacity(0.22), color.withOpacity(0.0)])
//           .createShader(Rect.fromLTWH(0, 0, size.width, size.height));

//     final dotPaint = Paint()
//       ..color = color
//       ..style = PaintingStyle.fill;

//     final maxValue = plotData.reduce((a, b) => a > b ? a : b);
//     final minValue = plotData.reduce((a, b) => a < b ? a : b);
//     final range = maxValue - minValue;
//     final effectiveRange = range == 0 ? 1.0 : range;

//     // Build points
//     final points = <Offset>[];
//     for (int i = 0; i < plotData.length; i++) {
//       final x = plotData.length == 1
//           ? size.width / 2
//           : (i / (plotData.length - 1)) * size.width;
//       final normalizedValue = (plotData[i] - minValue) / effectiveRange;
//       final y = size.height -
//           (normalizedValue * size.height * 0.8) -
//           size.height * 0.1;
//       points.add(Offset(x, y));
//     }

//     // Draw subtle horizontal grid lines
//     final gridPaint = Paint()
//       ..color = Colors.grey.withOpacity(0.18)
//       ..strokeWidth = 1.0
//       ..style = PaintingStyle.stroke;
//     const int gridLines = 4;
//     for (int i = 0; i <= gridLines; i++) {
//       final y = (i / gridLines) * size.height;
//       canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
//     }

//     // Smooth path using quadratic Beziers between midpoints
//     final path = Path();
//     if (points.length == 1) {
//       path.moveTo(points.first.dx, points.first.dy);
//     } else if (points.length == 2) {
//       path.moveTo(points[0].dx, points[0].dy);
//       path.lineTo(points[1].dx, points[1].dy);
//     } else {
//       path.moveTo(points[0].dx, points[0].dy);
//       for (int i = 0; i < points.length - 1; i++) {
//         final p0 = points[i];
//         final p1 = points[i + 1];
//         final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
//         path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
//       }
//       path.lineTo(points.last.dx, points.last.dy);
//     }

//     // Fill area under the curve
//     final fillPath = Path.from(path);
//     fillPath.lineTo(size.width, size.height);
//     fillPath.lineTo(0, size.height);
//     fillPath.close();

//     canvas.drawPath(fillPath, fillPaint);
//     canvas.drawPath(path, paint);

//     // Draw value labels (max, mid, min) on left
//     final textStyle = TextStyle(color: Colors.grey[600], fontSize: 10);
//     void _drawLabel(String text, double y) {
//       final tp = TextPainter(
//           text: TextSpan(text: text, style: textStyle),
//           textDirection: TextDirection.ltr);
//       tp.layout();
//       tp.paint(canvas, Offset(4, y - tp.height / 2));
//     }

//     _drawLabel(maxValue.toStringAsFixed(0), points.first.dy);
//     final midValue = (maxValue + minValue) / 2;
//     final midNormalizedY = size.height -
//         (((midValue - minValue) / effectiveRange) * size.height * 0.8) -
//         size.height * 0.1;
//     _drawLabel(midValue.toStringAsFixed(0), midNormalizedY);
//     _drawLabel(minValue.toStringAsFixed(0), points.last.dy);

//     // Draw points with very small inner dot and subtle halo; highlight latest (rightmost)
//     for (int i = 0; i < points.length; i++) {
//       final p = points[i];
//       // halo (smaller)
//       canvas.drawCircle(
//           p,
//           4,
//           Paint()
//             ..color = color.withOpacity(0.12)
//             ..style = PaintingStyle.fill);
//       // inner (very small)
//       canvas.drawCircle(p, 1.6, dotPaint);
//     }

//     // Highlight newest (rightmost) point
//     final newest = points.last;
//     canvas.drawCircle(
//         newest,
//         5,
//         Paint()
//           ..color = Colors.white
//           ..style = PaintingStyle.fill);
//     canvas.drawCircle(
//         newest,
//         5,
//         Paint()
//           ..color = color
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 2);

//     // Draw simple x-axis labels if labels provided (first, mid, last)
//     if (plotLabels != null && plotLabels.isNotEmpty) {
//       final labelStyle = TextStyle(color: Colors.grey[600], fontSize: 10);
//       final drawText = (String txt, double x) {
//         final tp = TextPainter(
//             text: TextSpan(text: txt, style: labelStyle),
//             textDirection: TextDirection.ltr);
//         tp.layout();
//         final dx = x - tp.width / 2;
//         // place labels below the chart area to avoid overlapping dots
//         final dy = size.height - tp.height + 6;
//         tp.paint(canvas, Offset(dx, dy));
//       };

//       String fmt(DateTime d) => '${d.day}/${d.month}';

//       // first, mid, last by x positions
//       drawText(fmt(plotLabels.first), points.first.dx);
//       drawText(fmt(plotLabels[plotLabels.length ~/ 2]),
//           points[plotLabels.length ~/ 2].dx);
//       drawText(fmt(plotLabels.last), points.last.dx);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }
