/// Comprehensive input validation utilities for HealthVerse
/// Contains regex patterns and validation functions for all input types

class Validators {
  // ============== REGEX PATTERNS ==============

  /// Email validation regex (RFC 5322 compliant)
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Phone number regex (Pakistani format: 03XX-XXXXXXX or 923XX-XXXXXXX)
  static final RegExp phoneRegex = RegExp(
    r'^(03[0-9]{2}[0-9]{7}|92[0-9]{10}|\+92[0-9]{10})$',
  );

  /// International phone (10-15 digits)
  static final RegExp internationalPhoneRegex = RegExp(
    r'^\+?[0-9]{10,15}$',
  );

  /// Name validation (letters, spaces, hyphens, apostrophes, 2-50 chars)
  static final RegExp nameRegex = RegExp(
    r"^[a-zA-Z\s\-']{2,50}$",
  );

  /// Password regex (min 8 chars, at least one letter and one number)
  static final RegExp passwordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$',
  );

  /// Strong password (min 8 chars, uppercase, lowercase, number, special char)
  static final RegExp strongPasswordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
  );

  /// CNIC regex (Pakistani format: XXXXX-XXXXXXX-X)
  static final RegExp cnicRegex = RegExp(
    r'^[0-9]{5}-[0-9]{7}-[0-9]$',
  );

  /// CNIC without dashes (13 digits)
  static final RegExp cnicWithoutDashRegex = RegExp(
    r'^[0-9]{13}$',
  );

  /// PMDC Number (Pakistan Medical & Dental Council)
  static final RegExp pmdcRegex = RegExp(
    r'^[0-9]{1,10}-[A-Z]$|^[0-9]{1,10}$',
  );

  /// Age validation (1-150)
  static final RegExp ageRegex = RegExp(
    r'^(1[0-4][0-9]|150|[1-9][0-9]|[1-9])$',
  );

  /// Postal code (5-10 alphanumeric)
  static final RegExp postalCodeRegex = RegExp(
    r'^[A-Za-z0-9]{5,10}$',
  );

  /// URL validation
  static final RegExp urlRegex = RegExp(
    r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
  );

  /// Only letters (no numbers/special chars)
  static final RegExp lettersOnlyRegex = RegExp(
    r'^[a-zA-Z\s]+$',
  );

  /// Only digits
  static final RegExp digitsOnlyRegex = RegExp(
    r'^[0-9]+$',
  );

  /// Alphanumeric only
  static final RegExp alphanumericRegex = RegExp(
    r'^[a-zA-Z0-9]+$',
  );

  /// Medical license number (alphanumeric with optional dashes, 5-20 chars)
  static final RegExp medicalLicenseRegex = RegExp(
    r'^[A-Za-z0-9\-]{5,20}$',
  );

  /// Blood pressure format (e.g., 120/80)
  static final RegExp bloodPressureRegex = RegExp(
    r'^[0-9]{2,3}\/[0-9]{2,3}$',
  );

  /// Blood sugar level (numeric, can have decimal)
  static final RegExp bloodSugarRegex = RegExp(
    r'^[0-9]+(\.[0-9]{1,2})?$',
  );

  // ============== VALIDATION FUNCTIONS ==============

  /// Validate email address
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address.';
    }
    final email = value.trim();

    if (email.length < 6 || email.length > 30) {
      return 'Email must be between 6 and 30 characters.';
    }

    // Basic split into local and domain parts
    final parts = email.split('@');
    if (parts.length != 2) {
      return 'Please enter a valid email (for example: name@example.com).';
    }
    final local = parts[0];
    final domainFull = parts[1];
    if (local.isEmpty || domainFull.isEmpty) {
      return 'Please enter a valid email (for example: name@example.com).';
    }

    // If using Gmail, enforce username (local part) length rules
    if (domainFull.toLowerCase().startsWith('gmail')) {
      if (local.length < 6 || local.length > 30) {
        return 'For Gmail addresses, the part before @ must be 6–30 characters.';
      }
    }

    // Ensure there's a dot for TLD
    final lastDot = domainFull.lastIndexOf('.');
    if (lastDot <= 0 || lastDot == domainFull.length - 1) {
      return 'Please enter a valid email (domain must include a dot, e.g., example.com).';
    }

    final firstLabel = domainFull.split('.').first;
    final tld = domainFull.substring(lastDot + 1);

    // If domain label starts with 'g', require exact 'gmail'
    if (firstLabel.toLowerCase().startsWith('g')) {
      if (firstLabel.toLowerCase() != 'gmail') {
        return 'If your email provider starts with "g", please use "gmail" (e.g., name@gmail.com).';
      }
    } else {
      if (firstLabel.length < 2) {
        return 'Please use a valid email domain (at least 2 characters before the dot).';
      }
    }

    // If gmail, require .com
    if (firstLabel.toLowerCase() == 'gmail') {
      if (tld.toLowerCase() != 'com') {
        return 'Gmail addresses must end with .com (for example: name@gmail.com).';
      }
    }

    // TLD must be at least 2 characters (covers the .c rule)
    if (tld.length < 2) {
      return 'The part after the dot (like .com) must be at least 2 characters.';
    }

    // Final structural check using existing regex
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email (for example: name@example.com).';
    }

    return null;
  }

  /// Validate phone number (Pakistani format)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final cleanPhone = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!phoneRegex.hasMatch(cleanPhone) &&
        !internationalPhoneRegex.hasMatch(cleanPhone)) {
      return 'Please enter a valid phone number (e.g., 03XX-XXXXXXX)';
    }
    return null;
  }

  /// Validate name
  static String? validateName(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    if (value.trim().length > 50) {
      return '$fieldName must not exceed 50 characters';
    }
    if (!nameRegex.hasMatch(value.trim())) {
      return '$fieldName can only contain letters, spaces, hyphens, and apostrophes';
    }
    return null;
  }

  /// Validate password (minimum requirements)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!passwordRegex.hasMatch(value)) {
      return 'Password must contain at least one letter and one number';
    }
    return null;
  }

  /// Validate strong password
  static String? validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!strongPasswordRegex.hasMatch(value)) {
      return 'Password must contain uppercase, lowercase, number, and special character';
    }
    return null;
  }

  /// Validate confirm password
  static String? validateConfirmPassword(
      String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != originalPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validate CNIC
  static String? validateCNIC(String? value) {
    if (value == null || value.isEmpty) {
      return 'CNIC is required';
    }
    final cleanCnic = value.replaceAll('-', '');
    if (!cnicWithoutDashRegex.hasMatch(cleanCnic)) {
      return 'Please enter a valid CNIC (XXXXX-XXXXXXX-X)';
    }
    return null;
  }

  /// Validate age
  static String? validateAge(String? value) {
    if (value == null || value.isEmpty) {
      return 'Age is required';
    }
    if (!ageRegex.hasMatch(value)) {
      return 'Please enter a valid age (1-150)';
    }
    return null;
  }

  /// Validate date of birth
  static String? validateDOB(DateTime? selectedDate) {
    if (selectedDate == null) {
      return 'Please select your date of birth.';
    }

    final now = DateTime.now();
    // Calculate approximate age using year difference
    final age = now.year - selectedDate.year;

    // 1. Check for future dates
    if (selectedDate.isAfter(now)) {
      return 'Date of birth cannot be in the future.';
    }

    // 2. Check for realistic age (e.g., 120 years max)
    if (age > 120) {
      return 'Please enter a valid year of birth.';
    }

    // 3. Minimum age requirement (e.g., 13 years old)
    if (age < 13) {
      return 'You must be at least 13 years old to use HealthVerse.';
    }

    return null;
  }

  /// Validate required field (generic)
  static String? validateRequired(String? value,
      {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate blood pressure
  static String? validateBloodPressure(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    if (!bloodPressureRegex.hasMatch(value)) {
      return 'Please enter valid blood pressure (e.g., 120/80)';
    }
    return null;
  }

  /// Validate blood sugar
  static String? validateBloodSugar(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    if (!bloodSugarRegex.hasMatch(value)) {
      return 'Please enter a valid number';
    }
    return null;
  }

  /// Validate address
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your residential address.';
    }

    final address = value.trim();

    // 1. Minimum length to avoid very short/dummy values
    if (address.length < 10) {
      return 'Please enter a complete address (street, city, etc.).';
    }

    // 2. Maximum length to prevent database overflow
    if (address.length > 150) {
      return 'Address is too long (max 150 characters).';
    }

    // 3. Ensure it contains at least one number and some letters
    final hasNumber = RegExp(r'[0-9]').hasMatch(address);
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(address);

    if (!hasLetters) {
      return 'Address must contain street or building names.';
    }

    // 4. Pattern check for dummy data (repeating chars like "aaaaaa")
    if (RegExp(r'(.)\1{4,}').hasMatch(address.replaceAll(' ', ''))) {
      return 'Please enter a real address, not repeating characters.';
    }

    return null;
  }

  /// Validate PMDC number
  static String? validatePMDC(String? value) {
    if (value == null || value.isEmpty) {
      return 'PMDC number is required';
    }
    if (!pmdcRegex.hasMatch(value.trim())) {
      return 'Please enter a valid PMDC number';
    }
    return null;
  }

  static String? validateURL(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (!urlRegex.hasMatch(value)) {
      return 'Please enter a valid URL';
    }
    return null;
  }

  static String? validateMinLength(String? value, int minLength,
      {String fieldName = 'This field'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    return null;
  }

  static String? validateMaxLength(String? value, int maxLength,
      {String fieldName = 'This field'}) {
    if (value != null && value.length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }
    return null;
  }

  static bool matches(String value, RegExp pattern) {
    return pattern.hasMatch(value);
  }

  /// Format phone number with dashes
  static String formatPhoneNumber(String phone) {
    final clean = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (clean.length == 11 && clean.startsWith('03')) {
      return '${clean.substring(0, 4)}-${clean.substring(4)}';
    }
    return phone;
  }

  /// Format CNIC with dashes
  static String formatCNIC(String cnic) {
    final clean = cnic.replaceAll('-', '');
    if (clean.length == 13) {
      return '${clean.substring(0, 5)}-${clean.substring(5, 12)}-${clean.substring(12)}';
    }
    return cnic;
  }
}
