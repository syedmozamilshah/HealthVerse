import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/provider/future_provider/vital_provider/vital_provider.dart';
import 'package:fyp/views/color/colors.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:fyp/utils/pakistan_time_helper.dart';
import 'package:intl/intl.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:fyp/models/vital_data/vital_data.dart';

class VitalsHistoryScreen extends ConsumerStatefulWidget {
  const VitalsHistoryScreen({super.key});

  @override
  ConsumerState<VitalsHistoryScreen> createState() =>
      _VitalsHistoryScreenState();
}

class _VitalsHistoryScreenState extends ConsumerState<VitalsHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);
    final contentMaxWidth = ResponsiveHelper.getContentWidth(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: loginGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
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
                      'Vitals History',
                      style: TextStyle(
                        fontSize: isWeb ? 28 : 20.sp,
                        fontWeight: FontWeight.normal,
                        color: const Color.fromARGB(255, 240, 247, 245),
                      ),
                    ),
                  ],
                ),
              ),

              // Tabs
              Container(
                margin: EdgeInsets.symmetric(horizontal: isWeb ? 24 : 5.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  controller: _tabController,
                  // indicator: BoxDecoration(
                  //   borderRadius: BorderRadius.circular(25),
                  //   color: tealColor,
                  // ),
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(color: Colors.white, width: 3),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: tealColor,
                  tabs: const [
                    Tab(text: "Blood Sugar"),
                    Tab(text: "Blood Pressure"),
                  ],
                ),
              ),

              SizedBox(height: isWeb ? 16 : 2.h),

              // Content
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final vitalData = ref.watch(vitalInfoProvider);

                        return vitalData.when(
                          data: (data) {
                            return TabBarView(
                              controller: _tabController,
                              children: [
                                _buildSugarHistory(
                                    data.vitals.sugarLevel, isWeb),
                                _buildBPHistory(
                                    data.vitals.bloodPressure, isWeb),
                              ],
                            );
                          },
                          error: (err, stack) =>
                              Center(child: Text('Error: $err')),
                          loading: () => const Center(
                              child:
                                  CircularProgressIndicator(color: tealColor)),
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
    );
  }

  Widget _buildSugarHistory(List<dynamic> sugarData, bool isWeb) {
    if (sugarData.isEmpty) {
      return Center(
          child: Text("No Blood Sugar data available",
              style: TextStyle(color: Colors.grey[600])));
    }

    // Sort by date descending
    sugarData.sort((a, b) => b.date.compareTo(a.date));

    // Group by date to merge entries from the same day (using LOCAL time)
    final Map<String, Sugar> groupedData = {};
    for (var item in sugarData) {
      // Convert to local time for proper date grouping
      final localDate = PakistanTimeHelper.toPakistanTime(item.date);
      final dateKey = DateFormat('yyyy-MM-dd').format(localDate);
      if (!groupedData.containsKey(dateKey)) {
        // Create a new Sugar object to avoid modifying the original
        groupedData[dateKey] = Sugar(
          date: localDate,
          fasting: item.fasting,
          random: item.random,
          afterTwoHours: item.afterTwoHours,
        );
      } else {
        final existing = groupedData[dateKey]!;
        // Merge logic: keep existing (latest) if not null, otherwise take new (older)
        if ((existing.fasting == null || existing.fasting == 0) &&
            (item.fasting != null && item.fasting != 0)) {
          existing.fasting = item.fasting;
        }
        if ((existing.random == null || existing.random == 0) &&
            (item.random != null && item.random != 0)) {
          existing.random = item.random;
        }
        if ((existing.afterTwoHours == null || existing.afterTwoHours == 0) &&
            (item.afterTwoHours != null && item.afterTwoHours != 0)) {
          existing.afterTwoHours = item.afterTwoHours;
        }
      }
    }

    final processedList = groupedData.values.toList();
    processedList.sort((a, b) => b.date.compareTo(a.date));

    // Prepare data for chart (last 7 entries for simplicity)
    final chartData = processedList.take(7).toList().reversed.toList();

    return SingleChildScrollView(
      padding:
          EdgeInsets.symmetric(horizontal: isWeb ? 24 : 5.w, vertical: 2.h),
      child: Column(
        children: [
          // Chart Card
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: EdgeInsets.all(isWeb ? 24 : 5.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Last 7 Entries (Fasting)",
                    style: TextStyle(
                        fontSize: isWeb ? 18 : 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  SizedBox(height: 2.h),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: chartData
                                .expand((e) => [
                                      e.fasting ?? 0,
                                      e.random ?? 0,
                                      e.afterTwoHours ?? 0,
                                    ])
                                .reduce((a, b) => a > b ? a : b)
                                .toDouble() +
                            20,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (value.toInt() >= 0 &&
                                    value.toInt() < chartData.length) {
                                  final date =
                                      PakistanTimeHelper.toPakistanTime(
                                          chartData[value.toInt()].date);
                                  return SizedBox(
                                    height: (isWeb ? 40 : 28),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            DateFormat('MM/dd').format(date),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            DateFormat('hh:mm a').format(date),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 50,
                          getDrawingHorizontalLine: (value) =>
                              FlLine(color: Colors.grey[200], strokeWidth: 1),
                          getDrawingVerticalLine: (value) =>
                              FlLine(color: Colors.grey[200], strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: chartData.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;

                          final fasting = item.fasting?.toDouble() ?? 0.0;
                          final random = item.random?.toDouble() ?? 0.0;
                          final after2h = item.afterTwoHours?.toDouble() ?? 0.0;

                          return BarChartGroupData(
                            x: index,
                            barsSpace: 4,
                            barRods: [
                              BarChartRodData(
                                toY: fasting,
                                color: Colors.blueAccent,
                                width: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: random,
                                color: Colors.orangeAccent,
                                width: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: after2h,
                                color: Colors.green,
                                width: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendItem(Colors.blueAccent, "Fasting"),
                      const SizedBox(width: 12),
                      _legendItem(Colors.orangeAccent, "Random"),
                      const SizedBox(width: 12),
                      _legendItem(Colors.green, "After 2h"),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 2.h),

          // Group by month for better organization
          ..._buildMonthGroupedSugarList(processedList, isWeb),
        ],
      ),
    );
  }

  // Helper method to build month-grouped sugar list
  List<Widget> _buildMonthGroupedSugarList(
      List<Sugar> processedList, bool isWeb) {
    if (processedList.isEmpty) return [];

    // Group by month-year
    final Map<String, List<Sugar>> monthGroups = {};
    for (var item in processedList) {
      final monthKey = DateFormat('MMMM yyyy')
          .format(PakistanTimeHelper.toPakistanTime(item.date));
      if (!monthGroups.containsKey(monthKey)) {
        monthGroups[monthKey] = [];
      }
      monthGroups[monthKey]!.add(item);
    }

    List<Widget> widgets = [];

    for (var entry in monthGroups.entries) {
      // Month header
      widgets.add(
        Padding(
          padding: EdgeInsets.only(top: 2.h, bottom: 1.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 16 : 4.w, vertical: isWeb ? 8 : 1.h),
                decoration: BoxDecoration(
                  color: tealColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isWeb ? 16 : 14.sp,
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Text(
                '(${entry.value.length} records)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isWeb ? 14 : 12.sp,
                ),
              ),
            ],
          ),
        ),
      );

      // M-6 SHOWING ALL ENTRIES FOR THE MONTH (MERGED BY DATE)
      // M-7 PATIENT APP SHOWING THE CHARTS
      // Items for this month
      for (var item in entry.value) {
        widgets.add(
          Card(
            margin: EdgeInsets.only(bottom: 1.5.h),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            color: const Color(0xFFF0F7F5), // Light teal/white background
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(isWeb ? 16 : 4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and Time Header (show date and time together)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          // e.g. Monday, Dec 22, 2025 • 02:30 PM
                          DateFormat('EEEE, MMM d, yyyy • hh:mm a').format(
                              PakistanTimeHelper.toPakistanTime(item.date)),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isWeb ? 16 : 15.sp,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 2.h),
                  Divider(color: Colors.grey[300], height: 1),
                  SizedBox(height: 2.h),

                  // Three Columns
                  Row(
                    children: [
                      Expanded(
                        child: _buildVitalValue("Fasting",
                            item.fasting?.toString() ?? "-", "mg/dL"),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: _buildVitalValue(
                            "Random", item.random?.toString() ?? "-", "mg/dL"),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: _buildVitalValue("After 2h",
                            item.afterTwoHours?.toString() ?? "-", "mg/dL"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildBPHistory(List<dynamic> bpData, bool isWeb) {
    if (bpData.isEmpty) {
      return Center(
          child: Text("No Blood Pressure data available",
              style: TextStyle(color: Colors.grey[600])));
    }

    // Sort by date descending
    bpData.sort((a, b) => b.date.compareTo(a.date));

    // Prepare data for chart (last 7 entries)
    final chartData = bpData.take(7).toList().reversed.toList();

    return SingleChildScrollView(
      padding:
          EdgeInsets.symmetric(horizontal: isWeb ? 24 : 5.w, vertical: 2.h),
      child: Column(
        children: [
          // Chart Card
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: EdgeInsets.all(isWeb ? 24 : 5.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Last 7 Entries (Systolic/Diastolic)",
                    style: TextStyle(
                        fontSize: isWeb ? 18 : 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  SizedBox(height: 2.h),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: chartData
                                .expand((e) => [
                                      e.systolic ?? 0,
                                      e.diastolic ?? 0,
                                    ])
                                .reduce((a, b) => a > b ? a : b)
                                .toDouble() +
                            20,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (value.toInt() >= 0 &&
                                    value.toInt() < chartData.length) {
                                  final date =
                                      PakistanTimeHelper.toPakistanTime(
                                          chartData[value.toInt()].date);
                                  return SizedBox(
                                    height: (isWeb ? 40 : 28),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            DateFormat('E').format(date),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            DateFormat('hh:mm a').format(date),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 50,
                          getDrawingHorizontalLine: (value) =>
                              FlLine(color: Colors.grey[200], strokeWidth: 1),
                          getDrawingVerticalLine: (value) =>
                              FlLine(color: Colors.grey[200], strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: chartData.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final systolic = item.systolic?.toDouble() ?? 0.0;
                          final diastolic = item.diastolic?.toDouble() ?? 0.0;
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: systolic,
                                color: Colors.redAccent,
                                width: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: diastolic,
                                color: Colors.blueAccent,
                                width: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 12, height: 12, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      const Text("Systolic", style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 16),
                      Container(
                          width: 12, height: 12, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      const Text("Diastolic", style: TextStyle(fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
          ),

          SizedBox(height: 2.h),

          // Group by month for better organization
          ..._buildMonthGroupedBPList(bpData, isWeb),
        ],
      ),
    );
  }

  // Helper method to build month-grouped BP list
  List<Widget> _buildMonthGroupedBPList(List<dynamic> bpData, bool isWeb) {
    if (bpData.isEmpty) return [];

    // Group by month-year
    final Map<String, List<dynamic>> monthGroups = {};
    for (var item in bpData) {
      final localDate = PakistanTimeHelper.toPakistanTime(item.date);
      final monthKey = DateFormat('MMMM yyyy').format(localDate);
      if (!monthGroups.containsKey(monthKey)) {
        monthGroups[monthKey] = [];
      }
      monthGroups[monthKey]!.add(item);
    }

    List<Widget> widgets = [];

    for (var entry in monthGroups.entries) {
      // Month header
      widgets.add(
        Padding(
          padding: EdgeInsets.only(top: 2.h, bottom: 1.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 16 : 4.w, vertical: isWeb ? 8 : 1.h),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isWeb ? 16 : 14.sp,
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Text(
                '(${entry.value.length} records)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isWeb ? 14 : 12.sp,
                ),
              ),
            ],
          ),
        ),
      );

      // Items for this month
      for (var item in entry.value) {
        widgets.add(
          Card(
            margin: EdgeInsets.only(bottom: 1.5.h),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: EdgeInsets.all(isWeb ? 16 : 4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite,
                          color: Colors.redAccent, size: 18.sp),
                      SizedBox(width: 2.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, MMM d, yyyy • hh:mm a').format(
                                PakistanTimeHelper.toPakistanTime(item.date)),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isWeb ? 16 : 15.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    "${item.systolic}/${item.diastolic} mmHg",
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 24.sp,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildVitalValue(String label, String value, String unit,
      [IconData? icon]) {
    return Column(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tealColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: tealColor, size: 18.sp),
          ),
          SizedBox(height: 1.h),
        ],
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
        SizedBox(height: 0.5.h),
        Text(
          value,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
              color: Colors.black87),
        ),
        Text(unit, style: TextStyle(color: Colors.grey[400], fontSize: 10.sp)),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
