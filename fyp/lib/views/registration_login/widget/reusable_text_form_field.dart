import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../../../utils/responsive_helper.dart';
import '../../../utils/validators.dart';
import '../../color/colors.dart';

class ReusableTextFormField extends StatefulWidget {
  final String text;
  final IconData icon;
  final TextEditingController controller;
  final bool check;
  final bool isPasswordType;

  const ReusableTextFormField(
      {super.key,
      required this.text,
      required this.icon,
      required this.controller,
      required this.check,
      this.isPasswordType = false});

  @override
  State<ReusableTextFormField> createState() => _ReusableTextFormFieldState();
}

class _ReusableTextFormFieldState extends State<ReusableTextFormField> {
  late bool _isObsecure;

  @override
  void initState() {
    super.initState();
    _isObsecure = widget.isPasswordType;
  }

  String? _validate(String? value) {
    final fieldName = widget.text.toLowerCase();

    if (value == null || value.trim().isEmpty) {
      return "${widget.text} can't be empty";
    }

    // 2️⃣ PASSWORD VALIDATION
    if (widget.isPasswordType || fieldName.contains('password')) {
      // Length check (backend generates 8 chars)
      if (value.length < 8) {
        return "Password must be at least 8 characters";
      }

      // Character requirements (match C# generator)
      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
      final hasNumber = RegExp(r'\d').hasMatch(value);
      final hasSpecial =
          RegExp(r'[!@#$%^&*()\-\_=+\[\]{};:,.<>?]').hasMatch(value);

      // Apply strict rules ONLY for new/reset/register passwords
      final isOldPassword = fieldName.contains('old') ||
          fieldName.contains('previous') ||
          fieldName.contains('current');

      if (!isOldPassword) {
        if (!(hasLetter && hasNumber && hasSpecial)) {
          return "Password must contain a letter, number, and special character";
        }
      }
    }

    // 3️⃣ EMAIL VALIDATION
    if (fieldName.contains('email')) {
      final emailError = Validators.validateEmail(value);
      if (emailError != null) return emailError;
    }

    // 4️⃣ NAME VALIDATION
    if (fieldName.contains('name') && !fieldName.contains('user')) {
      final trimmed = value.trim();

      if (fieldName.contains('first') || fieldName.contains('last')) {
        if (trimmed.length < 3) {
          return "Must be at least 3 characters";
        }
        if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(trimmed)) {
          return "Only letters, spaces, hyphens, and apostrophes allowed";
        }
      } else {
        if (trimmed.length < 2) {
          return "Must be at least 2 characters";
        }
        if (!Validators.nameRegex.hasMatch(trimmed)) {
          return "Only letters, spaces, and hyphens allowed";
        }
      }
    }

    // 5️⃣ ADDRESS VALIDATION
    if (fieldName.contains('address')) {
      final addrError = Validators.validateAddress(value);
      if (addrError != null) return addrError;
    }

    // 6️⃣ AGE VALIDATION
    if (fieldName.contains('age')) {
      if (!Validators.ageRegex.hasMatch(value)) {
        return "Please enter a valid age (1–150)";
      }
    }

    // 7️⃣ CNIC VALIDATION
    if (fieldName.contains('cnic')) {
      final cleanCnic = value.replaceAll('-', '');
      if (!Validators.cnicWithoutDashRegex.hasMatch(cleanCnic)) {
        return "Please enter a valid CNIC (XXXXX-XXXXXXX-X)";
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);

    return TextFormField(
      controller: widget.controller,
      obscureText: _isObsecure,
      enableSuggestions: false,
      autocorrect: false,
      cursorColor: Colors.black,
      validator: _validate,
      style: TextStyle(
        color: Colors.black.withOpacity(0.9),
      ),
      keyboardType: widget.isPasswordType
          ? TextInputType.visiblePassword
          : widget.text.toLowerCase().contains('email')
              ? TextInputType.emailAddress
              : widget.text.toLowerCase().contains('age')
                  ? TextInputType.number
                  : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(
          widget.icon,
          color: iconColor,
        ),
        suffixIcon: widget.isPasswordType
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _isObsecure = !_isObsecure;
                  });
                },
                child: Icon(
                  _isObsecure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
              )
            : null,
        labelText: widget.text,
        labelStyle: TextStyle(
          color: Colors.grey[600],
        ),
        filled: true,
        fillColor: Colors.white,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: EdgeInsets.symmetric(
          vertical: isWeb ? 16.0 : 2.h,
          horizontal: isWeb ? 20.0 : 4.w,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWeb ? 12.0 : 3.w),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWeb ? 12.0 : 3.w),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWeb ? 12.0 : 3.w),
          borderSide: const BorderSide(color: tealColor, width: 2.0),
        ),
      ),
    );
  }
}
