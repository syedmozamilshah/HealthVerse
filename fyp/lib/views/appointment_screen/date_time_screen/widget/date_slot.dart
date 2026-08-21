import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:fyp/utils/pakistan_time_helper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../../../color/colors.dart';

class DateSlot extends StatefulWidget {
  final List<DateTime> availableDates;

  final ValueChanged<DateTime> onDateSelection;

  const DateSlot({
    super.key,
    required this.availableDates,
    required this.onDateSelection,
  });

  @override
  State<DateSlot> createState() => _DateSlotState();
}

class _DateSlotState extends State<DateSlot> {
  int? selectedIndex;

  bool _sameDates(List<DateTime> first, List<DateTime> second) {
    if (first.length != second.length) return false;

    for (var index = 0; index < first.length; index++) {
      if (!first[index].isAtSameMomentAs(second[index])) {
        return false;
      }
    }

    return true;
  }

  @override
  void didUpdateWidget(covariant DateSlot oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_sameDates(oldWidget.availableDates, widget.availableDates) &&
        widget.availableDates.isNotEmpty) {
      selectedIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onDateSelection(widget.availableDates[0]);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.availableDates.isNotEmpty) {
      selectedIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDateSelection(widget.availableDates[0]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);

    return SizedBox(
      height: isWeb ? 100 : 15.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.availableDates.length,
        itemBuilder: (context, index) {
          final date = widget.availableDates[index];
          final pakistanDate = PakistanTimeHelper.toPakistanTime(date);
          final day = DateFormat.d().format(pakistanDate);
          final month = DateFormat.MMM().format(pakistanDate);
          final isSelected = selectedIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() => selectedIndex = index);
              widget.onDateSelection(date);
            },
            child: Container(
              width: isWeb ? 80 : 20.w,
              margin: EdgeInsets.symmetric(horizontal: isWeb ? 8 : 2.w),
              decoration: BoxDecoration(
                color: isSelected ? tealColor : textFieldColor,
                borderRadius: BorderRadius.circular(isWeb ? 12 : 3.w),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: tealColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: isWeb ? 24 : 20.sp,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    month,
                    style: TextStyle(
                      fontSize: isWeb ? 16 : 16.sp,
                      color: isSelected ? Colors.white : Colors.grey[700],
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
