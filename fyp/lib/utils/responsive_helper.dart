import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'dart:math' as math;

/// Responsive helper class for handling different screen sizes
/// Supports mobile, tablet, and web/desktop layouts
class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  static bool isWeb(BuildContext context) =>
      MediaQuery.of(context).size.width >= 800;

  static bool isSmallMobile(BuildContext context) =>
      MediaQuery.of(context).size.height < 700;

  /// Get responsive width - constrains max width on larger screens
  static double getContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 600; // Desktop - narrow card
    if (width >= 800) return 500; // Tablet/Web - medium card
    return width; // Mobile - full width
  }

  /// Get responsive padding
  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isDesktop(context)) {
      return EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h);
    } else if (isTablet(context)) {
      return EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h);
    }
    return EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h);
  }

  /// Get responsive card width
  static double getCardMaxWidth(BuildContext context) {
    if (isDesktop(context)) return 500;
    if (isTablet(context)) return 450;
    return double.infinity;
  }

  /// Get responsive font size multiplier
  static double getFontMultiplier(BuildContext context) {
    if (isDesktop(context)) return 0.7;
    if (isTablet(context)) return 0.85;
    return 1.0;
  }

  /// Get responsive icon size
  static double getIconSize(BuildContext context, double baseSize) {
    if (isDesktop(context)) return baseSize * 0.7;
    if (isTablet(context)) return baseSize * 0.85;
    return baseSize;
  }

  /// Get responsive grid columns
  static int getGridColumns(BuildContext context) {
    if (isDesktop(context)) return 4;
    if (isTablet(context)) return 3;
    return 2;
  }

  /// Get responsive spacing
  static double getSpacing(BuildContext context) {
    if (isDesktop(context)) return 24;
    if (isTablet(context)) return 20;
    return 16;
  }

  /// Get responsive font size - capped for web
  static double getFontSize(BuildContext context, double mobileSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1200) return math.min(mobileSize * 0.8, 24);
    if (screenWidth >= 800) return math.min(mobileSize * 0.9, 28);
    return mobileSize;
  }

  /// Get responsive image/logo size - capped for web
  static double getLogoSize(BuildContext context, double mobileSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1200) return math.min(mobileSize * 0.6, 150);
    if (screenWidth >= 800) return math.min(mobileSize * 0.7, 180);
    return mobileSize;
  }
}

/// Responsive wrapper widget that centers content on larger screens
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final bool centerOnWeb;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth,
    this.centerOnWeb = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!centerOnWeb || ResponsiveHelper.isMobile(context)) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ResponsiveHelper.getCardMaxWidth(context),
        ),
        child: child,
      ),
    );
  }
}

/// Responsive layout builder for different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context) && desktop != null) {
      return desktop!;
    }
    if (ResponsiveHelper.isTablet(context) && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}

/// Extension methods for responsive sizing
extension ResponsiveExtension on num {
  /// Responsive width that scales down on larger screens
  double rw(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) return (this * 0.5).w;
    if (ResponsiveHelper.isTablet(context)) return (this * 0.7).w;
    return w;
  }

  /// Responsive height that scales down on larger screens
  double rh(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) return (this * 0.7).h;
    if (ResponsiveHelper.isTablet(context)) return (this * 0.85).h;
    return h;
  }

  /// Responsive font size
  double rsp(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) return (this * 0.75).sp;
    if (ResponsiveHelper.isTablet(context)) return (this * 0.9).sp;
    return sp;
  }
}
