import 'package:flutter/material.dart';
import 'package:fyp/models/doctor_data/doctor_data.dart';
import 'package:fyp/views/appointment_screen/date_time_screen/widget/doctor_detail_appointment_tile.dart';
import 'package:fyp/views/color/colors.dart';
import 'package:fyp/utils/responsive_helper.dart';

class DateTimeScreen extends StatefulWidget {
  final DoctorData doctorData;
  const DateTimeScreen({super.key, required this.doctorData});

  @override
  State<DateTimeScreen> createState() => _DateTimeScreenState();
}

class _DateTimeScreenState extends State<DateTimeScreen> {
  @override
  Widget build(BuildContext context) {
    final contentMaxWidth = ResponsiveHelper.getContentWidth(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Date and Time'),
        backgroundColor: tealColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: appGradient,
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: SingleChildScrollView(
                // M-4 SHOWING DOCTOR TIME
                child: DoctorDetailAppointmentTile(user: widget.doctorData),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
