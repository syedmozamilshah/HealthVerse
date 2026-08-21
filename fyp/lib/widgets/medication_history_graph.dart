import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fyp/services/medication_tracking_service/medication_tracking_service.dart';
import 'package:fyp/utils/pakistan_time_helper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

// M-5 UI BUILDER FOR MEDICATION HISTORY GRAPH
// M-7 MEDICATION CHECKING
/// Widget to display medication history as a bar graph
class MedicationHistoryGraph extends StatefulWidget {
  final String patientId;
  final Color primaryColor;
  final Color darkColor;
  final int days;

  const MedicationHistoryGraph({
    super.key,
    required this.patientId,
    this.primaryColor = const Color(0xFF00838F),
    this.darkColor = const Color(0xFF00695C),
    this.days = 7,
  });

  @override
  State<MedicationHistoryGraph> createState() => _MedicationHistoryGraphState();
}

class _MedicationHistoryGraphState extends State<MedicationHistoryGraph> {
  final MedicationTrackingService _medicationTrackingService =
      MedicationTrackingService();
  List<DailyHistoryStat> _historyData = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _medicationTrackingService.getDailyHistory(
        widget.patientId,
        days: widget.days,
      );

      if (response.success) {
        setState(() {
          _historyData = response.data;
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
        _error = 'Failed to load history';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(isWeb ? 20 : 4.w),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Medication History",
                    style: TextStyle(
                      fontSize: isWeb ? 18 : 17.sp,
                      fontWeight: FontWeight.bold,
                      color: widget.darkColor,
                    ),
                  ),
                  Row(
                    children: [
                      // Legend
                      _buildLegendItem('Taken', Colors.green, isWeb),
                      SizedBox(width: isWeb ? 12 : 2.w),
                      _buildLegendItem('Missed', Colors.red.shade300, isWeb),
                      SizedBox(width: isWeb ? 8 : 2.w),
                      IconButton(
                        icon: Icon(Icons.refresh,
                            color: widget.primaryColor,
                            size: isWeb ? 20 : 16.sp),
                        onPressed: _loadHistory,
                        tooltip: 'Refresh',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: isWeb ? 16 : 2.h),
              if (_isLoading)
                _buildLoadingState(isWeb)
              else if (_error != null)
                _buildErrorState(isWeb)
              else if (_historyData.isEmpty)
                _buildEmptyState(isWeb)
              else
                _buildBarGraph(isWeb),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isWeb) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isWeb ? 12 : 9.sp,
          height: isWeb ? 12 : 9.sp,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: isWeb ? 4 : 1.w),
        Text(
          label,
          style: TextStyle(
            fontSize: isWeb ? 11 : 15.sp,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isWeb) {
    return SizedBox(
      height: isWeb ? 150 : 18.h,
      child: Center(
        child: CircularProgressIndicator(color: widget.primaryColor),
      ),
    );
  }

  Widget _buildErrorState(bool isWeb) {
    return SizedBox(
      height: isWeb ? 150 : 18.h,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                color: Colors.red.shade300, size: isWeb ? 32 : 24.sp),
            SizedBox(height: isWeb ? 8 : 1.h),
            Text(
              _error ?? 'Error loading history',
              style: TextStyle(
                fontSize: isWeb ? 13 : 11.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isWeb) {
    return SizedBox(
      height: isWeb ? 150 : 18.h,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart,
                color: Colors.grey[400], size: isWeb ? 40 : 30.sp),
            SizedBox(height: isWeb ? 8 : 1.h),
            Text(
              'No medication history yet',
              style: TextStyle(
                fontSize: isWeb ? 14 : 12.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarGraph(bool isWeb) {
    // Find max doses for scaling
    int maxDoses = 1;
    for (var day in _historyData) {
      if (day.scheduledDoses > maxDoses) maxDoses = day.scheduledDoses;
    }

    // Calculate overall adherence
    int totalScheduled = 0;
    int totalTaken = 0;
    for (var day in _historyData) {
      totalScheduled += day.scheduledDoses;
      totalTaken += day.takenDoses;
    }
    double overallAdherence =
        totalScheduled > 0 ? (totalTaken / totalScheduled) * 100 : 0;

    return Column(
      children: [
        // Overall adherence indicator
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 16 : 3.w,
            vertical: isWeb ? 8 : 1.h,
          ),
          decoration: BoxDecoration(
            color: _getAdherenceColor(overallAdherence).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                overallAdherence >= 80
                    ? Icons.check_circle
                    : overallAdherence >= 50
                        ? Icons.warning
                        : Icons.error,
                color: _getAdherenceColor(overallAdherence),
                size: isWeb ? 20 : 16.sp,
              ),
              SizedBox(width: isWeb ? 8 : 2.w),
              Text(
                'Overall Adherence: ${overallAdherence.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: isWeb ? 15 : 15.sp,
                  fontWeight: FontWeight.w600,
                  color: _getAdherenceColor(overallAdherence),
                ),
              ),
              SizedBox(width: isWeb ? 16 : 3.w),
              Text(
                '($totalTaken/$totalScheduled doses)',
                style: TextStyle(
                  fontSize: isWeb ? 12 : 14.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isWeb ? 16 : 2.h),

        // Bar graph
        SizedBox(
          height: isWeb ? 150 : 18.h,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _historyData.map((day) {
              double barHeight = maxDoses > 0
                  ? ((day.scheduledDoses / maxDoses) * (isWeb ? 120 : 14.h))
                  : 0;
              double takenHeight = day.scheduledDoses > 0
                  ? (day.takenDoses / day.scheduledDoses) * barHeight
                  : 0;
              double missedHeight = barHeight - takenHeight;

              final pakNow = PakistanTimeHelper.nowPakistan();
              final todayStr =
                  '${pakNow.year}-${pakNow.month.toString().padLeft(2, '0')}-${pakNow.day.toString().padLeft(2, '0')}';
              bool isToday = day.date == todayStr;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isWeb ? 4 : 0.5.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Bar
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: isToday
                              ? Border.all(color: widget.primaryColor, width: 2)
                              : null,
                        ),
                        child: Column(
                          children: [
                            // Missed portion (top)
                            if (missedHeight > 0)
                              Container(
                                height: missedHeight,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade300,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(4),
                                    topRight: const Radius.circular(4),
                                    bottomLeft: takenHeight > 0
                                        ? Radius.zero
                                        : const Radius.circular(4),
                                    bottomRight: takenHeight > 0
                                        ? Radius.zero
                                        : const Radius.circular(4),
                                  ),
                                ),
                              ),
                            // Taken portion (bottom)
                            if (takenHeight > 0)
                              Container(
                                height: takenHeight,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: const Radius.circular(4),
                                    bottomRight: const Radius.circular(4),
                                    topLeft: missedHeight > 0
                                        ? Radius.zero
                                        : const Radius.circular(4),
                                    topRight: missedHeight > 0
                                        ? Radius.zero
                                        : const Radius.circular(4),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: isWeb ? 6 : 0.8.h),
                      // Day label
                      Text(
                        day.dayName,
                        style: TextStyle(
                          fontSize: isWeb ? 10 : 14.sp,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          color:
                              isToday ? widget.primaryColor : Colors.grey[600],
                        ),
                      ),
                      // Percentage label
                      Text(
                        '${day.adherencePercentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: isWeb ? 9 : 11.sp,
                          color: _getAdherenceColor(day.adherencePercentage),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getAdherenceColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }
}
