import 'package:flutter/material.dart';
import 'package:fyp/provider/state_notifier_provider/auth_provider/auth_provider.dart';
import 'package:fyp/views/home_screen/home_screen.dart';
import 'package:fyp/views/vital_screen/log_vitals_screen.dart';
import 'package:fyp/views/vital_screen/vitals_history_screen.dart';
import 'package:fyp/views/prescriptions_screen/prescriptions_screen.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/user_data/user_data.dart';
import '../../color/colors.dart';
import '../../profile_screen/profile_screen.dart';
import '../../registration_login/login_screen.dart';

class CustomDrawer extends StatelessWidget {
  final String selectedTile;
  final Function(String) onItemSelected;
  final UserData user;

  const CustomDrawer(
      {super.key,
      required this.selectedTile,
      required this.onItemSelected,
      required this.user});

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = AuthProvider();
    final isWeb = ResponsiveHelper.isWeb(context);
    final drawerWidth = isWeb ? 350.0 : null;
    
    return Drawer(
      width: drawerWidth,
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: loginGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // User Profile Section
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: isWeb ? 32 : 4.h,
                  horizontal: isWeb ? 24 : 5.w,
                ),
                child: Column(
                  children: [
                    // Profile Image
                    Container(
                      padding: EdgeInsets.all(isWeb ? 4 : 1.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tealColor,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tealColor.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: isWeb ? 50 : 12.w,
                        backgroundColor: Colors.white,
                        backgroundImage:
                            user.imageUrl != '' ? NetworkImage(user.imageUrl) : null,
                        child: user.imageUrl == ''
                            ? Icon(Icons.person, size: isWeb ? 50 : 12.w, color: tealColor)
                            : null,
                      ),
                    ),
                    
                    SizedBox(height: isWeb ? 16 : 2.h),
                    
                    // User Name
                    Text(
                      "${user.fName} ${user.lName}",
                      style: TextStyle(
                        fontSize: isWeb ? 22 : 18.sp,
                        fontWeight: FontWeight.bold,
                        color: tealColor,
                      ),
                    ),
                    
                    SizedBox(height: isWeb ? 4 : 0.5.h),
                    
                    // User Email
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: isWeb ? 16 : 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              Divider(
                color: tealColor.withOpacity(0.2),
                thickness: 1,
                indent: isWeb ? 24 : 5.w,
                endIndent: isWeb ? 24 : 5.w,
              ),
              
              SizedBox(height: isWeb ? 16 : 2.h),
              
              // Menu Items
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isWeb ? 16 : 4.w),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        context: context,
                        icon: Icons.home_rounded,
                        title: 'Home',
                        isSelected: selectedTile == 'HOME',
                        isWeb: isWeb,
                        onTap: () {
                          onItemSelected('HOME');
                          Navigator.pop(context); // Close drawer first
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      
                      SizedBox(height: isWeb ? 8 : 1.h),
                      
                      _buildMenuItem(
                        context: context,
                        icon: Icons.person_rounded,
                        title: 'Profile',
                        isSelected: selectedTile == 'PROFILE',
                        isWeb: isWeb,
                        onTap: () {
                          onItemSelected('PROFILE');
                          Navigator.pop(context); // Close drawer first
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                      ),
                      
                      SizedBox(height: isWeb ? 8 : 1.h),
                      
                      _buildMenuItem(
                        context: context,
                        icon: Icons.favorite_rounded,
                        title: 'Log Vitals',
                        isSelected: selectedTile == 'VITALS',
                        isWeb: isWeb,
                        onTap: () {
                          onItemSelected('VITALS');
                          Navigator.pop(context); // Close drawer first
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LogVitalsScreen(),
                            ),
                          );
                        },
                      ),
                      
                      SizedBox(height: isWeb ? 8 : 1.h),
                      
                      _buildMenuItem(
                        context: context,
                        icon: Icons.bar_chart_rounded,
                        title: 'Vitals History',
                        isSelected: selectedTile == 'VITALS_HISTORY',
                        isWeb: isWeb,
                        onTap: () {
                          onItemSelected('VITALS_HISTORY');
                          Navigator.pop(context); // Close drawer first
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const VitalsHistoryScreen(),
                            ),
                          );
                        },
                      ),
                      
                      SizedBox(height: isWeb ? 8 : 1.h),
                      
                      _buildMenuItem(
                        context: context,
                        icon: Icons.description_rounded,
                        title: 'My Prescriptions',
                        isSelected: selectedTile == 'PRESCRIPTIONS',
                        isWeb: isWeb,
                        onTap: () {
                          onItemSelected('PRESCRIPTIONS');
                          Navigator.pop(context); // Close drawer first
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrescriptionsScreen(),
                            ),
                          );
                        },
                      ),
                      
                      SizedBox(height: isWeb ? 8 : 1.h),
                      
                      _buildMenuItem(
                        context: context,
                        icon: Icons.settings_rounded,
                        title: 'Settings',
                        isSelected: selectedTile == 'SETTINGS',
                        isWeb: isWeb,
                        onTap: () {
                          onItemSelected('SETTINGS');
                          // Navigate to settings if available
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              // Logout Button
              Padding(
                padding: EdgeInsets.all(isWeb ? 20 : 5.w),
                child: SizedBox(
                  width: double.infinity,
                  height: isWeb ? 52 : 6.h,
                  child: ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      await authProvider.logout();
                      if (context.mounted) {
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.withOpacity(0.3)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: isWeb ? 24 : 20.sp),
                        SizedBox(width: isWeb ? 12 : 2.w),
                        Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: isWeb ? 18 : 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: isWeb ? 16 : 2.h),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    bool isWeb = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: isWeb ? 16 : 2.h,
            horizontal: isWeb ? 16 : 4.w,
          ),
          decoration: BoxDecoration(
            color: isSelected ? tealColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isWeb ? 10 : 2.w),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.2) 
                      : tealColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : tealColor,
                  size: isWeb ? 24 : 20.sp,
                ),
              ),
              SizedBox(width: isWeb ? 16 : 4.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: isWeb ? 18 : 16.sp,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: isSelected ? Colors.white.withOpacity(0.7) : Colors.grey[400],
                size: isWeb ? 24 : 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
