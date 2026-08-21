import 'package:flutter/material.dart';
import 'package:fyp/views/color/colors.dart';
import 'package:fyp/utils/pakistan_time_helper.dart';
import 'package:intl/intl.dart';

class ReusableDatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final String label;
  final ValueChanged<DateTime> onDateChanged;

  const ReusableDatePicker({
    super.key,
    required this.selectedDate,
    required this.label,
    required this.onDateChanged,
  });

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = PakistanTimeHelper.nowPakistan();
    final DateTime firstDate = DateTime(now.year - 100);
    final DateTime lastDate = now;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null && picked != selectedDate) {
      onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayText = selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(selectedDate!)
        : 'Select Date';

    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: tealColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20, color: tealColor),
            const SizedBox(width: 12),
            Text(
              '$label: $displayText',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
