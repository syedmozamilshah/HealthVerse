import 'package:flutter/material.dart';
import 'package:fyp/services/auth_service/auth_service.dart';
import 'package:fyp/views/registration_login/login_screen.dart';
import 'package:fyp/views/registration_login/widget/reusable_text_form_field.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import '../color/colors.dart';
import '../links/assets_link/asset_link.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  bool isLoading = false;

  void setLoading(bool value) {
    setState(() {
      isLoading = value;
    });
  }

  void navigateToSignIn() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: loginGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      SizedBox(
                        height: 6.h,
                        child: Image.asset(logo),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        'Healthverse',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: tealColor,
                        ),
                      ),
                      SizedBox(height: 3.h),

                      // Reset Password Text
                      Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        'Enter your email to receive a reset link',
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.grey[600],
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4.h),

                      ReusableTextFormField(
                        text: "Email Address",
                        icon: Icons.email_outlined,
                        controller: _emailController,
                        check: true,
                      ),
                      SizedBox(height: 4.h),

                      SizedBox(
                        width: double.infinity,
                        height: 6.h,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_emailController.text.isNotEmpty) {
                              // M-1 CALLING SERVICES FOR AUTH
                              await _authService.forgotPassword(
                                  _emailController.text,
                                  context,
                                  setLoading,
                                  navigateToSignIn);
                            } else {
                              reusableSnackBar(
                                  context, 'Please enter your email');
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
                                  color: Colors.white,
                                )
                              : Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
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
