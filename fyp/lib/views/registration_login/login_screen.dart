import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/provider/state_notifier_provider/auth_provider/auth_provider.dart';
import 'package:fyp/services/auth_service/auth_service.dart';
import 'package:fyp/views/color/colors.dart';
import 'package:fyp/views/home_screen/home_screen.dart';
import 'package:fyp/views/links/assets_link/asset_link.dart';
import 'package:fyp/views/registration_login/register_screen.dart';
import 'package:fyp/views/registration_login/widget/reusable_text_form_field.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service/notification_service.dart';

import '../../provider/state_notifier_provider/user_provider.dart';
import '../../services/api_client/api_client.dart';
import '../../utils/responsive_helper.dart';
import '../reset_recovery_password_screen/recovery_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLoading = false;
  final AuthService _authService = AuthService();
  final AuthProvider _authProvider = AuthProvider();

  void navigateToHomeScreen() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const HomeScreen()));
  }

  void navigateToRegisterScreen() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const RegisterScreen()));
  }

  void navigateToRecoveryScreen() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const RecoveryScreen()));
  }

  void setLoading(bool value) {
    setState(() {
      isLoading = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);
    final cardMaxWidth = ResponsiveHelper.getCardMaxWidth(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: loginGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 2.w : 5.w,
                vertical: 2.h,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardMaxWidth),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWeb ? 40 : 5.w,
                      vertical: isWeb ? 40 : 4.h,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        SizedBox(
                          height: isWeb ? 80 : 8.h,
                          child: Image.asset(logo),
                        ),
                        SizedBox(height: isWeb ? 8 : 1.h),
                        Text(
                          'Healthverse',
                          style: TextStyle(
                            fontSize: isWeb ? 20 : 18.sp,
                            fontWeight: FontWeight.bold,
                            color: tealColor,
                          ),
                        ),
                        SizedBox(height: isWeb ? 24 : 3.h),

                        // Welcome Text
                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: isWeb ? 28 : 22.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: isWeb ? 8 : 1.h),
                        Text(
                          'Sign in to manage your health',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : 15.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: isWeb ? 32 : 4.h),

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              ReusableTextFormField(
                                text: "Email Address",
                                icon: Icons.email_outlined,
                                controller: _emailController,
                                check: false,
                              ),
                              SizedBox(height: isWeb ? 16 : 2.h),
                              ReusableTextFormField(
                                text: "Password",
                                icon: Icons.lock_outline,
                                controller: _passwordController,
                                check: true,
                                isPasswordType: true,
                              ),
                            ],
                          ),
                        ),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: navigateToRecoveryScreen,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: tealColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isWeb ? 16 : 2.h),

                        // Sign In Button
                        Consumer(builder: (context, ref, child) {
                          return SizedBox(
                            width: double.infinity,
                            height: isWeb ? 50 : 6.h,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  ref
                                      .read(userProvider.notifier)
                                      .updateEmail(_emailController.text);
                                  ref
                                      .read(userProvider.notifier)
                                      .updatePassword(_passwordController.text);
                                  // M-1 CALLING SERVICES AND UPDATING THE PROVIDER
                                  final loginResponse =
                                      await _authService.signInUser(
                                          _emailController.text,
                                          _passwordController.text,
                                          context,
                                          setLoading);
                                  if (loginResponse.isSuccess == true) {
                                    ref
                                        .read(userProvider.notifier)
                                        .loadUserFromSession(
                                            loginResponse.user);
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString(
                                        'token', loginResponse.token);
                                    await _authProvider.login(loginResponse);
                                    final authProvider =
                                        ref.read(authProviderNotifier);
                                    await authProvider.loadSession();
                                    ApiClient().init(authProvider);

                                    // Register device token for push notifications
                                    try {
                                      await NotificationService()
                                          .initAndRegister(
                                              loginResponse.user.id);
                                    } catch (e) {
                                      print('FCM register error: $e');
                                    }

                                    reusableSnackBar(context, "Welcome");

                                    navigateToHomeScreen();
                                  } else {
                                    // Show the actual error message from API
                                    // This includes verification email sent message
                                    reusableSnackBar(
                                        context, loginResponse.message);
                                  }
                                } else {
                                  reusableSnackBar(context, "Fill all fields");
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tealColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: isWeb ? 18 : 17.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          );
                        }),
                        SizedBox(height: isWeb ? 24 : 3.h),

                        // Register Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "New to Healthverse? ",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: isWeb ? 15 : 15.sp,
                              ),
                            ),
                            GestureDetector(
                              onTap: navigateToRegisterScreen,
                              child: Text(
                                "Register Now",
                                style: TextStyle(
                                  color: tealColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isWeb ? 15 : 15.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
