import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/views/registration_login/login_screen.dart';
import 'package:fyp/views/registration_login/widget/reusable_drop_down.dart';
import 'package:fyp/views/registration_login/widget/reusable_text_form_field.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../../provider/state_notifier_provider/user_provider.dart';
import '../../services/auth_service/auth_service.dart';
import '../../utils/validators.dart';
import '../color/colors.dart';
import '../links/assets_link/asset_link.dart';
import '../widgets/reusable_date_picker/reusable_date_picker.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final TextEditingController _addressController = TextEditingController();
  List<String> bGList = <String>[
    'A+',
    'B+',
    'A-',
    'B-',
    'AB+',
    'AB-',
    'O-',
    'O+'
  ];
  String gender = 'Male';
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool isLoading = false;
  DateTime? selectedDob;

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
                vertical: isWeb ? 16 : 2.h,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardMaxWidth),
                child: Column(
                  children: [
                    // Logo at top
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: isWeb ? 48 : 5.h,
                          child: Image.asset(logo),
                        ),
                        SizedBox(width: isWeb ? 12 : 2.w),
                        Text(
                          'Healthverse',
                          style: TextStyle(
                            fontSize: isWeb ? 24 : 18.sp,
                            fontWeight: FontWeight.bold,
                            color: tealColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isWeb ? 24 : 3.h),

                    // Title
                    Text(
                      'Complete Profile',
                      style: TextStyle(
                        fontSize: isWeb ? 32 : 22.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: isWeb ? 8 : 0.5.h),
                    Text(
                      'Finish setting up your account',
                      style: TextStyle(
                        fontSize: isWeb ? 16 : 15.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: isWeb ? 24 : 3.h),

                    // Card with form
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWeb ? 32 : 5.w,
                          vertical: isWeb ? 24 : 3.h,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Address Field
                              ReusableTextFormField(
                                text: "Address",
                                icon: Icons.home_outlined,
                                controller: _addressController,
                                check: false,
                              ),
                              SizedBox(height: isWeb ? 20 : 2.5.h),

                              // Blood Group Dropdown
                              Text(
                                "Select your Blood Group",
                                style: TextStyle(
                                  fontSize: isWeb ? 16 : 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: isWeb ? 8 : 1.h),
                              Consumer(
                                builder: (context, ref, child) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: tealColor),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ReusableDropDown(
                                      list: bGList,
                                      initialValue: 'A+',
                                      hintText: 'Blood Group',
                                      onChanged: (value, ref) {
                                        ref
                                            .read(userProvider.notifier)
                                            .updateBloodType(value);
                                      },
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: isWeb ? 20 : 2.5.h),

                              // Date of Birth
                              Consumer(builder: (context, ref, child) {
                                return ReusableDatePicker(
                                  selectedDate: selectedDob,
                                  label: 'Date of Birth',
                                  onDateChanged: (date) {
                                    setState(() {
                                      selectedDob = date;
                                    });
                                    ref
                                        .read(userProvider.notifier)
                                        .updateDob(date);
                                  },
                                );
                              }),
                              SizedBox(height: isWeb ? 20 : 2.5.h),

                              // Gender Selection
                              Text(
                                "Gender",
                                style: TextStyle(
                                  fontSize: isWeb ? 16 : 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: isWeb ? 8 : 1.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          gender = "Male";
                                        });
                                      },
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              vertical: isWeb ? 16 : 1.5.h),
                                          decoration: BoxDecoration(
                                            color: gender == "Male"
                                                ? tealColor
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: tealColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Male',
                                              style: TextStyle(
                                                fontSize: isWeb ? 16 : 15.sp,
                                                fontWeight: FontWeight.w600,
                                                color: gender == "Male"
                                                    ? Colors.white
                                                    : tealColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isWeb ? 16 : 3.w),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          gender = "Female";
                                        });
                                      },
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              vertical: isWeb ? 16 : 1.5.h),
                                          decoration: BoxDecoration(
                                            color: gender == "Female"
                                                ? tealColor
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: tealColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Female',
                                              style: TextStyle(
                                                fontSize: isWeb ? 16 : 15.sp,
                                                fontWeight: FontWeight.w600,
                                                color: gender == "Female"
                                                    ? Colors.white
                                                    : tealColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isWeb ? 24 : 3.h),

                              // Complete Profile Button
                              Consumer(builder: (context, ref, child) {
                                return SizedBox(
                                  width: double.infinity,
                                  height: isWeb ? 56 : 6.h,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      if (_formKey.currentState!.validate()) {
                                        final dobError =
                                            Validators.validateDOB(selectedDob);
                                        if (dobError != null) {
                                          reusableSnackBar(context, dobError);
                                          return;
                                        }
                                        ref
                                            .read(userProvider.notifier)
                                            .updateGender(gender);
                                        ref
                                            .read(userProvider.notifier)
                                            .updateAddress(
                                                _addressController.text);
                                        final fName = ref.read(userProvider
                                            .select((value) => value.fName));
                                        final lName = ref.read(userProvider
                                            .select((value) => value.lName));
                                        final email = ref.read(userProvider
                                            .select((value) => value.email));
                                        final password = ref.read(userProvider
                                            .select((value) => value.password));
                                        final userGender = ref.read(userProvider
                                            .select((value) => value.gender));
                                        final address = ref.read(userProvider
                                            .select((value) => value.address));
                                        final dob = ref.read(userProvider
                                            .select((value) => value.dob));
                                        final bloodType = ref.read(
                                            userProvider.select(
                                                (value) => value.bloodGroup));
                                        final number = ref.read(userProvider
                                            .select((value) => value.number));
                                        final patientType = ref.read(
                                            userProvider.select(
                                                (value) => value.profileType));
                                        // M-1 CALLING SERVICES AND UPDATING THE PROVIDER
                                        _authService.registerUser(
                                            fName,
                                            lName,
                                            email,
                                            password,
                                            number,
                                            userGender,
                                            dob,
                                            address,
                                            bloodType,
                                            patientType,
                                            context,
                                            setLoading,
                                            navigateToSignIn);
                                      } else {
                                        reusableSnackBar(
                                            context, "fill all fields");
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
                                            'Complete Profile',
                                            style: TextStyle(
                                              fontSize: isWeb ? 18 : 17.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                );
                              }),
                            ],
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
    );
  }
}
