import 'package:flutter/material.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class DoctorLoadingTile extends StatefulWidget {
  const DoctorLoadingTile({super.key});

  @override
  State<DoctorLoadingTile> createState() => _ChatLoadingTile();
}

class _ChatLoadingTile extends State<DoctorLoadingTile> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final isWeb = ResponsiveHelper.isWeb(context);
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isWeb ? 24 : 6.w)),
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: isWeb ? 12 : 2.h, horizontal: isWeb ? 16 : 4.w),
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
                ),
                SizedBox(width: isWeb ? 20 : 5.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: size.width / 0.4,
                        height: size.width * 0.05,
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.06),
                            borderRadius:
                                BorderRadius.all(Radius.circular(2.w))),
                      ),
                      SizedBox(height: 1.w),
                      Container(
                        width: size.width / 0.4,
                        height: size.width * 0.05,
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.06),
                            borderRadius:
                                BorderRadius.all(Radius.circular(2.w))),
                      ),
                      SizedBox(height: 1.w),
                      Container(
                        width: size.width / 0.4,
                        height: size.width * 0.05,
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.06),
                            borderRadius:
                                BorderRadius.all(Radius.circular(2.w))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.w),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: size.width / 0.9,
                        height: size.width * 0.05,
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.06),
                            borderRadius:
                                BorderRadius.all(Radius.circular(2.w))),
                      ),
                      SizedBox(height: 1.w),
                      Container(
                        width: size.width / 0.9,
                        height: size.width * 0.05,
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.06),
                            borderRadius:
                                BorderRadius.all(Radius.circular(2.w))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    width: size.width / 0.4,
                    height: size.width * 0.07,
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.all(Radius.circular(4.w))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
