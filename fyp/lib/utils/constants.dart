import 'package:flutter/material.dart';

/// ============================================================================
/// APP INFORMATION
/// ============================================================================
class AppInfo {
  static const String appName = 'HealthVerse';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your Health, Our Priority';
}

/// ============================================================================
/// API ENDPOINTS
/// ============================================================================
class ApiEndpoints {
  // Base URLs
  // ADB reverse is set up: localhost on phone -> localhost on PC
  // Run these commands once when phone is connected:
  //   adb reverse tcp:5257 tcp:5257
  //   adb reverse tcp:8000 tcp:8000
  static const String baseUrl = 'https://healthverse-ubdt.onrender.com';
  static const String aiBaseUrl = 'https://healthverse-agent-mcp.onrender.com';
  static const String doctorAgentBaseUrl = 'https://healthverse-doctor-agents.onrender.com';

  // Auth endpoints
  static const String login = '/api/Auth/login';
  static const String register = '/api/Auth/register';
  static const String forgotPassword = '/api/Auth/forgot-password';
  static const String verifyEmail = '/api/Auth/verify-email';

  // User endpoints
  static const String userProfile = '/api/User/profile';
  static const String updateProfile = '/api/User/update';

  // Appointment endpoints
  static const String createAppointment = '/api/Appointment/create';
  static const String getAppointments = '/api/Appointment';

  // Doctor endpoints
  static const String getDoctors = '/api/Doctor';
  static const String getDoctorById = '/api/Doctor/';

  // Vitals endpoints
  static const String vitals = '/api/Patient/vitals';

  // AI Health Assessment endpoints
  static const String healthAssessmentStart = '/health-assessment/start';
  static const String healthAssessmentAnswer = '/health-assessment/answer';
  static const String healthAssessmentInitialCondition =
      '/health-assessment/initial-condition';
  static const String healthAssessmentHistory = '/health-assessment/history';
  static String healthAssessmentSession(String sessionId) =>
      '/health-assessment/session/$sessionId';
}

/// ============================================================================
/// COLORS
/// ============================================================================
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF1F8A70);
  static const Color primaryLight = Color(0xFFE0F2F1);
  static const Color primaryDark = Color(0xFF004D40);

  // Teal Theme Colors (Main App Theme)
  static const Color teal = Color(0xFF1F8A70);
  static const Color lightTeal = Color(0xFFE0F2F1);
  static const Color darkTeal = Color(0xFF004D40);
  static const Color softTeal = Color(0xFF80CBC4);

  // Background Colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textFieldBackground = Color(0xFFE7EEF3);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textDark = Colors.black87;

  // Accent Colors
  static const Color success = Color(0xFF21E853);
  static const Color successDark = Color(0xFF186F2E);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);

  // Misc Colors
  static const Color paleBlue = Color(0xFF7985F0);
  static const Color mainBlue = Color(0xFF3095E8);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color shadow = Color(0x1A000000);

  // Chart Colors
  static const Color chartBlue = Color(0xFF2196F3);
  static const Color chartGreen = Color(0xFF4CAF50);
  static const Color chartRed = Color(0xFFF44336);
  static const Color chartOrange = Color(0xFFFF9800);
  static const Color chartPurple = Color(0xFF9C27B0);
}

/// ============================================================================
/// GRADIENTS
/// ============================================================================
class AppGradients {
  static const LinearGradient login = LinearGradient(
    colors: [
      Color(0xFF80CBC4), // Soft teal
      Color(0xFFE0F2F1), // Very light teal
      Colors.white,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient primary = LinearGradient(
    colors: [
      Color(0xFF21E853),
      Color(0xFFBDF6CB),
      Color(0xFFFBFBFB),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient teal = LinearGradient(
    colors: [
      Color(0xFF1F8A70),
      Color(0xFF80CBC4),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient card = LinearGradient(
    colors: [
      Colors.white,
      Color(0xFFF5F5F5),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// ============================================================================
/// TEXT STYLES
/// ============================================================================
class AppTextStyles {
  // Headings
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle h5 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Body Text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  // Button Text
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
  );

  // Caption/Label
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}

/// ============================================================================
/// SPACING & DIMENSIONS
/// ============================================================================
class AppSpacing {
  // Padding/Margin values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);
  static const EdgeInsets screenPaddingHorizontal =
      EdgeInsets.symmetric(horizontal: 16.0);
  static const EdgeInsets screenPaddingVertical =
      EdgeInsets.symmetric(vertical: 16.0);

  // Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(24.0);

  // Content width constraints
  static const double maxContentWidth = 600.0;
  static const double maxCardWidth = 500.0;
  static const double maxFormWidth = 450.0;
}

/// ============================================================================
/// BORDER RADIUS
/// ============================================================================
class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double circular = 100.0;

  // BorderRadius objects
  static final BorderRadius xsRadius = BorderRadius.circular(xs);
  static final BorderRadius smRadius = BorderRadius.circular(sm);
  static final BorderRadius mdRadius = BorderRadius.circular(md);
  static final BorderRadius lgRadius = BorderRadius.circular(lg);
  static final BorderRadius xlRadius = BorderRadius.circular(xl);
  static final BorderRadius xxlRadius = BorderRadius.circular(xxl);
  static final BorderRadius circularRadius = BorderRadius.circular(circular);
}

/// ============================================================================
/// SHADOWS
/// ============================================================================
class AppShadows {
  static List<BoxShadow> small = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> large = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.teal.withOpacity(0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}

/// ============================================================================
/// ANIMATION DURATIONS
/// ============================================================================
class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration splash = Duration(seconds: 3);
}

/// ============================================================================
/// SHARED PREFERENCES KEYS
/// ============================================================================
class PrefsKeys {
  static const String token = 'token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String userName = 'user_name';
  static const String onboardingCompleted = 'onboarding_completed';
  static const String themeMode = 'theme_mode';
  static const String languageCode = 'language_code';
}

/// ============================================================================
/// ASSET PATHS
/// ============================================================================
class AppAssets {
  // Images
  static const String logo = 'lib/assets/icon/healthverse_logo.png';
  static const String logoWhite = 'lib/assets/icon/healthverse_logo_white.png';
  static const String placeholder = 'lib/assets/images/placeholder.png';

  // Onboarding images
  static const String onboarding1 = 'lib/assets/onboarding/welcome.png';
  static const String onboarding2 = 'lib/assets/onboarding/doctors.png';
  static const String onboarding3 = 'lib/assets/onboarding/health.png';
  static const String onboarding4 = 'lib/assets/onboarding/start.png';

  // Icons
  static const String iconDoctor = 'lib/assets/icons/doctor.png';
  static const String iconAppointment = 'lib/assets/icons/appointment.png';
  static const String iconVitals = 'lib/assets/icons/vitals.png';
}

/// ============================================================================
/// VALIDATION PATTERNS
/// ============================================================================
class ValidationPatterns {
  static final RegExp email = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp phone = RegExp(
    r'^\+?[0-9]{10,15}$',
  );

  static final RegExp password = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$',
  );

  static final RegExp name = RegExp(
    r'^[a-zA-Z\s]{2,50}$',
  );
}

/// ============================================================================
/// ERROR MESSAGES
/// ============================================================================
class ErrorMessages {
  static const String networkError = 'Please check your internet connection';
  static const String serverError =
      'Something went wrong. Please try again later';
  static const String sessionExpired =
      'Your session has expired. Please login again';
  static const String invalidCredentials = 'Invalid email or password';
  static const String emailRequired = 'Email is required';
  static const String passwordRequired = 'Password is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String weakPassword =
      'Password must be at least 8 characters with letters and numbers';
  static const String passwordMismatch = 'Passwords do not match';
  static const String nameRequired = 'Name is required';
  static const String phoneRequired = 'Phone number is required';
  static const String invalidPhone = 'Please enter a valid phone number';
}

/// ============================================================================
/// SUCCESS MESSAGES
/// ============================================================================
class SuccessMessages {
  static const String loginSuccess = 'Login successful!';
  static const String registerSuccess =
      'Registration successful! Please verify your email';
  static const String passwordResetSent =
      'Password reset link sent to your email';
  static const String profileUpdated = 'Profile updated successfully';
  static const String appointmentBooked = 'Appointment booked successfully';
  static const String vitalsRecorded = 'Vitals recorded successfully';
}

/// ============================================================================
/// INPUT DECORATIONS
/// ============================================================================
class AppInputDecoration {
  static InputDecoration standard({
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon:
          prefixIcon != null ? Icon(prefixIcon, color: AppColors.teal) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.textFieldBackground,
      border: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: const BorderSide(color: AppColors.teal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdRadius,
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

/// ============================================================================
/// BUTTON STYLES
/// ============================================================================
class AppButtonStyles {
  static ButtonStyle primary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.teal,
    foregroundColor: AppColors.textLight,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.mdRadius,
    ),
    elevation: 2,
  );

  static ButtonStyle secondary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.lightTeal,
    foregroundColor: AppColors.teal,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.mdRadius,
    ),
    elevation: 0,
  );

  static ButtonStyle outline = OutlinedButton.styleFrom(
    foregroundColor: AppColors.teal,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.mdRadius,
    ),
    side: const BorderSide(color: AppColors.teal, width: 2),
  );

  static ButtonStyle text = TextButton.styleFrom(
    foregroundColor: AppColors.teal,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  );
}
