import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import '../../color/colors.dart';

class ItemCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double width;
  final double height;
  final double leftPadding;
  final double rightPadding;
  const ItemCard(
      {super.key,
      required this.title,
      required this.icon,
      required this.width,
      required this.height,
      this.leftPadding = 0.0,
      this.rightPadding = 0.0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding, right: rightPadding),
      child: Card(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2.w),
            color: homeItemCardColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 3.5.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 8.w, color: mainColor),
                ],
              ),
              SizedBox(height: 1.5.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style:
                          TextStyle(fontSize: 16.sp, color: homeItemTextColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
