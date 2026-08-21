import 'package:flutter/material.dart';
import 'package:fyp/models/doctor_data/doctor_data.dart';
import 'package:fyp/views/color/colors.dart';
import 'package:fyp/utils/pakistan_time_helper.dart';
import 'package:intl/intl.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class TimeSlotSelector extends StatefulWidget {
  final List<Slot> dailyOne;
  final Function(Slot?)? onSlotSelected;

  const TimeSlotSelector({
    super.key,
    required this.dailyOne,
    this.onSlotSelected,
  });

  @override
  State<TimeSlotSelector> createState() => _TimeSlotSelectorState();
}

class _TimeSlotSelectorState extends State<TimeSlotSelector> {
  int? selectedIndex;

  bool _sameSlots(List<Slot> first, List<Slot> second) {
    if (first.length != second.length) return false;

    for (var index = 0; index < first.length; index++) {
      final firstSlot = first[index];
      final secondSlot = second[index];
      if (!firstSlot.startTime.isAtSameMomentAs(secondSlot.startTime) ||
          !firstSlot.endTime.isAtSameMomentAs(secondSlot.endTime) ||
          firstSlot.isBooked != secondSlot.isBooked ||
          firstSlot.userId != secondSlot.userId) {
        return false;
      }
    }

    return true;
  }

  @override
  void didUpdateWidget(covariant TimeSlotSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_sameSlots(oldWidget.dailyOne, widget.dailyOne)) {
      selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter out past time slots - only for today, show all slots for future dates
    final now = PakistanTimeHelper.nowPakistan();
    final today = DateTime(now.year, now.month, now.day);

    List<Slot> availableSlots;
    if (widget.dailyOne.isNotEmpty) {
      final firstSlotDate = DateTime(
        PakistanTimeHelper.toPakistanTime(widget.dailyOne.first.startTime).year,
        PakistanTimeHelper.toPakistanTime(widget.dailyOne.first.startTime)
            .month,
        PakistanTimeHelper.toPakistanTime(widget.dailyOne.first.startTime).day,
      );

      // If viewing today, filter out past slots
      // If viewing future date, show all slots
      if (firstSlotDate.isAtSameMomentAs(today)) {
        availableSlots = widget.dailyOne
            .where((slot) =>
                PakistanTimeHelper.toPakistanTime(slot.startTime).isAfter(now))
            .toList();
        print(
            'Today - Filtering past slots: ${widget.dailyOne.length} -> ${availableSlots.length}');
      } else {
        availableSlots = widget.dailyOne;
        print('Future date - Showing all slots: ${availableSlots.length}');
      }
    } else {
      availableSlots = [];
    }

    if (availableSlots.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(4.h),
          child: Text(
            "No available time slots for this date",
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
          ),
        ),
      );
    }

    return SafeArea(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: availableSlots.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3.h,
          mainAxisSpacing: 3.w,
          childAspectRatio: 2,
        ),
        itemBuilder: (context, index) {
          final slot = availableSlots[index];
          final formatted = DateFormat.jm()
              .format(PakistanTimeHelper.toPakistanTime(slot.startTime));
          final isBooked = slot.isBooked;

          // Debug: Print slot time details
          if (index == 0) {
            print('=== First Slot Debug ===');
            print('Slot startTime: ${slot.startTime}');
            print('Formatted display: $formatted');
            print('Kind: ${slot.startTime.isUtc ? "UTC" : "Local"}');
          }

          return Transform(
            transform: Matrix4.identity()..scale(1.3, 1.3),
            child: Opacity(
              opacity: isBooked ? 0.4 : 1.0,
              child: Stack(
                children: [
                  ChoiceChip(
                    label: Text(formatted),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: isBooked
                          ? Colors.grey[700]
                          : (selectedIndex == index
                              ? Colors.white
                              : Colors.black),
                      fontSize: 14.sp,
                      decoration: isBooked ? TextDecoration.lineThrough : null,
                    ),
                    selected: selectedIndex == index && !isBooked,
                    backgroundColor:
                        isBooked ? Colors.grey[200] : textFieldColor,
                    selectedColor: tealColor,
                    disabledColor: Colors.grey[200],
                    onSelected: isBooked
                        ? null // Disable selection for booked slots
                        : (_) {
                            setState(() {
                              selectedIndex = index;
                            });
                            print("=== Slot Selected ===");
                            print("Display Time: $formatted");
                            print("Actual startTime: ${slot.startTime}");
                            print(
                                "Kind: ${slot.startTime.isUtc ? "UTC" : "Local"}");
                            widget.onSlotSelected?.call(slot);
                          },
                  ),
                  if (isBooked)
                    Positioned.fill(
                      child: Center(
                        child: Icon(
                          Icons.lock,
                          size: 16.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
