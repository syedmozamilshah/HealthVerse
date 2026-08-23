import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/views/home_screen/home_screen.dart';
import 'package:fyp/views/onboarding/onboarding_screen.dart';
import 'package:fyp/views/registration_login/login_screen.dart';
import 'package:fyp/views/splash/splash_screen.dart';
import 'package:fyp/views/color/colors.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider/state_notifier_provider/user_provider.dart';
import 'services/api_client/api_client.dart';
import 'provider/state_notifier_provider/auth_provider/auth_provider.dart';

// Conditional import for Stripe
import 'services/stripe/stripe_init.dart'
    if (dart.library.io) 'services/stripe/stripe_init_mobile.dart'
    as stripe_init;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Stripe (conditionally based on platform)
  await stripe_init.initializeStripe();

  // Initialize Firebase for FCM
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialize error: $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _showSplash = true;
  bool _initialized = false;
  bool _isAuthenticated = false;
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApiClient();
    });
  }

  Future<void> _initApiClient() async {
    final authProvider = ref.read(authProviderNotifier);
    await authProvider.loadSession();
    _isAuthenticated = authProvider.isAuthenticated;

    // Check if onboarding is completed
    final prefs = await SharedPreferences.getInstance();
    _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    ApiClient().init(authProvider);
    print("ApiClient initialized with token: ${authProvider.session?.token}");
    if (_isAuthenticated && authProvider.session != null) {
      final user = authProvider.session!.user;

      ref.read(userProvider.notifier).loadUserFromSession(user);
      // Initialize FCM and register device token for this user
      try {
        await NotificationService().initAndRegister(user.id);
      } catch (e) {
        // ignore errors during notification init
        print('Notification init error: $e');
      }
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  void _onSplashComplete() {
    if (mounted) {
      setState(() => _showSplash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveSizer(
      builder: (context, orientation, screenType) {
        Widget currentHome;
        if (_showSplash || !_initialized) {
          currentHome = SplashScreen(onComplete: _showSplash ? _onSplashComplete : () {});
        } else if (!_onboardingCompleted) {
          // First time user - show onboarding
          currentHome = const OnboardingScreen();
        } else if (_isAuthenticated) {
          // Authenticated user - show home
          currentHome = const HomeScreen();
        } else {
          // Not authenticated - show login
          currentHome = const LoginScreen();
        }

        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.teal,
            primaryColor: tealColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: tealColor,
              primary: tealColor,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: tealColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: tealColor,
                foregroundColor: Colors.white,
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: tealColor,
              foregroundColor: Colors.white,
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: tealColor,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: ZoomPageTransitionsBuilder(),
              },
            ),
          ),
          home: currentHome,
        );
      },
    );
  }
}
