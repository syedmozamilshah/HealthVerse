import 'package:flutter/material.dart';
import 'package:fyp/services/auth_service/auth_service.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:fyp/views/links/assets_link/asset_link.dart';
import 'package:fyp/views/registration_login/widget/reusable_text_form_field.dart';

import '../color/colors.dart';

class ResetPassword extends StatefulWidget {
  const ResetPassword({super.key});

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final AuthService _authService = AuthService();
  final TextEditingController _prePassowrdController = TextEditingController();
  final TextEditingController _newPassowrdController = TextEditingController();
  final TextEditingController _confirmNewPassowrdController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  // Password strength criteria
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigits = false;
  bool _hasSpecialChar = false;
  bool _hasMinLength = false;

  int get _passwordStrengthCount {
    return (_hasUppercase ? 1 : 0) +
        (_hasLowercase ? 1 : 0) +
        (_hasDigits ? 1 : 0) +
        (_hasSpecialChar ? 1 : 0) +
        (_hasMinLength ? 1 : 0);
  }

  void navigatoToProfileScreen() {
    Navigator.pop(context);
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
          gradient: appGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back Button Header
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 24 : 4.w,
                  vertical: isWeb ? 16 : 2.h,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: EdgeInsets.all(isWeb ? 10 : 2.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: isWeb ? 24 : 20.sp,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isWeb ? 16 : 3.w),
                    Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: isWeb ? 22 : 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
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

                              // Reset Password Text
                              Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: isWeb ? 28 : 22.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: isWeb ? 8 : 1.h),
                              Text(
                                'Create a new password',
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
                                      text: "Old Password",
                                      icon: Icons.lock_outline,
                                      controller: _prePassowrdController,
                                      check: true,
                                      isPasswordType: true,
                                    ),
                                    SizedBox(height: isWeb ? 16 : 2.h),
                                    ReusableTextFormField(
                                      text: "New Password",
                                      icon: Icons.lock_outline,
                                      controller: _newPassowrdController,
                                      check: true,
                                      isPasswordType: true,
                                    ),
                                    SizedBox(height: isWeb ? 8 : 1.h),
                                    // Password strength criteria UI
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildCriteriaRow(
                                            'At least 8 characters',
                                            _hasMinLength),
                                        _buildCriteriaRow(
                                            'Has lowercase letter',
                                            _hasLowercase),
                                        _buildCriteriaRow(
                                            'Has uppercase letter',
                                            _hasUppercase),
                                        _buildCriteriaRow(
                                            'Has number', _hasDigits),
                                        _buildCriteriaRow(
                                            'Has special character',
                                            _hasSpecialChar),
                                      ],
                                    ),
                                    SizedBox(height: isWeb ? 16 : 2.h),
                                    ReusableTextFormField(
                                      text: "Confirm New Password",
                                      icon: Icons.lock_outline,
                                      controller: _confirmNewPassowrdController,
                                      check: true,
                                      isPasswordType: true,
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: isWeb ? 32 : 4.h),

                              // Continue Button
                              SizedBox(
                                width: double.infinity,
                                height: isWeb ? 50 : 6.h,
                                child: ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () async {
                                          if (_formKey.currentState!
                                              .validate()) {
                                            if (_newPassowrdController.text ==
                                                _confirmNewPassowrdController
                                                    .text) {
                                              // require at least 5 of 5 criteria
                                              if (_passwordStrengthCount >= 5) {
                                                // M-1 CALLING SERVICES FOR AUTH
                                                await _authService.resetPassword(
                                                    _prePassowrdController.text,
                                                    _newPassowrdController.text,
                                                    context,
                                                    setLoading,
                                                    navigatoToProfileScreen);
                                              } else {
                                                reusableSnackBar(context,
                                                    'Password is not strong enough. Please follow the criteria.');
                                              }
                                            } else {
                                              reusableSnackBar(context,
                                                  'New passwords must match');
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tealColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          'Continue',
                                          style: TextStyle(
                                            fontSize: isWeb ? 18 : 17.sp,
                                            fontWeight: FontWeight.bold,
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _newPassowrdController.addListener(() {
      _updatePasswordCriteria(_newPassowrdController.text);
    });
  }

  @override
  void dispose() {
    _prePassowrdController.dispose();
    _newPassowrdController.dispose();
    _confirmNewPassowrdController.dispose();
    super.dispose();
  }

  void _updatePasswordCriteria(String pw) {
    setState(() {
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(pw);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(pw);
      _hasDigits = RegExp(r'\d').hasMatch(pw);
      _hasSpecialChar =
          RegExp(r'[!@#\$%\^&\*(),.?"/:{}|<>\-\\\[\];]').hasMatch(pw);
      _hasMinLength = pw.length >= 8;
    });
  }

  Widget _buildCriteriaRow(String text, bool satisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            satisfied ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: satisfied ? tealColor : Colors.grey,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: satisfied ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
