import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../color/colors.dart';
import '../links/assets_link/asset_link.dart';
import '../registration_login/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final LiquidController _liquidController = LiquidController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      backgroundColor: const Color(0xFF1F8A70), // tealColor
      icon: Icons.health_and_safety_rounded,
      isLogoPage: true,
      title: 'Welcome to HealthVerse',
      subtitle: 'Your Digital Health Companion',
      description: 'Track your health, manage appointments, and stay connected with your healthcare providers all in one place.',
    ),
    OnboardingPage(
      backgroundColor: const Color(0xFF26A69A), // lighter teal
      icon: Icons.calendar_month_rounded,
      title: 'Book Appointments',
      subtitle: 'Easy Scheduling',
      description: 'Schedule appointments with doctors, describe your symptoms, and get the care you need when you need it.',
    ),
    OnboardingPage(
      backgroundColor: const Color(0xFF00897B), // darker teal
      icon: Icons.favorite_rounded,
      title: 'Track Your Vitals',
      subtitle: 'Monitor Your Health',
      description: 'Log your blood sugar, blood pressure, and other vitals. View trends and insights to stay on top of your health.',
    ),
    OnboardingPage(
      backgroundColor: const Color(0xFF004D40), // darkTealColor
      icon: Icons.chat_bubble_rounded,
      title: 'AI Health Assistant',
      subtitle: 'Smart Healthcare',
      description: 'Get instant health insights and recommendations powered by AI. Your health questions answered 24/7.',
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          LiquidSwipe(
            pages: _pages.map((page) => _buildPage(page)).toList(),
            liquidController: _liquidController,
            onPageChangeCallback: (page) {
              setState(() => _currentPage = page);
            },
            slideIconWidget: _currentPage < _pages.length - 1
                ? Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white.withOpacity(0.8),
                    size: 20.sp,
                  )
                : null,
            enableSideReveal: true,
            preferDragFromRevealedArea: true,
            ignoreUserGestureWhileAnimating: true,
            waveType: WaveType.liquidReveal,
          ),
          
          // Page Indicators
          Positioned(
            bottom: 12.h,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: 1.w),
                  height: 1.2.h,
                  width: _currentPage == index ? 8.w : 2.5.w,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          
          // Skip Button
          Positioned(
            top: 6.h,
            right: 5.w,
            child: TextButton(
              onPressed: _completeOnboarding,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          // Get Started Button (on last page)
          if (_currentPage == _pages.length - 1)
            Positioned(
              bottom: 4.h,
              left: 8.w,
              right: 8.w,
              child: ElevatedButton(
                onPressed: _completeOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: tealColor,
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.black26,
                ),
                child: Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isLargeScreen = screenWidth > 800;
    
    // Responsive sizing
    final logoSize = isLargeScreen ? 150.0 : (isSmallScreen ? screenWidth * 0.25 : screenWidth * 0.3);
    final iconSize = isLargeScreen ? 50.0 : (isSmallScreen ? 30.sp : 40.sp);
    final titleSize = isLargeScreen ? 28.0 : (isSmallScreen ? 20.sp : 24.sp);
    final subtitleSize = isLargeScreen ? 16.0 : (isSmallScreen ? 14.sp : 16.sp);
    final descSize = isLargeScreen ? 14.0 : (isSmallScreen ? 13.sp : 15.sp);
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: page.backgroundColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 40 : 8.w,
                    vertical: 2.h,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: isSmallScreen ? 2.h : 4.h),
                      
                      // Logo or Icon Container
                      page.isLogoPage
                          ? Container(
                              padding: EdgeInsets.all(isLargeScreen ? 20 : 4.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 25,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                logo,
                                width: logoSize,
                                height: logoSize,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Container(
                              padding: EdgeInsets.all(isLargeScreen ? 30 : 6.w),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: EdgeInsets.all(isLargeScreen ? 24 : 5.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  page.icon,
                                  size: iconSize,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                      
                      SizedBox(height: isSmallScreen ? 3.h : 5.h),
                      
                      // Title
                      Text(
                        page.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      
                      SizedBox(height: 1.h),
                      
                      // Subtitle
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 16 : 4.w,
                          vertical: isLargeScreen ? 8 : 0.8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: subtitleSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: isSmallScreen ? 2.h : 3.h),
                      
                      // Description
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 20 : 2.w,
                        ),
                        child: Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: descSize,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.5,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: isSmallScreen ? 8.h : 12.h),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class OnboardingPage {
  final Color backgroundColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final bool isLogoPage;

  OnboardingPage({
    required this.backgroundColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    this.isLogoPage = false,
  });
}
