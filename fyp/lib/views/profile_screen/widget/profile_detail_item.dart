import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import '../../color/colors.dart';

class ProfileDetailItem extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onPressed;
  const ProfileDetailItem(
      {super.key,
      required this.label,
      this.value = '',
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: profileDetailColor,
        borderRadius: BorderRadius.circular(2.w),
      ),
      padding: EdgeInsets.only(left: 5.w, bottom: 2.h),
      margin: EdgeInsets.only(left: 5.w, right: 5.w, top: 2.5.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              IconButton(
                onPressed: onPressed,
                icon: const Icon(
                  Icons.settings,
                  color: iconColor,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
