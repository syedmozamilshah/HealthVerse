import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../../color/colors.dart';
import '../../../utils/responsive_helper.dart';

/// Glassmorphism theme constants for consistent styling across the app
class GlassmorphicTheme {
  // Blur values
  static const double blurSigma = 25.0;
  static const double blurSigmaLight = 15.0;

  // Gradient colors for glassmorphic effect
  static Color get glassColorStart => tealColor.withOpacity(0.15);
  static Color get glassColorEnd => tealAccent.withOpacity(0.08);
  static Color get glassBorderColor => Colors.white.withOpacity(0.4);
  static Color get glassHighlight => Colors.white.withOpacity(0.2);

  // Shadow colors
  static Color get shadowColor => tealColor.withOpacity(0.25);
  static Color get shadowColorDark => Colors.black.withOpacity(0.08);
  // Icon colors
  static Color get activeIconColor => Colors.white;
  static Color get inactiveIconColor => darkTealColor.withOpacity(0.7);

  // Background gradient for glassmorphic containers
  static LinearGradient get glassGradient => LinearGradient(
        colors: [
          tealColor.withOpacity(0.12),
          tealAccent.withOpacity(0.08),
          Colors.white.withOpacity(0.15),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Decoration for glassmorphic containers
  static BoxDecoration glassDecoration({
    double borderRadius = 30,
    bool withShadow = true,
  }) {
    return BoxDecoration(
      gradient: glassGradient,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: glassBorderColor,
        width: 1.5,
      ),
      boxShadow: withShadow
          ? [
              BoxShadow(
                color: shadowColor,
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: shadowColorDark,
                blurRadius: 40,
                spreadRadius: -10,
                offset: const Offset(0, 15),
              ),
            ]
          : null,
    );
  }
}

class GlassmorphicBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const GlassmorphicBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWeb ? 24 : 4.w,
        vertical: isWeb ? 16 : 2.h,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassmorphicTheme.blurSigma,
            sigmaY: GlassmorphicTheme.blurSigma,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isWeb ? 20 : 3.w,
              vertical: isWeb ? 14 : 1.5.h,
            ),
            decoration: GlassmorphicTheme.glassDecoration(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context: context,
                  icon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                  isWeb: isWeb,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.calendar_month_rounded,
                  label: 'Appointments',
                  index: 1,
                  isWeb: isWeb,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.favorite_rounded,
                  label: 'Vitals',
                  index: 2,
                  isWeb: isWeb,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.description_rounded,
                  label: 'Prescriptions',
                  index: 3,
                  isWeb: isWeb,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  index: 4,
                  isWeb: isWeb,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required bool isWeb,
  }) {
    final isSelected = currentIndex == index;
    final screenWidth = MediaQuery.of(context).size.width;
    // Smaller sizing for small screens
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;

    return GestureDetector(
      onTap: () => onTap(index),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isWeb 
                ? 18 
                : (isSelected 
                    ? (isSmallScreen ? 2.5.w : isMediumScreen ? 3.5.w : 4.5.w) 
                    : (isSmallScreen ? 1.5.w : 2.5.w)),
            vertical: isWeb ? 12 : 1.2.h,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      tealColor,
                      tealColor.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: tealColor.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: darkTealColor.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey('$index-$isSelected'),
                  color: isSelected
                      ? GlassmorphicTheme.activeIconColor
                      : GlassmorphicTheme.inactiveIconColor,
                  size: isWeb ? 26 : (isSmallScreen ? 18.sp : 20.sp),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: isSelected
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: isWeb ? 8 : 0.8.w),
                          Text(
                            isSmallScreen ? _getShortLabel(label) : label,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: isWeb ? 14 : (isSmallScreen ? 11.sp : 12.sp),
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getShortLabel(String label) {
    switch (label) {
      case 'Appointments':
        return 'Appts';
      case 'Prescriptions':
        return 'Rx';
      case 'Profile':
        return 'Me';
      default:
        return label;
    }
  }
}
