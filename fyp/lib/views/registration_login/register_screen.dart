import 'package:flutter/material.dart';
import 'package:fyp/provider/state_notifier_provider/user_provider.dart';
import 'package:fyp/views/registration_login/login_screen.dart';
import 'package:fyp/views/registration_login/widget/reusable_text_form_field.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../color/colors.dart';
import '../links/assets_link/asset_link.dart';
import '../widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'user_details_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fNameController = TextEditingController();
  final TextEditingController _lNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isPhoneValid = false;
  String completePhoneNumber = '';
  String? _phoneErrorText;
  // Password strength criteria
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigits = false;
  bool _hasSpecialChar = false;
  bool _hasMinLength = false;
  bool isLoading = false;

  int get _passwordStrengthCount {
    return (_hasUppercase ? 1 : 0) +
        (_hasLowercase ? 1 : 0) +
        (_hasDigits ? 1 : 0) +
        (_hasSpecialChar ? 1 : 0) +
        (_hasMinLength ? 1 : 0);
  }

  void setLoading(bool value) {
    setState(() {
      isLoading = value;
    });
  }

  void navigateToUserDetailScreen() {
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (context) => const UserDetailScreen()));
  }

  void navigateToLoginScreen() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const LoginScreen()));
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
                horizontal: isWeb ? 24 : 5.w,
                vertical: isWeb ? 32 : 5.h,
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
                      horizontal: isWeb ? 32 : 5.w,
                      vertical: isWeb ? 32 : 4.h,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        SizedBox(
                          height: isWeb ? 60 : 6.h,
                          child: Image.asset(logo),
                        ),
                        SizedBox(height: isWeb ? 8 : 1.h),
                        Text(
                          'Healthverse',
                          style: TextStyle(
                            fontSize: isWeb ? 20 : 16.sp,
                            fontWeight: FontWeight.bold,
                            color: tealColor,
                          ),
                        ),
                        SizedBox(height: isWeb ? 16 : 2.h),

                        // Create Account Text
                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: isWeb ? 28 : 20.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: isWeb ? 8 : 1.h),
                        Text(
                          'Sign up to manage your health',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : 15.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: isWeb ? 24 : 3.h),

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ReusableTextFormField(
                                      text: "First Name",
                                      icon: Icons.person_outline,
                                      controller: _fNameController,
                                      check: false,
                                    ),
                                  ),
                                  SizedBox(width: isWeb ? 16 : 2.w),
                                  Expanded(
                                    child: ReusableTextFormField(
                                      text: "Last Name",
                                      icon: Icons.person_outline,
                                      controller: _lNameController,
                                      check: false,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isWeb ? 16 : 2.h),
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
                              SizedBox(height: isWeb ? 8 : 1.h),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCriteriaRow(
                                      'At least 8 characters', _hasMinLength),
                                  _buildCriteriaRow(
                                      'Has lowercase letter', _hasLowercase),
                                  _buildCriteriaRow(
                                      'Has uppercase letter', _hasUppercase),
                                  _buildCriteriaRow('Has number', _hasDigits),
                                  _buildCriteriaRow(
                                      'Has special character', _hasSpecialChar),
                                ],
                              ),
                              SizedBox(height: isWeb ? 16 : 2.h),
                              ReusableTextFormField(
                                text: "Confirm Password",
                                icon: Icons.lock_outline,
                                controller: _confirmPasswordController,
                                check: true,
                                isPasswordType: true,
                              ),
                              SizedBox(height: isWeb ? 16 : 2.h),
                              IntlPhoneField(
                                controller: _phoneController,
                                initialCountryCode: 'PK',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                onChanged: (phone) {
                                  setState(() {
                                    completePhoneNumber = phone.completeNumber;
                                    _isPhoneValid =
                                        completePhoneNumber.isNotEmpty;
                                    if (_isPhoneValid) {
                                      _phoneErrorText = null;
                                    }
                                  });
                                },
                                onCountryChanged: (country) {},
                                decoration: InputDecoration(
                                  labelText: "Phone Number",
                                  labelStyle: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                  errorText: _phoneErrorText,
                                  filled: true,
                                  fillColor: Colors.white,
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.auto,
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: isWeb ? 18 : 16.0,
                                      horizontal: isWeb ? 24 : 20.0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade400),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(
                                        color: tealColor, width: 2.0),
                                  ),
                                ),
                              ),
                              SizedBox(height: isWeb ? 24 : 3.h),
                              Consumer(builder: (context, ref, child) {
                                return SizedBox(
                                  width: isWeb ? 300 : double.infinity,
                                  height: isWeb ? 52 : 6.h,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      if (_formKey.currentState!.validate() &&
                                          _isPhoneValid) {
                                        if (_passwordController.text ==
                                            _confirmPasswordController.text) {
                                          // require at least 5 of 5 criteria
                                          if (_passwordStrengthCount >= 5) {
                                            ref
                                                .read(userProvider.notifier)
                                                .updateFName(
                                                    _fNameController.text);
                                            ref
                                                .read(userProvider.notifier)
                                                .updateLName(
                                                    _lNameController.text);
                                            ref
                                                .read(userProvider.notifier)
                                                .updateEmail(
                                                    _emailController.text);
                                            ref
                                                .read(userProvider.notifier)
                                                .updatePassword(
                                                    _passwordController.text);
                                            ref
                                                .read(userProvider.notifier)
                                                .updateNumber(
                                                    _phoneController.text);
                                            navigateToUserDetailScreen();
                                          } else {
                                            reusableSnackBar(context,
                                                'Password is not strong enough. Please follow the criteria.');
                                          }
                                        } else {
                                          reusableSnackBar(context,
                                              "Password and confirm password must match");
                                        }
                                      } else {
                                        if (!_isPhoneValid) {
                                          setState(() {
                                            _phoneErrorText =
                                                'Phone number can\'t be empty';
                                          });
                                        }
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
                                              fontSize: isWeb ? 18 : 17.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                );
                              }),
                              SizedBox(height: isWeb ? 24 : 3.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Already have an account? ",
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: isWeb ? 16 : 15.sp,
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: navigateToLoginScreen,
                                      child: Text(
                                        "Sign In",
                                        style: TextStyle(
                                          color: tealColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isWeb ? 16 : 15.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      _updatePasswordCriteria(_passwordController.text);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fNameController.dispose();
    _lNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
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
