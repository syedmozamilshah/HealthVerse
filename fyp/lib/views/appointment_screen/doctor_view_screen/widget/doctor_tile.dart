import 'package:flutter/material.dart';
import 'package:fyp/models/doctor_data/doctor_data.dart';
import 'package:fyp/views/color/colors.dart';
import 'package:fyp/utils/pakistan_time_helper.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class DoctorTile extends StatelessWidget {
  final DoctorData user;
  final VoidCallback onTap;

  const DoctorTile({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);

    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isWeb ? 24 : 6.w)),
      elevation: 4,
      margin: EdgeInsets.symmetric(
          vertical: isWeb ? 12 : 2.h, horizontal: isWeb ? 16 : 4.w),
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 24 : 6.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: isWeb ? 40 : 9.w,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: NetworkImage(user.imageUrl),
                ),
                SizedBox(width: isWeb ? 20 : 5.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Dr. ${user.fName.toUpperCase()} ${user.lName.toUpperCase()}",
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.speciality,
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        user.specialization,
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
            SizedBox(height: 4.w),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        user.experience.isNotEmpty ? user.experience : "N/A",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.5.sp,
                        ),
                      ),
                      Text(
                        "Experience",
                        style: TextStyle(fontSize: 16.5.sp, color: mainColor),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _getAvailableHours(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.5.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "Available Hours",
                        style: TextStyle(fontSize: 16.5.sp, color: mainColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.w),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                    ),
                    onPressed: onTap,
                    child: const Text("Book Appointment",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getAvailableHours() {
    // Check if doctor has daily availabilities with future dates
    if (user.dailyAvailabilities.isNotEmpty) {
      final now = PakistanTimeHelper.nowPakistan();
      final today = DateTime(now.year, now.month, now.day);

      // Filter future availabilities
      final futureAvailabilities = user.dailyAvailabilities.where((avail) {
        final pakDate = PakistanTimeHelper.toPakistanTime(avail.date);
        final date = DateTime(pakDate.year, pakDate.month, pakDate.day);
        return date.isAtSameMomentAs(today) || date.isAfter(today);
      }).toList();

      if (futureAvailabilities.isNotEmpty) {
        // Get the first available day
        final firstDay = futureAvailabilities.first;
        final startTime = _formatTime(firstDay.startTime);
        final endTime = _formatTime(firstDay.endTime);
        return "$startTime - $endTime";
      }
    }

    // Fallback to morning time if no daily availabilities
    if (user.morningStartTime.isNotEmpty && user.morningEndTime.isNotEmpty) {
      return "${user.morningStartTime} - ${user.morningEndTime}";
    }

    return "N/A";
  }

  String _formatTime(DateTime time) {
    return PakistanTimeHelper.formatPakistanTime(time, 'h:mm a');
  }
}
