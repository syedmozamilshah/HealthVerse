import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/views/appointment_screen/appointment_symptoms.dart';
import 'package:fyp/views/home_screen/home_screen.dart';
import 'package:fyp/views/prescriptions_screen/prescriptions_screen.dart';
import 'package:fyp/views/profile_screen/profile_screen.dart';
import 'package:fyp/views/vital_screen/log_vitals_screen.dart';
import 'package:fyp/views/widgets/glassmorphic_bottom_nav/glassmorphic_bottom_nav.dart';
import 'package:fyp/views/widgets/buddy_chat_widget.dart';

class MainNavigation extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigation({
    super.key,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  late int _currentIndex;
  late PageController _pageController;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleBackButton(bool didPop) {
    if (didPop) return;

    if (_currentIndex != 0) {
      // Go back to home if not already there
      _onNavItemTapped(0);
      return;
    }

    // Double tap to exit
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    // Allow exit
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) => _handleBackButton(didPop),
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              children: const [
                HomeScreenContent(),
                AppointmentSymptoms(showBackButton: false),
                LogVitalsScreen(showBackButton: false),
                PrescriptionsScreen(showBackButton: false),
                ProfileScreen(showBackButton: false),
              ],
            ),
            // Buddy Chat Widget - available on all screens
            const BuddyChatWidget(),
          ],
        ),
        bottomNavigationBar: GlassmorphicBottomNav(
          currentIndex: _currentIndex,
          onTap: _onNavItemTapped,
        ),
      ),
    );
  }
}
