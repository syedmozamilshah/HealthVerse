import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fyp/models/prescription/prescription_model.dart';
import 'package:fyp/services/medication_tracking_service/medication_tracking_service.dart';
import 'package:fyp/utils/pakistan_time_helper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

// M-5 MEDICATION INTAKE TRACKING
/// Widget to display active medications with checkboxes for time slot tracking
class MedicationTrackingWidget extends StatefulWidget {
  final String patientId;
  final Color primaryColor;
  final Color darkColor;

  const MedicationTrackingWidget({
    super.key,
    required this.patientId,
    this.primaryColor = const Color(0xFF00838F),
    this.darkColor = const Color(0xFF00695C),
  });

  @override
  State<MedicationTrackingWidget> createState() =>
      _MedicationTrackingWidgetState();
}

class _MedicationTrackingWidgetState extends State<MedicationTrackingWidget> {
  final MedicationTrackingService _medicationTrackingService =
      MedicationTrackingService();
  List<ActiveMedication> _activeMedications = [];
  bool _isLoading = true;
  String? _error;
  // Track which medications are being updated
  Set<String> _updatingMeds = {};

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _medicationTrackingService
          .getActiveMedications(widget.patientId);

      if (response.success) {
        setState(() {
          _activeMedications = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load medications';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMedicationTime(
    ActiveMedication medication,
    String timeSlot,
    bool currentValue,
  ) async {
    // Once checked, cannot be unchecked - one way only
    if (currentValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicine already marked as taken'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final key =
        '${medication.prescriptionId}_${medication.medicineName}_$timeSlot';

    if (_updatingMeds.contains(key)) return;

    setState(() {
      _updatingMeds.add(key);
    });

    try {
      final success = await _medicationTrackingService.markMedicationTaken(
        prescriptionId: medication.prescriptionId,
        medicineName: medication.medicineName,
        timeSlot: timeSlot,
        taken: true, // Always mark as taken (one-way)
      );

      if (success) {
        // Reload medications to get updated tracking status
        await _loadMedications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update medication status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _updatingMeds.remove(key);
      });
    }
  }

  bool _getTimeSlotTaken(ActiveMedication medication, String timeSlot) {
    if (medication.todayTracking == null) return false;

    switch (timeSlot.toLowerCase()) {
      case 'morning':
        return medication.todayTracking!.morningTaken;
      case 'afternoon':
        return medication.todayTracking!.afternoonTaken;
      case 'evening':
        return medication.todayTracking!.eveningTaken;
      case 'night':
        return medication.todayTracking!.nightTaken;
      default:
        return false;
    }
  }

  bool _isTimeSlotScheduled(ActiveMedication medication, String timeSlot) {
    switch (timeSlot.toLowerCase()) {
      case 'morning':
        return medication.morning;
      case 'afternoon':
        return medication.afternoon;
      case 'evening':
        return medication.evening;
      case 'night':
        return medication.night;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Medications",
              style: TextStyle(
                fontSize: isWeb ? 22 : 18.sp,
                fontWeight: FontWeight.bold,
                color: widget.darkColor,
              ),
            ),
            if (_activeMedications.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 10 : 2.w,
                  vertical: isWeb ? 4 : 0.5.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_activeMedications.length} active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isWeb ? 11 : 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            IconButton(
              icon: Icon(Icons.refresh, color: widget.primaryColor),
              onPressed: _loadMedications,
              tooltip: 'Refresh medications',
            ),
          ],
        ),
        SizedBox(height: isWeb ? 16 : 1.5.h),
        if (_isLoading)
          _buildLoadingState(isWeb)
        else if (_error != null)
          _buildErrorState(isWeb)
        else if (_activeMedications.isEmpty)
          _buildEmptyState(isWeb)
        else
          Column(
            children: _activeMedications
                .map((med) => _buildMedicationCard(med, isWeb))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildLoadingState(bool isWeb) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isWeb ? 32 : 6.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              CircularProgressIndicator(color: widget.primaryColor),
              SizedBox(height: isWeb ? 12 : 1.5.h),
              Text(
                'Loading medications...',
                style: TextStyle(
                  fontSize: isWeb ? 14 : 14.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isWeb) {
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
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: isWeb ? 48 : 35.sp,
                color: Colors.red.withOpacity(0.7),
              ),
              SizedBox(height: isWeb ? 12 : 1.5.h),
              Text(
                _error ?? 'Error loading medications',
                style: TextStyle(
                  fontSize: isWeb ? 14 : 14.sp,
                  color: Colors.red[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isWeb ? 12 : 1.5.h),
              TextButton(
                onPressed: _loadMedications,
                child: Text(
                  'Retry',
                  style: TextStyle(color: widget.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isWeb) {
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
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.medication_outlined,
                size: isWeb ? 48 : 35.sp,
                color: widget.primaryColor.withOpacity(0.5),
              ),
              SizedBox(height: isWeb ? 12 : 1.5.h),
              Text(
                'No active medications',
                style: TextStyle(
                  fontSize: isWeb ? 16 : 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: isWeb ? 6 : 0.8.h),
              Text(
                'Your prescribed medications will appear here',
                style: TextStyle(
                  fontSize: isWeb ? 13 : 13.sp,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationCard(ActiveMedication medication, bool isWeb) {
    final scheduledSlots = <String>[];
    if (medication.morning) scheduledSlots.add('morning');
    if (medication.afternoon) scheduledSlots.add('afternoon');
    if (medication.evening) scheduledSlots.add('evening');
    if (medication.night) scheduledSlots.add('night');

    // Calculate today's progress
    int totalToday = scheduledSlots.length;
    int takenToday = 0;
    for (final slot in scheduledSlots) {
      if (_getTimeSlotTaken(medication, slot)) takenToday++;
    }
    double todayProgress = totalToday > 0 ? takenToday / totalToday : 0;

    return Container(
      margin: EdgeInsets.only(bottom: isWeb ? 16 : 2.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(isWeb ? 16 : 3.5.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.primaryColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with medication name and days remaining
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isWeb ? 10 : 2.5.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.primaryColor,
                            widget.primaryColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.medication,
                        color: Colors.white,
                        size: isWeb ? 24 : 18.sp,
                      ),
                    ),
                    SizedBox(width: isWeb ? 12 : 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medication.medicineName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: isWeb ? 16 : 16.sp,
                              color: widget.darkColor,
                            ),
                          ),
                          if (medication.dosage.isNotEmpty) ...[
                            SizedBox(height: isWeb ? 2 : 0.3.h),
                            Text(
                              medication.dosage,
                              style: TextStyle(
                                fontSize: isWeb ? 13 : 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWeb ? 10 : 2.w,
                        vertical: isWeb ? 4 : 0.5.h,
                      ),
                      decoration: BoxDecoration(
                        color: medication.daysRemaining <= 2
                            ? Colors.orange.withOpacity(0.1)
                            : widget.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${medication.daysRemaining} days left',
                        style: TextStyle(
                          color: medication.daysRemaining <= 2
                              ? Colors.orange
                              : widget.primaryColor,
                          fontSize: isWeb ? 11 : 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isWeb ? 16 : 2.h),

                // Time slots with checkboxes
                Text(
                  "Mark when you take your medicine:",
                  style: TextStyle(
                    fontSize: isWeb ? 12 : 14.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isWeb ? 10 : 1.h),
                Row(
                  children: [
                    if (medication.morning)
                      _buildTimeCheckbox(medication, 'Morning', isWeb),
                    if (medication.afternoon)
                      _buildTimeCheckbox(medication, 'Afternoon', isWeb),
                    if (medication.evening)
                      _buildTimeCheckbox(medication, 'Evening', isWeb),
                    if (medication.night)
                      _buildTimeCheckbox(medication, 'Night', isWeb),
                  ],
                ),
                SizedBox(height: isWeb ? 12 : 1.5.h),

                // Today's progress bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: todayProgress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            todayProgress >= 1.0
                                ? Colors.green
                                : widget.primaryColor,
                          ),
                          minHeight: isWeb ? 6 : 1.h,
                        ),
                      ),
                    ),
                    SizedBox(width: isWeb ? 12 : 2.w),
                    Text(
                      '$takenToday/$totalToday today',
                      style: TextStyle(
                        fontSize: isWeb ? 11 : 13.sp,
                        color: todayProgress >= 1.0
                            ? Colors.green
                            : widget.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isWeb ? 8 : 1.h),

                // Doctor info and instructions
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: isWeb ? 14 : 12.sp,
                      color: Colors.grey[500],
                    ),
                    SizedBox(width: isWeb ? 4 : 1.w),
                    Text(
                      'Dr. ${medication.doctorName}',
                      style: TextStyle(
                        fontSize: isWeb ? 11 : 13.sp,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (medication.doctorSpecialty.isNotEmpty) ...[
                      Text(
                        ' • ${medication.doctorSpecialty}',
                        style: TextStyle(
                          fontSize: isWeb ? 11 : 13.sp,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ],
                ),
                if (medication.nextAppointmentDate != null) ...[
                  SizedBox(height: isWeb ? 4 : 0.5.h),
                  Row(
                    children: [
                      Icon(
                        Icons.event_available,
                        size: isWeb ? 14 : 12.sp,
                        color: widget.primaryColor,
                      ),
                      SizedBox(width: isWeb ? 4 : 1.w),
                      Text(
                        'Next visit: ${_formatNextAppointment(medication.nextAppointmentDate!)}',
                        style: TextStyle(
                          fontSize: isWeb ? 11 : 13.sp,
                          color: widget.darkColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (medication.instructions.isNotEmpty) ...[
                  SizedBox(height: isWeb ? 6 : 0.8.h),
                  Container(
                    padding: EdgeInsets.all(isWeb ? 8 : 2.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: isWeb ? 14 : 12.sp,
                          color: Colors.blue[400],
                        ),
                        SizedBox(width: isWeb ? 6 : 1.5.w),
                        Expanded(
                          child: Text(
                            medication.instructions,
                            style: TextStyle(
                              fontSize: isWeb ? 11 : 13.sp,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCheckbox(
    ActiveMedication medication,
    String timeSlot,
    bool isWeb,
  ) {
    final isScheduled = _isTimeSlotScheduled(medication, timeSlot);
    if (!isScheduled) return const SizedBox.shrink();

    final isTaken = _getTimeSlotTaken(medication, timeSlot);
    final key =
        '${medication.prescriptionId}_${medication.medicineName}_${timeSlot.toLowerCase()}';
    final isUpdating = _updatingMeds.contains(key);

    final timeLabel = _getSlotTimeLabel(medication, timeSlot);

    return Expanded(
      child: GestureDetector(
        onTap: isUpdating
            ? null
            : () => _toggleMedicationTime(
                medication, timeSlot.toLowerCase(), isTaken),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: isWeb ? 4 : 0.5.w),
          padding: EdgeInsets.symmetric(
            vertical: isWeb ? 10 : 1.2.h,
            horizontal: isWeb ? 4 : 1.w,
          ),
          decoration: BoxDecoration(
            color: isTaken
                ? Colors.green.withOpacity(0.15)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isTaken
                  ? Colors.green.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUpdating)
                SizedBox(
                  width: isWeb ? 20 : 16.sp,
                  height: isWeb ? 20 : 16.sp,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.primaryColor,
                  ),
                )
              else
                Icon(
                  isTaken ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: isWeb ? 24 : 18.sp,
                  color: isTaken ? Colors.green : Colors.grey[400],
                ),
              SizedBox(height: isWeb ? 4 : 0.5.h),
              Icon(
                _getTimeIcon(timeSlot),
                size: isWeb ? 16 : 15.sp,
                color: isTaken ? Colors.green : Colors.grey[500],
              ),
              SizedBox(height: isWeb ? 2 : 0.3.h),
              Text(
                timeSlot.substring(0, 3),
                style: TextStyle(
                  fontSize: isWeb ? 10 : 14.sp,
                  color: isTaken ? Colors.green : Colors.grey[500],
                  fontWeight: isTaken ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (timeLabel.isNotEmpty) ...[
                SizedBox(height: isWeb ? 2 : 0.3.h),
                Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: isWeb ? 9 : 14.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatNextAppointment(DateTime utc) {
    final local = PakistanTimeHelper.toPakistanTime(utc);
    final today = PakistanTimeHelper.nowPakistan();
    final d = DateTime(local.year, local.month, local.day);
    final t0 = DateTime(today.year, today.month, today.day);
    final diff = d.difference(t0).inDays;

    String dayLabel;
    if (diff == 0) {
      dayLabel = 'Today';
    } else if (diff == 1) {
      dayLabel = 'Tomorrow';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      dayLabel = '${local.day} ${months[local.month - 1]}';
    }

    final hour12 =
        local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '$dayLabel, $hour12:$minute $period';
  }

  String _getSlotTimeLabel(ActiveMedication medication, String slot) {
    final slotKey = slot.toLowerCase();
    final timeText = switch (slotKey) {
      'morning' => medication.morningTimeUtc,
      'afternoon' => medication.afternoonTimeUtc,
      'evening' => medication.eveningTimeUtc,
      'night' => medication.nightTimeUtc,
      _ => '',
    };

    if (timeText.isEmpty) return '';

    // Convert stored UTC time to local display
    final parsed = DateTime.tryParse(timeText);
    if (parsed != null) {
      return _formatLocalTime(PakistanTimeHelper.toPakistanTime(parsed));
    }

    // If only HH:mm provided, treat it as UTC time-of-day for today
    final parts = timeText.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final nowUtc = DateTime.now().toUtc();
      final utc =
          DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, hour, minute);
      return _formatLocalTime(PakistanTimeHelper.toPakistanTime(utc));
    }

    return timeText;
  }

  String _formatLocalTime(DateTime local) {
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
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
}
