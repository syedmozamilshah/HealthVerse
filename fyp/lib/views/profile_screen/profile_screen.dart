import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/provider/state_notifier_provider/user_provider.dart';
import 'package:fyp/views/reset_recovery_password_screen/reset_screen.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../provider/state_notifier_provider/auth_provider/auth_provider.dart';
import '../../services/profile_service/profile_service.dart';
import '../../services/notification_service/notification_service.dart';
import '../../models/notification/notification_preference.dart';
import '../color/colors.dart';
import '../registration_login/login_screen.dart';
import 'widget/edit_alert_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;

  const ProfileScreen({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Uint8List? _imageBytes;
  final ProfileService _profileService = ProfileService();
  final EditAlertDialog _editAlertDialog = EditAlertDialog();
  bool isLoading = false;
  NotificationPreference? _prefs;
  bool _prefsLoading = false;

  @override
  void initState() {
    super.initState();
  }

  void setLoading(bool value) {
    if (!mounted) return;
    setState(() {
      isLoading = value;
    });
  }

  void navigateToResetPasswordScreen() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ResetPassword()));
  }

  void updateAddres(String value) {
    _profileService.updateAddress(value, context, setLoading);
  }

  void updateName(String fName, String lName) {
    _profileService.updateName(fName, lName, context, setLoading);
  }

  void updateNumber(String value) {
    _profileService.updateNumber(value, context, setLoading);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);
    final contentMaxWidth = ResponsiveHelper.getContentWidth(context);

    return Consumer(
      builder: (context, ref, child) {
        final user = ref.watch(userProvider);
        return Scaffold(
          backgroundColor: primaryColor,
          body: Container(
            decoration: const BoxDecoration(
              gradient: appGradient,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWeb ? 24 : 4.w,
                      vertical: isWeb ? 16 : 2.h,
                    ),
                    child: Row(
                      children: [
                        if (widget.showBackButton)
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
                                child: Icon(Icons.arrow_back,
                                    color: Colors.white,
                                    size: isWeb ? 24 : 20.sp),
                              ),
                            ),
                          ),
                        if (widget.showBackButton)
                          SizedBox(width: isWeb ? 20 : 4.w),
                        Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: isWeb ? 28 : 20.sp,
                            fontWeight: FontWeight.normal,
                            color: const Color.fromARGB(255, 240, 247, 245),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentMaxWidth),
                        child: ListView(
                          padding: EdgeInsets.only(
                            left: isWeb ? 24 : 4.w,
                            right: isWeb ? 24 : 4.w,
                            bottom: widget.showBackButton
                                ? 0
                                : (isWeb ? 100 : 12.h),
                          ),
                          children: [
                            SizedBox(height: isWeb ? 16 : 1.h),

                            // Profile Card with Image and Name
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: isWeb ? 0 : 2.w),
                              padding: EdgeInsets.all(isWeb ? 24 : 4.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(isWeb ? 20 : 5.w),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Profile Image
                                  Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: tealColor,
                                            width: 3,
                                          ),
                                        ),
                                        child: _imageBytes != null
                                            ? CircleAvatar(
                                                radius: isWeb ? 60 : 12.w,
                                                backgroundImage:
                                                    MemoryImage(_imageBytes!),
                                              )
                                            : user.imageUrl != ''
                                                ? CircleAvatar(
                                                    radius: isWeb ? 60 : 12.w,
                                                    backgroundImage:
                                                        NetworkImage(
                                                            user.imageUrl),
                                                  )
                                                : CircleAvatar(
                                                    radius: isWeb ? 60 : 12.w,
                                                    backgroundColor: tealColor
                                                        .withOpacity(0.2),
                                                    child: Icon(
                                                      Icons.person,
                                                      size: isWeb ? 60 : 12.w,
                                                      color: tealColor,
                                                    ),
                                                  ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () async {
                                            XFile? img = await _profileService
                                                .pickImage();
                                            if (img != null) {
                                              // Validate image format and size
                                              final validationError =
                                                  await _profileService
                                                      .validateImage(img);
                                              if (validationError != null) {
                                                if (context.mounted) {
                                                  reusableSnackBar(
                                                      context, validationError);
                                                }
                                                return;
                                              }

                                              // Read bytes for preview (works on both web and mobile)
                                              final bytes =
                                                  await img.readAsBytes();
                                              if (!mounted) return;
                                              setState(() {
                                                _imageBytes = bytes;
                                              });
                                              // M-2 FOR UPDATING THE IMAGE IN THE DATABASE AND GETTING THE NEW URL
                                              final String? url =
                                                  await _profileService
                                                      .updateUserProfileImage(
                                                          img,
                                                          context,
                                                          setLoading);
                                              if (url != null) {
                                                ref
                                                    .watch(
                                                        userProvider.notifier)
                                                    .updateImageUrl(url);
                                              }
                                            }
                                          },
                                          child: Container(
                                            padding:
                                                EdgeInsets.all(isWeb ? 8 : 2.w),
                                            decoration: BoxDecoration(
                                              color: tealColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 2),
                                            ),
                                            child: Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: isWeb ? 20 : 4.w,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isWeb ? 16 : 2.h),
                                  // Name
                                  Text(
                                    "${user.fName} ${user.lName}",
                                    style: TextStyle(
                                      fontSize: isWeb ? 24 : 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: isWeb ? 4 : 0.5.h),
                                  // Email
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      fontSize: isWeb ? 15 : 15.sp,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: isWeb ? 24 : 3.h),

                            // My Details Header with Settings Icon
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: isWeb ? 0 : 2.w),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'My Details',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: isWeb ? 20 : 17.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: isWeb ? 12 : 1.h),

                            // Details Cards
                            _buildDetailCard(
                              context: context,
                              isWeb: isWeb,
                              label: "Name",
                              value: "${user.fName} ${user.lName}".trim(),
                              icon: Icons.person_outline,
                              onPressed: () async {
                                Map<String, String>? result =
                                    await _editAlertDialog.editNameDialog(
                                  context,
                                  user.fName,
                                  user.lName,
                                );
                                if (!mounted || result == null) {
                                  return;
                                }
                                final fName = result['firstName'] ?? '';
                                final lName = result['lastName'] ?? '';
                                if (fName.isNotEmpty) {
                                  // M-2 FOR UPDATING THE NAME IN THE DATABASE
                                  updateName(fName, lName);
                                  ref
                                      .watch(userProvider.notifier)
                                      .updateName(fName, lName);
                                  final auth = ref.read(authProviderNotifier);
                                  await auth.updateUserInSession(user.copyWith(
                                      fName: fName, lName: lName));
                                }
                              },
                            ),

                            _buildDetailCard(
                              context: context,
                              isWeb: isWeb,
                              label: "Phone Number",
                              value: user.number.contains("+92")
                                  ? user.number
                                  : "+92${user.number}",
                              icon: Icons.phone_outlined,
                              onPressed: () async {
                                final String initialNumber = user.number;
                                // Prepare displayed national number for the IntlPhoneField controller
                                String displayedNumber;
                                if (initialNumber.startsWith('+92')) {
                                  displayedNumber =
                                      initialNumber.replaceFirst('+92', '');
                                } else if (initialNumber.startsWith('+')) {
                                  // remove leading + for display; IntlPhoneField will show country code selector
                                  displayedNumber =
                                      initialNumber.replaceFirst('+', '');
                                } else {
                                  displayedNumber = initialNumber;
                                }

                                String completePhoneNumber =
                                    initialNumber.startsWith('+')
                                        ? initialNumber
                                        : '+92${initialNumber}';

                                final TextEditingController _phoneController =
                                    TextEditingController(
                                        text: displayedNumber);

                                await showDialog(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    return AlertDialog(
                                      title: const Text('Update Phone Number'),
                                      content: IntlPhoneField(
                                        controller: _phoneController,
                                        initialCountryCode: 'PK',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ],
                                        onChanged: (phone) {
                                          completePhoneNumber =
                                              phone.completeNumber;
                                        },
                                        decoration: InputDecoration(
                                          labelText: "Phone Number",
                                          labelStyle: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          floatingLabelBehavior:
                                              FloatingLabelBehavior.auto,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 16.0,
                                                  horizontal: 20.0),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                            borderSide: const BorderSide(
                                                color: Colors.grey),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade400),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                            borderSide: const BorderSide(
                                                color: tealColor, width: 2.0),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogContext),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(dialogContext);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: tealColor,
                                          ),
                                          child: const Text('Update'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (!mounted || completePhoneNumber.isEmpty) {
                                  return;
                                }

                                if (completePhoneNumber.trim().isNotEmpty) {
                                  // M-2 FOR UPDATING THE PHONE NUMBER IN THE DATABASE
                                  updateNumber(completePhoneNumber);
                                  ref
                                      .watch(userProvider.notifier)
                                      .updateNumber(completePhoneNumber);
                                  final auth = ref.read(authProviderNotifier);
                                  await auth.updateUserInSession(user.copyWith(
                                      number: completePhoneNumber));
                                }
                              },
                            ),

                            _buildDetailCard(
                              context: context,
                              isWeb: isWeb,
                              label: "Address",
                              value: user.address.isNotEmpty
                                  ? user.address
                                  : "Not set",
                              icon: Icons.location_on_outlined,
                              onPressed: () async {
                                String? newValue = await _editAlertDialog
                                    .editDialog(context, 'Address',
                                        initialText: user.address);
                                if (!mounted ||
                                    newValue == null ||
                                    newValue.trim().isEmpty) {
                                  return;
                                }
                                if (newValue.trim().isNotEmpty) {
                                  // M-2 FOR UPDATING THE ADDRESS IN THE DATABASE
                                  updateAddres(newValue);
                                  ref
                                      .watch(userProvider.notifier)
                                      .updateAddress(newValue);
                                  final auth = ref.read(authProviderNotifier);
                                  await auth.updateUserInSession(
                                      user.copyWith(address: newValue));
                                }
                              },
                            ),

                            SizedBox(height: isWeb ? 24 : 3.h),

                            // Security Section
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: isWeb ? 0 : 2.w),
                              child: Text(
                                'Preferences and Security',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: isWeb ? 20 : 17.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            SizedBox(height: isWeb ? 12 : 1.h),
                            // Notification Preferences Section
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: isWeb ? 0 : 2.w),
                              padding: EdgeInsets.all(isWeb ? 24 : 4.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(isWeb ? 20 : 5.w),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notifications',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: isWeb ? 20 : 17.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: isWeb ? 12 : 1.h),
                                  Builder(builder: (context) {
                                    final user = ref.watch(userProvider);
                                    if (!_prefsLoading && _prefs == null) {
                                      _prefsLoading = true;
                                      NotificationService()
                                          .getPreferences(user.id)
                                          .then((value) {
                                        if (!mounted) return;
                                        setState(() {
                                          _prefs =
                                              value ?? NotificationPreference();
                                        });
                                      }).whenComplete(() {
                                        if (mounted) setState(() {});
                                      });
                                    }

                                    if (_prefs == null) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }

                                    return Column(
                                      children: [
                                        SwitchListTile(
                                          title:
                                              const Text('Appointment Alerts'),
                                          value:
                                              _prefs!.appointmentAlertsEnabled,
                                          onChanged: (v) {
                                            setState(() => _prefs!
                                                .appointmentAlertsEnabled = v);
                                          },
                                        ),
                                        SwitchListTile(
                                          title:
                                              const Text('Medication Alerts'),
                                          value:
                                              _prefs!.medicationAlertsEnabled,
                                          onChanged: (v) {
                                            setState(() => _prefs!
                                                .medicationAlertsEnabled = v);
                                          },
                                        ),
                                        SwitchListTile(
                                          title: Row(
                                            children: [
                                              const Text('Vitals Reminders'),
                                              SizedBox(width: isWeb ? 8 : 2.w),
                                              GestureDetector(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Vitals Reminders'),
                                                      content: const Text(
                                                        'Notifications will be sent at:\n\n'
                                                        '• 1:00 PM (Pakistan Time)\n'
                                                        '• 8:00 PM (Pakistan Time)\n\n'
                                                        'You will receive daily reminders to log your vitals at these times.',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context),
                                                          child:
                                                              const Text('OK'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                                child: Icon(
                                                  Icons.info_outline,
                                                  size: isWeb ? 20 : 18.sp,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                          value: _prefs!.vitalsRemindersEnabled,
                                          onChanged: (v) {
                                            setState(() => _prefs!
                                                .vitalsRemindersEnabled = v);
                                          },
                                        ),
                                        SizedBox(height: isWeb ? 12 : 1.h),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            ElevatedButton(
                                              onPressed: isLoading
                                                  ? null
                                                  : () async {
                                                      final user = ref
                                                          .read(userProvider);
                                                      setLoading(true);
                                                      try {
                                                        await NotificationService()
                                                            .updatePreferences(
                                                                user.id,
                                                                _prefs!);
                                                        if (mounted) {
                                                          reusableSnackBar(
                                                              context,
                                                              'Preferences updated');
                                                        }
                                                      } catch (e) {
                                                        if (mounted) {
                                                          reusableSnackBar(
                                                              context,
                                                              'Failed to update preferences');
                                                        }
                                                      } finally {
                                                        setLoading(false);
                                                      }
                                                    },
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        )
                                      ],
                                    );
                                  })
                                ],
                              ),
                            ),

                            SizedBox(height: isWeb ? 12 : 1.h),

                            // Change Password Button
                            _buildSecurityOption(
                              context: context,
                              isWeb: isWeb,
                              label: "Change Password",
                              subtitle: "Update your password",
                              icon: Icons.lock_outline,
                              // M-1 FOR NAVIGATING TO THE RESET PASSWORD SCREEN
                              onPressed: navigateToResetPasswordScreen,
                            ),

                            SizedBox(height: isWeb ? 24 : 3.h),

                            // Save Changes Button (optional visual)
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: isWeb ? 0 : 2.w),
                              width: double.infinity,
                              height: isWeb ? 50 : 6.h,
                              child: ElevatedButton(
                                onPressed: () {
                                  reusableSnackBar(context,
                                      'All changes are saved automatically!');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tealColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(isWeb ? 12 : 4.w),
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isWeb ? 16 : 15.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: isWeb ? 20 : 2.h),

                            // Logout Button
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: isWeb ? 0 : 2.w),
                              width: double.infinity,
                              height: isWeb ? 50 : 6.h,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.clear();
                                  final authProvider = AuthProvider();
                                  await authProvider.logout();
                                  if (context.mounted) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(isWeb ? 12 : 4.w),
                                    side: BorderSide(
                                        color: Colors.red.withOpacity(0.3)),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout_rounded,
                                        size: isWeb ? 22 : 18.sp),
                                    SizedBox(width: isWeb ? 10 : 2.w),
                                    Text(
                                      'Logout',
                                      style: TextStyle(
                                        fontSize: isWeb ? 16 : 15.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: isWeb ? 40 : 4.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCard({
    required BuildContext context,
    required bool isWeb,
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isWeb ? 0 : 2.w,
        vertical: isWeb ? 6 : 1.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 16 : 4.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isWeb ? 20 : 4.w,
          vertical: isWeb ? 8 : 1.h,
        ),
        leading: Container(
          padding: EdgeInsets.all(isWeb ? 10 : 2.5.w),
          decoration: BoxDecoration(
            color: tealColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isWeb ? 10 : 3.w),
          ),
          child: Icon(icon, color: tealColor, size: isWeb ? 24 : 5.w),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: isWeb ? 14 : 14.sp,
            color: Colors.grey[600],
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: isWeb ? 16 : 15.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        trailing: IconButton(
          onPressed: onPressed,
          icon: Icon(
            Icons.edit_outlined,
            color: tealColor,
            size: isWeb ? 22 : 5.w,
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityOption({
    required BuildContext context,
    required bool isWeb,
    required String label,
    required String subtitle,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isWeb ? 0 : 2.w,
        vertical: isWeb ? 6 : 1.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 16 : 4.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isWeb ? 20 : 4.w,
          vertical: isWeb ? 8 : 1.h,
        ),
        leading: Container(
          padding: EdgeInsets.all(isWeb ? 10 : 2.5.w),
          decoration: BoxDecoration(
            color: tealColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isWeb ? 10 : 3.w),
          ),
          child: Icon(icon, color: tealColor, size: isWeb ? 24 : 5.w),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: isWeb ? 16 : 15.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: isWeb ? 13 : 12.sp,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: tealColor,
          size: isWeb ? 24 : 6.w,
        ),
        onTap: onPressed,
      ),
    );
  }
}
