import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/models/vital_data/vital_data.dart';
import 'package:fyp/provider/future_provider/vital_provider/vital_provider.dart';
import 'package:fyp/services/vital_service/vital_service.dart';
import 'package:fyp/views/color/colors.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:fyp/utils/pakistan_time_helper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class LogVitalsScreen extends StatefulWidget {
  final bool showBackButton;

  const LogVitalsScreen({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<LogVitalsScreen> createState() => _LogVitalsScreenState();
}

class _LogVitalsScreenState extends State<LogVitalsScreen> {
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();

  final VitalService vitalService = VitalService();

  BloodPressure bp =
      BloodPressure(systolic: 0, diastolic: 0, date: DateTime.now().toUtc());
  Sugar sugar = Sugar(date: DateTime.now().toUtc());

  String? sugarType;
  bool isFastingEnteredToday = false;
  bool isRandomEnteredToday = false;
  bool isAfter2HoursEnteredToday = false;
  bool hasBpToday = false;
  bool sugarLoading = false;
  bool bpLoading = false;
  // Editing state
  String? _editingSugarType;
  bool _editingBp = false;

  String _getNormalRange(String type) {
    switch (type) {
      case "Fasting":
        return "Normal Fasting Sugar: 70–99 mg/dL";
      case "Random":
        return "Normal Random Sugar: < 200 mg/dL";
      case "After 2 Hours":
        return "Normal 2-Hour Post Meal: < 140 mg/dL";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);
    final contentMaxWidth = ResponsiveHelper.getContentWidth(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: loginGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button (conditionally shown)
              if (widget.showBackButton)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 24 : 4.w,
                    vertical: isWeb ? 16 : 2.h,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                        'Log Your Vitals',
                        style: TextStyle(
                          fontSize: isWeb ? 28 : 20.sp,
                          fontWeight: FontWeight.normal,
                          color: const Color.fromARGB(255, 242, 248, 247),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 24 : 4.w,
                    vertical: isWeb ? 16 : 2.h,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Log Your Vitals',
                        style: TextStyle(
                          fontSize: isWeb ? 28 : 20.sp,
                          fontWeight: FontWeight.normal,
                          color: const Color.fromARGB(255, 242, 248, 247),
                        ),
                      ),
                    ],
                  ),
                ),

              // Main Content
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: isWeb ? 24 : 5.w,
                        right: isWeb ? 24 : 5.w,
                        bottom:
                            widget.showBackButton ? 0 : (isWeb ? 100 : 12.h),
                      ),
                      child: Column(
                        children: [
                          // Blood Sugar Card
                          Card(
                            elevation: 8,
                            shadowColor: tealColor.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(isWeb ? 24 : 5.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section Header
                                  Row(
                                    children: [
                                      Container(
                                        padding:
                                            EdgeInsets.all(isWeb ? 12 : 2.5.w),
                                        decoration: BoxDecoration(
                                          color: tealColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.bloodtype,
                                          color: tealColor,
                                          size: isWeb ? 28 : 22.sp,
                                        ),
                                      ),
                                      SizedBox(width: isWeb ? 16 : 3.w),
                                      Text(
                                        'Blood Sugar',
                                        style: TextStyle(
                                          fontSize: isWeb ? 22 : 18.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: isWeb ? 24 : 3.h),

                                  // Sugar Type Toggle
                                  Consumer(builder: (context, ref, child) {
                                    final data = ref.watch(vitalInfoProvider);
                                    return data.when(
                                      data: (vitalResponse) {
                                        final vitals = vitalResponse.vitals;
                                        final today =
                                            PakistanTimeHelper.nowPakistan();

                                        final hasFastingToday =
                                            vitals.sugarLevel.any((s) {
                                          final d =
                                              PakistanTimeHelper.toPakistanTime(
                                                  s.date);
                                          return d.year == today.year &&
                                              d.month == today.month &&
                                              d.day == today.day &&
                                              (s.fasting != null &&
                                                  s.fasting != 0);
                                        });
                                        final hasRandomToday =
                                            vitals.sugarLevel.any((s) {
                                          final d =
                                              PakistanTimeHelper.toPakistanTime(
                                                  s.date);
                                          return d.year == today.year &&
                                              d.month == today.month &&
                                              d.day == today.day &&
                                              (s.random != null &&
                                                  s.random != 0);
                                        });
                                        final hasAfter2hToday =
                                            vitals.sugarLevel.any((s) {
                                          final d =
                                              PakistanTimeHelper.toPakistanTime(
                                                  s.date);
                                          return d.year == today.year &&
                                              d.month == today.month &&
                                              d.day == today.day &&
                                              (s.afterTwoHours != null &&
                                                  s.afterTwoHours != 0);
                                        });

                                        isFastingEnteredToday = hasFastingToday;
                                        isRandomEnteredToday = hasRandomToday;
                                        isAfter2HoursEnteredToday =
                                            hasAfter2hToday;

                                        // Check if any sugar type is entered today (for showing status when no type selected)
                                        bool anySugarEnteredToday =
                                            hasFastingToday ||
                                                hasRandomToday ||
                                                hasAfter2hToday;
                                        // Check if all sugar types are entered today
                                        bool allSugarTypesEntered =
                                            hasFastingToday &&
                                                hasRandomToday &&
                                                hasAfter2hToday;

                                        bool isCurrentSugarTypeDisabled = false;
                                        String buttonText = "Save Blood Sugar";

                                        if (allSugarTypesEntered) {
                                          isCurrentSugarTypeDisabled = true;
                                          buttonText = "Already Entered Today";
                                        } else if (sugarType == null) {
                                          // No type selected - show what's available
                                          if (anySugarEnteredToday) {
                                            buttonText = "Select Sugar Type";
                                          }
                                        } else if (sugarType == "Fasting" &&
                                            hasFastingToday) {
                                          isCurrentSugarTypeDisabled = true;
                                          buttonText =
                                              _editingSugarType == 'Fasting'
                                                  ? 'Save Changes'
                                                  : 'Edit Entry';
                                        } else if (sugarType == "Random" &&
                                            hasRandomToday) {
                                          isCurrentSugarTypeDisabled = true;
                                          buttonText =
                                              _editingSugarType == 'Random'
                                                  ? 'Save Changes'
                                                  : 'Edit Entry';
                                        } else if (sugarType ==
                                                "After 2 Hours" &&
                                            hasAfter2hToday) {
                                          isCurrentSugarTypeDisabled = true;
                                          buttonText = _editingSugarType ==
                                                  'After 2 Hours'
                                              ? 'Save Changes'
                                              : 'Edit Entry';
                                        }

                                        return Column(
                                          children: [
                                            // Meal Type Toggle
                                            Container(
                                              padding: EdgeInsets.all(
                                                  isWeb ? 6 : 1.w),
                                              decoration: BoxDecoration(
                                                color: lightTealColor
                                                    .withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  _buildMealToggle(
                                                    'Fasting',
                                                    sugarType == 'Fasting',
                                                    isFastingEnteredToday,
                                                    () => setState(() =>
                                                        sugarType = 'Fasting'),
                                                    isWeb,
                                                  ),
                                                  _buildMealToggle(
                                                    'Random',
                                                    sugarType == 'Random',
                                                    isRandomEnteredToday,
                                                    () => setState(() =>
                                                        sugarType = 'Random'),
                                                    isWeb,
                                                  ),
                                                  _buildMealToggle(
                                                    'After 2h',
                                                    sugarType ==
                                                        'After 2 Hours',
                                                    isAfter2HoursEnteredToday,
                                                    () => setState(() =>
                                                        sugarType =
                                                            'After 2 Hours'),
                                                    isWeb,
                                                  ),
                                                ],
                                              ),
                                            ),

                                            SizedBox(height: isWeb ? 16 : 2.h),

                                            // Normal Range Info
                                            if (sugarType != null)
                                              Container(
                                                width: double.infinity,
                                                padding: EdgeInsets.all(
                                                    isWeb ? 16 : 3.w),
                                                decoration: BoxDecoration(
                                                  color: lightTealColor
                                                      .withOpacity(0.3),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.info_outline,
                                                        color: tealColor,
                                                        size:
                                                            isWeb ? 20 : 18.sp),
                                                    SizedBox(
                                                        width:
                                                            isWeb ? 12 : 2.w),
                                                    Expanded(
                                                      child: Text(
                                                        _getNormalRange(
                                                            sugarType!),
                                                        style: TextStyle(
                                                          fontSize: isWeb
                                                              ? 16
                                                              : 14.sp,
                                                          color: tealColor,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                            SizedBox(height: isWeb ? 16 : 2.h),

                                            // Sugar Input Field
                                            Container(
                                              decoration: BoxDecoration(
                                                color: lightTealColor
                                                    .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: tealColor
                                                      .withOpacity(0.2),
                                                ),
                                              ),
                                              child: TextField(
                                                controller: _sugarController,
                                                keyboardType:
                                                    TextInputType.number,
                                                style: TextStyle(
                                                    fontSize:
                                                        isWeb ? 22 : 18.sp,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                textAlign: TextAlign.center,
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Enter Value (mg/dL)',
                                                  hintStyle: TextStyle(
                                                    color: Colors.grey[500],
                                                    fontSize:
                                                        isWeb ? 18 : 16.sp,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                    vertical: isWeb ? 16 : 2.h,
                                                    horizontal:
                                                        isWeb ? 20 : 4.w,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            SizedBox(height: isWeb ? 16 : 2.h),

                                            // Save Sugar Button
                                            SizedBox(
                                              width:
                                                  isWeb ? 300 : double.infinity,
                                              height: isWeb ? 50 : 6.h,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      isCurrentSugarTypeDisabled
                                                          ? Colors.grey.shade400
                                                          : tealColor,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  elevation: 2,
                                                ),
                                                // M-6 CALLING THE SAVE SUGAR
                                                onPressed: sugarLoading
                                                    ? null
                                                    : (isCurrentSugarTypeDisabled
                                                        ? () {
                                                            // If already in edit mode for this type, save changes
                                                            if (_editingSugarType ==
                                                                sugarType) {
                                                              _saveSugar(
                                                                  ref,
                                                                  hasFastingToday,
                                                                  hasRandomToday,
                                                                  hasAfter2hToday);
                                                            } else {
                                                              // Start editing: populate field with today's value
                                                              double? existing;
                                                              final today =
                                                                  PakistanTimeHelper
                                                                      .nowPakistan();
                                                              for (var s in vitals
                                                                  .sugarLevel) {
                                                                final d = PakistanTimeHelper
                                                                    .toPakistanTime(
                                                                        s.date);
                                                                if (d.year ==
                                                                        today
                                                                            .year &&
                                                                    d.month ==
                                                                        today
                                                                            .month &&
                                                                    d.day ==
                                                                        today
                                                                            .day) {
                                                                  if (sugarType == 'Fasting' &&
                                                                      s.fasting !=
                                                                          null &&
                                                                      s.fasting !=
                                                                          0) {
                                                                    existing = s
                                                                        .fasting;
                                                                    break;
                                                                  }
                                                                  if (sugarType == 'Random' &&
                                                                      s.random !=
                                                                          null &&
                                                                      s.random !=
                                                                          0) {
                                                                    existing = s
                                                                        .random;
                                                                    break;
                                                                  }
                                                                  if (sugarType == 'After 2 Hours' &&
                                                                      s.afterTwoHours !=
                                                                          null &&
                                                                      s.afterTwoHours !=
                                                                          0) {
                                                                    existing = s
                                                                        .afterTwoHours;
                                                                    break;
                                                                  }
                                                                }
                                                              }
                                                              if (existing !=
                                                                  null) {
                                                                _sugarController
                                                                        .text =
                                                                    existing
                                                                        .toInt()
                                                                        .toString();
                                                              }
                                                              setState(() {
                                                                _editingSugarType =
                                                                    sugarType;
                                                              });
                                                            }
                                                          }
                                                        : () => _saveSugar(
                                                            ref,
                                                            hasFastingToday,
                                                            hasRandomToday,
                                                            hasAfter2hToday)),
                                                child: sugarLoading
                                                    ? SizedBox(
                                                        width:
                                                            isWeb ? 24 : 22.sp,
                                                        height:
                                                            isWeb ? 24 : 22.sp,
                                                        child:
                                                            const CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : Text(
                                                        buttonText,
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: isWeb
                                                              ? 18
                                                              : 16.sp,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                      error: (err, stack) => _buildErrorButton(
                                          "Save Sugar", isWeb),
                                      loading: () => _buildLoadingButton(isWeb),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: isWeb ? 24 : 3.h),

                          // Blood Pressure Card
                          Card(
                            elevation: 8,
                            shadowColor: tealColor.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(isWeb ? 24 : 5.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section Header
                                  Row(
                                    children: [
                                      Container(
                                        padding:
                                            EdgeInsets.all(isWeb ? 12 : 2.5.w),
                                        decoration: BoxDecoration(
                                          color: tealColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.monitor_heart,
                                          color: tealColor,
                                          size: isWeb ? 28 : 22.sp,
                                        ),
                                      ),
                                      SizedBox(width: isWeb ? 16 : 3.w),
                                      Text(
                                        'Blood Pressure',
                                        style: TextStyle(
                                          fontSize: isWeb ? 22 : 18.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: isWeb ? 24 : 3.h),

                                  // BP Input Fields
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildBPInputField(
                                          controller: _systolicController,
                                          label: 'Systolic',
                                          hint: 'Upper',
                                          isWeb: isWeb,
                                        ),
                                      ),
                                      SizedBox(width: isWeb ? 16 : 3.w),
                                      Text(
                                        '/',
                                        style: TextStyle(
                                          fontSize: isWeb ? 32 : 24.sp,
                                          fontWeight: FontWeight.bold,
                                          color: tealColor,
                                        ),
                                      ),
                                      SizedBox(width: isWeb ? 16 : 3.w),
                                      Expanded(
                                        child: _buildBPInputField(
                                          controller: _diastolicController,
                                          label: 'Diastolic',
                                          hint: 'Lower',
                                          isWeb: isWeb,
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: isWeb ? 16 : 2.h),

                                  // Normal Range Info
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(isWeb ? 16 : 3.w),
                                    decoration: BoxDecoration(
                                      color: lightTealColor.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline,
                                            color: tealColor,
                                            size: isWeb ? 20 : 18.sp),
                                        SizedBox(width: isWeb ? 12 : 2.w),
                                        Expanded(
                                          child: Text(
                                            'Normal BP: 120/80 mmHg or below',
                                            style: TextStyle(
                                              fontSize: isWeb ? 16 : 14.sp,
                                              color: tealColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: isWeb ? 16 : 2.h),

                                  // Save BP Button
                                  Consumer(builder: (context, ref, child) {
                                    final data = ref.watch(vitalInfoProvider);
                                    return data.when(
                                      data: (vitalResponse) {
                                        final vitals = vitalResponse.vitals;
                                        final today =
                                            PakistanTimeHelper.nowPakistan();

                                        hasBpToday =
                                            vitals.bloodPressure.any((bpEntry) {
                                          final d =
                                              PakistanTimeHelper.toPakistanTime(
                                                  bpEntry.date);
                                          return d.year == today.year &&
                                              d.month == today.month &&
                                              d.day == today.day;
                                        });

                                        final bpButtonText = hasBpToday
                                            ? (_editingBp
                                                ? 'Save Changes'
                                                : 'Edit Entry')
                                            : 'Save Blood Pressure';

                                        return SizedBox(
                                          width: isWeb ? 300 : double.infinity,
                                          height: isWeb ? 50 : 6.h,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  hasBpToday && !_editingBp
                                                      ? Colors.grey.shade400
                                                      : tealColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                            ),
                                            // M-6 CALLING THE SAVE BP
                                            onPressed: bpLoading
                                                ? null
                                                : (hasBpToday
                                                    ? () async {
                                                        if (_editingBp) {
                                                          await _saveBloodPressure(
                                                              ref);
                                                        } else {
                                                          // start editing: populate fields with today's BP
                                                          final today =
                                                              PakistanTimeHelper
                                                                  .nowPakistan();
                                                          for (var bpEntry
                                                              in vitals
                                                                  .bloodPressure) {
                                                            final d = PakistanTimeHelper
                                                                .toPakistanTime(
                                                                    bpEntry
                                                                        .date);
                                                            if (d.year ==
                                                                    today
                                                                        .year &&
                                                                d.month ==
                                                                    today
                                                                        .month &&
                                                                d.day ==
                                                                    today.day) {
                                                              _systolicController
                                                                      .text =
                                                                  bpEntry
                                                                      .systolic
                                                                      .toString();
                                                              _diastolicController
                                                                      .text =
                                                                  bpEntry
                                                                      .diastolic
                                                                      .toString();
                                                              setState(() {
                                                                _editingBp =
                                                                    true;
                                                              });
                                                              break;
                                                            }
                                                          }
                                                        }
                                                      }
                                                    : () => _saveBloodPressure(
                                                        ref)),
                                            child: bpLoading
                                                ? SizedBox(
                                                    width: isWeb ? 24 : 22.sp,
                                                    height: isWeb ? 24 : 22.sp,
                                                    child:
                                                        const CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : Text(
                                                    bpButtonText,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize:
                                                          isWeb ? 18 : 16.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        );
                                      },
                                      error: (err, stack) => _buildErrorButton(
                                          "Save Blood Pressure", isWeb),
                                      loading: () => _buildLoadingButton(isWeb),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: isWeb ? 24 : 3.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealToggle(String label, bool isSelected, bool isDisabled,
      VoidCallback onTap, bool isWeb) {
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: MouseRegion(
          cursor: isDisabled
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: isWeb ? 14 : 1.5.h),
            decoration: BoxDecoration(
              color: isDisabled
                  ? Colors.grey.shade300
                  : (isSelected ? tealColor : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDisabled
                    ? Colors.grey.shade600
                    : (isSelected ? Colors.white : Colors.black87),
                fontWeight: FontWeight.w600,
                fontSize: isWeb ? 16 : 14.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBPInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isWeb = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isWeb ? 16 : 14.sp,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isWeb ? 8 : 1.h),
        Container(
          decoration: BoxDecoration(
            color: lightTealColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: tealColor.withOpacity(0.2),
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(
                fontSize: isWeb ? 24 : 20.sp, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: isWeb ? 18 : 16.sp,
                fontWeight: FontWeight.normal,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: isWeb ? 16 : 2.h,
                horizontal: isWeb ? 12 : 2.w,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorButton(String text, bool isWeb) {
    return SizedBox(
      width: isWeb ? 300 : double.infinity,
      height: isWeb ? 50 : 6.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: tealColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          reusableSnackBar(context, "Error loading data");
        },
        child: Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: isWeb ? 18 : 16.sp),
        ),
      ),
    );
  }

  Widget _buildLoadingButton(bool isWeb) {
    return SizedBox(
      width: isWeb ? 300 : double.infinity,
      height: isWeb ? 50 : 6.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: null,
        child: Text(
          "Loading...",
          style: TextStyle(color: Colors.white, fontSize: isWeb ? 18 : 16.sp),
        ),
      ),
    );
  }

  Future<void> _saveSugar(WidgetRef ref, bool hasFastingToday,
      bool hasRandomToday, bool hasAfter2hToday) async {
    if (_sugarController.text.isEmpty || sugarType == null) {
      reusableSnackBar(context, "Please enter sugar and select type");
      return;
    }

    final sugarValue = int.tryParse(_sugarController.text);

    if (sugarValue == null) {
      reusableSnackBar(context, "Please enter a valid integer value for sugar");
      return;
    }

    if (sugarValue < 25 || sugarValue > 1000) {
      reusableSnackBar(context, "Sugar must be between 25 and 1000");
      return;
    }

    // If already entered and not in edit mode for this type, block save
    if (sugarType == "Fasting" &&
        hasFastingToday &&
        _editingSugarType != 'Fasting') {
      reusableSnackBar(context, "Fasting sugar already logged today");
      return;
    }
    if (sugarType == "Random" &&
        hasRandomToday &&
        _editingSugarType != 'Random') {
      reusableSnackBar(context, "Random sugar already logged today");
      return;
    }
    if (sugarType == "After 2 Hours" &&
        hasAfter2hToday &&
        _editingSugarType != 'After 2 Hours') {
      reusableSnackBar(context, "2 Hours sugar already logged today");
      return;
    }

    setState(() => sugarLoading = true);
    try {
      sugar.date = DateTime.now().toUtc();
      if (sugarType == "Fasting") {
        sugar.fasting = sugarValue.toDouble();
      } else if (sugarType == "Random") {
        sugar.random = sugarValue.toDouble();
      } else if (sugarType == "After 2 Hours") {
        sugar.afterTwoHours = sugarValue.toDouble();
      }

      final response = await vitalService.updateSugar(sugar);
      if (!(response.success)) {
        if (mounted) {
          setState(() => sugarLoading = false);
        }
        reusableSnackBar(
            context,
            response.message.isNotEmpty
                ? response.message
                : "Failed to save sugar. Please register patient first.");
        return;
      }
      if (mounted) {
        setState(() => sugarLoading = false);
      }
      _sugarController.clear();
      setState(() {
        sugarType = null;
        _editingSugarType = null;
      });
      reusableSnackBar(context, "Sugar saved successfully");
      ref.invalidate(vitalInfoProvider);
    } catch (e) {
      if (mounted) {
        setState(() => sugarLoading = false);
      }
      reusableSnackBar(context, "Error saving sugar: $e");
    }
  }

  Future<void> _saveBloodPressure(WidgetRef ref) async {
    final systolic = int.tryParse(_systolicController.text);
    final diastolic = int.tryParse(_diastolicController.text);

    if (systolic == null || diastolic == null) {
      reusableSnackBar(context, "Please enter valid numbers for BP");
      return;
    }
    if (systolic <= 0 || diastolic <= 0 || systolic > 500 || diastolic > 500) {
      reusableSnackBar(context,
          "Values must be between 1 and 500 for both systolic and diastolic");
      return;
    }

    if (hasBpToday && !_editingBp) {
      reusableSnackBar(context, "BP already logged today");
      return;
    }

    setState(() => bpLoading = true);
    try {
      bp.date = DateTime.now().toUtc();
      bp.systolic = systolic;
      bp.diastolic = diastolic;

      final response = await vitalService.updateBp(bp);
      if (!(response.success)) {
        reusableSnackBar(
            context,
            response.message.isNotEmpty
                ? response.message
                : "Failed to save BP. Please register patient first.");
        return;
      }
      ref.invalidate(vitalInfoProvider);
      reusableSnackBar(context, "Blood Pressure saved successfully");

      _systolicController.clear();
      _diastolicController.clear();
      setState(() {
        _editingBp = false;
      });
    } catch (e) {
      reusableSnackBar(context, "Error saving BP: $e");
    } finally {
      if (mounted) {
        setState(() => bpLoading = false);
      }
    }
  }
}
