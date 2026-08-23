import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:fyp/models/question/question_model.dart';
import 'package:fyp/services/symptoms_question_service/symptoms_question_service.dart';
import 'package:fyp/views/registration_login/user_details_screen.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:fyp/services/appointment_service/appointment_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/prescription_service/prescription_service.dart';
import '../../models/prescription/prescription_model.dart';

import 'package:responsive_sizer/responsive_sizer.dart';
import '../color/colors.dart';
import 'doctor_view_screen/doctor_view_screen.dart';
import 'mcq_screen/mcq_screen.dart';

class AppointmentSymptoms extends StatefulWidget {
  final bool showBackButton;

  const AppointmentSymptoms({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<AppointmentSymptoms> createState() => _AppointmentSymptomsState();
}

class _AppointmentSymptomsState extends State<AppointmentSymptoms>
    with TickerProviderStateMixin  {
  // Speech to text setup
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _selectedLocaleId = 'en_US'; // Default locale
  List<LocaleName> _availableLocales = [];
  String _lastRecognizedWords = ''; // Store last recognized words
  bool _isNewPatient = true;
  final AppointmentService _appointmentService = AppointmentService();
  late TabController _tabController;
  List<SavedPrescription> _prescriptions = [];
  final PrescriptionService _prescriptionService = PrescriptionService();
  


  // Dialog state callback
  void Function(void Function())? _dialogSetState;
  bool _shouldKeepListening = false; // Flag to control continuous listening
  String _accumulatedText = ''; // Store all recognized text

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _initSpeech();
    _loadPatientHistory();
  }

Future<void> _loadPatientHistory() async {
  try {
    final response = await _prescriptionService.getMyPrescriptions();

    if (!mounted) return;

    if (response.success) {
      final prescriptions = response.data;

      setState(() {
        _prescriptions = prescriptions;

        _isNewPatient = prescriptions.isEmpty;


        debugPrint("Prescriptions count: ${prescriptions.length}");
        debugPrint("_isNewPatient: $_isNewPatient");
      });

      // ✅ AFTER state update
      _syncTabControllerLength();
    } else {
      setState(() {
        _isNewPatient = true;
      });

      _syncTabControllerLength();
    }
  } catch (e) {
    debugPrint("Error loading history: $e");

    if (!mounted) return;

    setState(() {
      _isNewPatient = true;
    });

    _syncTabControllerLength();
  }
}

void _syncTabControllerLength() {
  final requiredLength = _isNewPatient ? 1 : 2;

  if (_tabController.length == requiredLength) return;

  final oldController = _tabController;

  _tabController = TabController(
    length: requiredLength,
    vsync: this,
  );

  setState(() {}); 

  oldController.dispose();
}

  /// Initialize speech recognition
  Future<void> _initSpeech() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint('Microphone permission not granted');
      return;
    }

    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          // Auto-restart on error if should keep listening
          if (_shouldKeepListening && error.errorMsg != 'error_busy') {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_shouldKeepListening && mounted) {
                _startListening();
              }
            });
          }
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            // Auto-restart listening if user hasn't clicked Done
            if (_shouldKeepListening) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_shouldKeepListening && mounted) {
                  _startListening();
                }
              });
            } else {
              if (mounted) {
                setState(() => _isListening = false);
              }
            }
          }
        },
      );

      if (_speechEnabled) {
        _availableLocales = await _speechToText.locales();
        debugPrint(
            'Available locales: ${_availableLocales.map((l) => l.localeId).toList()}');

        // Check for Urdu locale
        final urduLocale = _availableLocales.where(
          (locale) =>
              locale.localeId.startsWith('ur') ||
              locale.name.toLowerCase().contains('urdu'),
        );
        if (urduLocale.isNotEmpty) {
          _selectedLocaleId = urduLocale.first.localeId;
          debugPrint('Urdu locale found: $_selectedLocaleId');
        } else {
          // Find first English locale
          final enLocale = _availableLocales.where(
            (locale) => locale.localeId.startsWith('en'),
          );
          if (enLocale.isNotEmpty) {
            _selectedLocaleId = enLocale.first.localeId;
          }
        }
      }
      debugPrint('Speech enabled: $_speechEnabled');
    } catch (e) {
      debugPrint('Speech init error: $e');
      _speechEnabled = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Start listening for speech (continuous until Done is clicked)
  Future<void> _startListening() async {
    if (!_speechEnabled) {
      debugPrint('Speech not enabled');
      return;
    }

    _shouldKeepListening = true;
    _lastRecognizedWords = '';

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: _selectedLocaleId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(minutes: 5), // Extended listen time
        pauseFor: const Duration(seconds: 3), // Short pause before auto-restart
      );
      setState(() => _isListening = true);
      if (_dialogSetState != null) {
        _dialogSetState!(() {});
      }
      debugPrint('Started listening with locale: $_selectedLocaleId');
    } catch (e) {
      debugPrint('Start listening error: $e');
      setState(() => _isListening = false);
    }
  }

  /// Stop listening completely (called when Done is clicked)
  Future<void> _stopListening() async {
    _shouldKeepListening = false; // Stop auto-restart
    await _speechToText.stop();
    setState(() => _isListening = false);
    if (_dialogSetState != null) {
      _dialogSetState!(() {});
    }
    debugPrint('Stopped listening. Final text: ${_symptomsController.text}');
  }

  /// Handle speech recognition result
  void _onSpeechResult(SpeechRecognitionResult result) {
    debugPrint(
        'Speech result: ${result.recognizedWords} (final: ${result.finalResult})');

    if (result.recognizedWords.isNotEmpty) {
      _lastRecognizedWords = result.recognizedWords;

      // When result is final, append to accumulated text
      if (result.finalResult) {
        if (_accumulatedText.isNotEmpty) {
          _accumulatedText = '$_accumulatedText ${result.recognizedWords}';
        } else {
          _accumulatedText = result.recognizedWords;
        }
        // Update the symptoms text field with accumulated text
        _symptomsController.text = _accumulatedText;
      } else {
        // Show partial results (current recognition + accumulated)
        if (_accumulatedText.isNotEmpty) {
          _symptomsController.text =
              '$_accumulatedText ${result.recognizedWords}';
        } else {
          _symptomsController.text = result.recognizedWords;
        }
      }

      // Move cursor to end
      _symptomsController.selection = TextSelection.fromPosition(
        TextPosition(offset: _symptomsController.text.length),
      );

      // Update dialog if it's open
      if (_dialogSetState != null) {
        _dialogSetState!(() {});
      }

      setState(() {});
    }
  }

  /// Get filtered and unique locales for dropdown
  List<Map<String, String>> _getFilteredLocales() {
    final Map<String, Map<String, String>> uniqueLocales = {};

    for (var locale in _availableLocales) {
      final id = locale.localeId;
      String displayName = locale.name;
      String key = id; // Use full locale ID as key

      // Urdu
      if (id.startsWith('ur')) {
        displayName = '🇵🇰 Urdu (اردو)';
        key = 'ur';
      }
      // English variants
      else if (id == 'en_US' || id == 'en-US') {
        displayName = '🇺🇸 English (US)';
        key = 'en_US';
      } else if (id == 'en_GB' || id == 'en-GB') {
        displayName = '🇬🇧 English (UK)';
        key = 'en_GB';
      } else if (id == 'en_IN' || id == 'en-IN') {
        displayName = '🇮🇳 English (India)';
        key = 'en_IN';
      } else if (id == 'en_PK' || id == 'en-PK') {
        displayName = '🇵🇰 English (Pakistan)';
        key = 'en_PK';
      } else if (id.startsWith('en')) {
        // Skip other English variants to avoid duplicates
        if (uniqueLocales.containsKey('en_US') ||
            uniqueLocales.containsKey('en_GB')) {
          continue;
        }
        displayName = '🌐 English';
        key = 'en';
      } else {
        // Skip non-relevant languages (including Hindi)
        continue;
      }

      // Only add if not already present (avoid duplicates)
      if (!uniqueLocales.containsKey(key)) {
        uniqueLocales[key] = {'id': id, 'name': displayName};
      }
    }

    // Sort: Urdu first (for Pakistan), then English variants
    final result = uniqueLocales.values.toList();
    result.sort((a, b) {
      final order = ['ur', 'en_PK', 'en_IN', 'en_US', 'en_GB', 'en'];
      final aKey = uniqueLocales.entries.firstWhere((e) => e.value == a).key;
      final bKey = uniqueLocales.entries.firstWhere((e) => e.value == b).key;
      final aIndex = order.indexOf(aKey);
      final bIndex = order.indexOf(bKey);
      return (aIndex == -1 ? 999 : aIndex)
          .compareTo(bIndex == -1 ? 999 : bIndex);
    });

    return result;
  }

  @override
  void dispose() {
    _speechToText.stop();
    _tabController.dispose();
    super.dispose();
  }

  final SymptomQuestionService _symptomQuestionService =
      SymptomQuestionService();
  final TextEditingController _symptomsController = TextEditingController();

  void navigateToUserDetailScreen() {
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (context) => const UserDetailScreen()));
  }

  void navigateToDoctorScreen() {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                const DoctorViewScreen(speciality: 'Optometrist')));
  }

  bool isLoading = false;

  void setLoading(bool loading) {
    setState(() {
      isLoading = loading;
    });
  }

                  color: tealColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showServiceErrorDialog(bool isWeb, String? errorMessage) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.cloud_off,
                  color: Colors.red, size: isWeb ? 28 : 24.sp),
              SizedBox(width: isWeb ? 12 : 2.w),
              Expanded(
                child: Text(
                  'Service Temporarily Unavailable',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            errorMessage ??
                'The service is temporarily busy. Please wait a moment and try again.\n\nYour symptoms have been noted. This is not an issue with your input.',
            style: TextStyle(
              fontSize: isWeb ? 16 : 15.sp,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Try Again',
                style: TextStyle(
                  color: tealColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);
    final contentMaxWidth = ResponsiveHelper.getContentWidth(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: loginGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
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
                                color: Colors.white, size: isWeb ? 24 : 20.sp),
                          ),
                        ),
                      ),
                    if (widget.showBackButton)
                      SizedBox(width: isWeb ? 20 : 4.w),
                    Text(
                      'Book Appointment',
                      style: TextStyle(
                        fontSize: isWeb ? 28 : 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // TabBar

              Container(
                margin: EdgeInsets.symmetric(horizontal: isWeb ? 24 : 4.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  // indicator: BoxDecoration(
                  //   color: Colors.white,
                  //   borderRadius: BorderRadius.circular(12),
                  // ),
                  key: ValueKey(_tabController.length),
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(color: Colors.white, width: 3),
                  ),
                  labelColor: tealColor,
                  unselectedLabelColor: Colors.white,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isWeb ? 16 : 14.sp,
                  ),
                  tabs: [
                    const Tab(text: 'New Appointment'),
                    if (!_isNewPatient) const Tab(text: 'Recurring'),
                  ],
                ),
              ),

              SizedBox(height: isWeb ? 16 : 2.h),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  key: ValueKey(_tabController.length),
                  children: [
                    _buildNewAppointmentTab(isWeb, contentMaxWidth),
                    if (!_isNewPatient)
                      _buildRecurringTab(isWeb, contentMaxWidth),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewAppointmentTab(bool isWeb, double contentMaxWidth) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 24 : 5.w),
          child: Card(
            elevation: 8,
            shadowColor: tealColor.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: EdgeInsets.all(isWeb ? 32 : 6.w),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon and Title
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isWeb ? 16 : 3.w),
                          decoration: BoxDecoration(
                            color: tealColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.edit_note,
                            color: tealColor,
                            size: isWeb ? 32 : 24.sp,
                          ),
                        ),
                        SizedBox(width: isWeb ? 20 : 4.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Describe Your Symptoms',
                                style: TextStyle(
                                  fontSize: isWeb ? 20 : 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: isWeb ? 4 : 0.5.h),
                              Text(
                                'Tell us how you\'re feeling',
                                style: TextStyle(
                                  fontSize: isWeb ? 16 : 14.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isWeb ? 32 : 4.h),

                    // Text Area
                    Container(
                      height: isWeb ? 300 : 25.h,
                      decoration: BoxDecoration(
                        color: lightTealColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: tealColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _symptomsController,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText:
                              "Describe your symptoms in detail...\n\nFor example:\n• What symptoms are you experiencing?\n• When did they start?\n• How severe are they?",
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: isWeb ? 16 : 15.sp,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(isWeb ? 20 : 4.w),
                        ),
                        style: TextStyle(
                          fontSize: isWeb ? 18 : 16.sp,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    SizedBox(height: isWeb ? 24 : 2.h),

                    // Voice Recording Option
                    _buildVoiceRecordingOption(isWeb),

                    SizedBox(height: isWeb ? 24 : 2.h),

                    // Submit Button
                    _buildSubmitSymptomsButton(isWeb),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecurringTab(bool isWeb, double contentMaxWidth) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 24 : 5.w),
          child: Card(
            elevation: 8,
            shadowColor: tealColor.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: EdgeInsets.all(isWeb ? 32 : 6.w),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon and Title
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isWeb ? 16 : 3.w),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.repeat,
                            color: Colors.orange,
                            size: isWeb ? 32 : 24.sp,
                          ),
                        ),
                        SizedBox(width: isWeb ? 20 : 4.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recurring Visit',
                                style: TextStyle(
                                  fontSize: isWeb ? 20 : 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: isWeb ? 4 : 0.5.h),
                              Text(
                                'Follow-up or routine checkup',
                                style: TextStyle(
                                  fontSize: isWeb ? 16 : 14.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isWeb ? 24 : 3.h),

                    // Info Card
                    Container(
                      padding: EdgeInsets.all(isWeb ? 16 : 4.w),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange, size: isWeb ? 24 : 20.sp),
                          SizedBox(width: isWeb ? 12 : 3.w),
                          Expanded(
                            child: Text(
                              'For follow-up appointments or routine checkups, you can directly select your doctor without describing symptoms.',
                              style: TextStyle(
                                fontSize: isWeb ? 14 : 13.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isWeb ? 32 : 4.h),

                    // Optional Notes
                    Text(
                      'Optional Notes (for your doctor)',
                      style: TextStyle(
                        fontSize: isWeb ? 16 : 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: isWeb ? 12 : 1.5.h),
                    Container(
                      height: isWeb ? 150 : 15.h,
                      decoration: BoxDecoration(
                        color: lightTealColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: tealColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText:
                              "Any specific concerns for this visit? (optional)",
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: isWeb ? 15 : 14.sp,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(isWeb ? 16 : 4.w),
                        ),
                        style: TextStyle(
                          fontSize: isWeb ? 16 : 15.sp,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    SizedBox(height: isWeb ? 32 : 4.h),

                    // Verified Eye Care Specialists Section
                    Text(
                      'Select Eye Care Specialist',
                      style: TextStyle(
                        fontSize: isWeb ? 16 : 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: isWeb ? 12 : 1.5.h),

                    // Specialist Type Cards
                    _buildSpecialistCard(
                      isWeb: isWeb,
                      title: 'Ophthalmologist',
                      subtitle: 'Eye surgery & disease treatment',
                      icon: Icons.medical_services,
                      color: Colors.blue,
                    ),
                    SizedBox(height: isWeb ? 12 : 1.5.h),
                    _buildSpecialistCard(
                      isWeb: isWeb,
                      title: 'Optometrist',
                      subtitle: 'Vision testing & eye exams',
                      icon: Icons.remove_red_eye,
                      color: Colors.teal,
                    ),
                    SizedBox(height: isWeb ? 12 : 1.5.h),
                    _buildSpecialistCard(
                      isWeb: isWeb,
                      title: 'Ocularist',
                      subtitle: 'Prosthetic eye specialist',
                      icon: Icons.visibility,
                      color: Colors.purple,
                    ),
                    SizedBox(height: isWeb ? 12 : 1.5.h),
                    _buildSpecialistCard(
                      isWeb: isWeb,
                      title: 'Optician',
                      subtitle: 'Glasses & contact lens fitting',
                      icon: Icons.center_focus_strong,
                      color: Colors.orange,
                    ),

                    SizedBox(height: isWeb ? 32 : 4.h),

                    // // Select Doctor Button
                    // SizedBox(
                    //   width: double.infinity,
                    //   height: isWeb ? 56 : 7.h,
                    //   child: ElevatedButton(
                    //     onPressed: () {
                    //       Navigator.push(
                    //         context,
                    //         MaterialPageRoute(
                    //           builder: (context) => const DoctorViewScreen(
                    //               speciality: 'Optometrist'),
                    //         ),
                    //       );
                    //     },
                    //     style: ElevatedButton.styleFrom(
                    //       backgroundColor: Colors.orange,
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(16),
                    //       ),
                    //       elevation: 4,
                    //     ),
                    //     child: Row(
                    //       mainAxisAlignment: MainAxisAlignment.center,
                    //       children: [
                    //         Icon(Icons.person_search,
                    //             color: Colors.white, size: isWeb ? 24 : 20.sp),
                    //         SizedBox(width: isWeb ? 12 : 2.w),
                    //         Text(
                    //           'Select Doctor',
                    //           style: TextStyle(
                    //             color: Colors.white,
                    //             fontSize: isWeb ? 18 : 17.sp,
                    //             fontWeight: FontWeight.bold,
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceRecordingOption(bool isWeb) {
    return GestureDetector(
      onTap: () {
        _lastRecognizedWords = ''; // Reset on dialog open
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                // Store reference to dialog's setState
                _dialogSetState = setDialogState;

                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : tealColor,
                      ),
                      SizedBox(width: isWeb ? 12 : 2.w),
                      Expanded(
                        child: Text(
                          _isListening ? "Listening..." : "Speech to Text",
                          style: TextStyle(
                            fontSize: isWeb ? 20 : 17.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Speak your symptoms clearly. Text will appear in the input field.",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        SizedBox(height: isWeb ? 16 : 2.h),

                        // Language Selector
                        if (_availableLocales.isNotEmpty) ...[
                          Text(
                            "Language:",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: isWeb ? 14 : 13.sp,
                            ),
                          ),
                          SizedBox(height: isWeb ? 8 : 1.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isWeb ? 12 : 3.w,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedLocaleId,
                                isExpanded: true,
                                items: _getFilteredLocales().map((locale) {
                                  return DropdownMenuItem<String>(
                                    value: locale['id'],
                                    child: Text(
                                      locale['name']!,
                                      style: TextStyle(
                                        fontSize: isWeb ? 14 : 13.sp,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: _isListening
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedLocaleId = value;
                                          });
                                          setDialogState(() {});
                                        }
                                      },
                              ),
                            ),
                          ),
                          SizedBox(height: isWeb ? 16 : 2.h),
                        ],

                        // Listening indicator
                        if (_isListening)
                          Container(
                            padding: EdgeInsets.all(isWeb ? 16 : 3.w),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: isWeb ? 12 : 10.sp,
                                  height: isWeb ? 12 : 10.sp,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: isWeb ? 12 : 2.w),
                                Expanded(
                                  child: Text(
                                    "Listening... Speak now",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                      fontSize: isWeb ? 14 : 13.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (!_speechEnabled)
                          Container(
                            padding: EdgeInsets.all(isWeb ? 12 : 3.w),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange,
                                  size: isWeb ? 20 : 18.sp,
                                ),
                                SizedBox(width: isWeb ? 8 : 2.w),
                                Expanded(
                                  child: Text(
                                    "Speech recognition not available",
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontSize: isWeb ? 13 : 12.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: isWeb ? 24 : 3.h),

                        // Show recognized text
                        if (_symptomsController.text.isNotEmpty || _isListening)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isWeb ? 12 : 3.w),
                            decoration: BoxDecoration(
                              color: tealColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: tealColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Recognized Text:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isWeb ? 12 : 11.sp,
                                    color: tealColor,
                                  ),
                                ),
                                SizedBox(height: isWeb ? 4 : 0.5.h),
                                Text(
                                  _symptomsController.text.isEmpty
                                      ? "Waiting for speech..."
                                      : _symptomsController.text,
                                  style: TextStyle(
                                    fontSize: isWeb ? 14 : 13.sp,
                                    color: _symptomsController.text.isEmpty
                                        ? Colors.grey
                                        : Colors.black87,
                                    fontStyle: _symptomsController.text.isEmpty
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: isWeb ? 16 : 2.h),

                        // Mic Button
                        Center(
                          child: GestureDetector(
                            onTap: _speechEnabled
                                ? () async {
                                    if (_isListening) {
                                      await _stopListening();
                                    } else {
                                      // Reset for fresh start
                                      _lastRecognizedWords = '';
                                      _accumulatedText = '';
                                      await _startListening();
                                    }
                                    setDialogState(() {});
                                    setState(() {});
                                  }
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.all(isWeb ? 24 : 5.w),
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? Colors.red
                                    : (_speechEnabled
                                        ? tealColor
                                        : Colors.grey),
                                shape: BoxShape.circle,
                                boxShadow: _isListening
                                    ? [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.4),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                _isListening ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: isWeb ? 32 : 26.sp,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: isWeb ? 16 : 2.h),

                        Center(
                          child: Text(
                            _isListening
                                ? "Tap to stop"
                                : "Tap to start speaking",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: isWeb ? 13 : 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        if (_isListening) {
                          await _stopListening();
                        }
                        _dialogSetState = null; // Clear reference
                        Navigator.pop(dialogContext);
                        setState(() {});
                      },
                      child: Text(
                        'Done',
                        style: TextStyle(color: tealColor),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: isWeb ? 16 : 2.h,
            horizontal: isWeb ? 20 : 4.w,
          ),
          decoration: BoxDecoration(
            color: lightTealColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic, color: tealColor, size: isWeb ? 24 : 20.sp),
              SizedBox(width: isWeb ? 12 : 2.w),
              Text(
                'Can\'t type? Use voice input',
                style: TextStyle(
                  color: tealColor,
                  fontSize: isWeb ? 16 : 15.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitSymptomsButton(bool isWeb) {
    return SizedBox(
      width: isWeb ? 300 : double.infinity,
      height: isWeb ? 56 : 7.h,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () async {
                if (_symptomsController.text.trim().isNotEmpty) {
                  setLoading(true);
                  try {
                    print(_symptomsController.text);
                    final result =
                        await _symptomQuestionService.triageQuestionStart(
                            _symptomsController.text.trim(), setLoading);

                    print("result: $result");

                    if (result != null && result.isNotEmpty) {
                      try {
                        final QuestionModel questionModel =
                            QuestionModel.fromJson(result);

                        // Check if there was an error (invalid input or service error)
                        if (questionModel.hasError) {
                          if (mounted) {
                            // Check error type to show appropriate dialog
                            final errorType =
                                questionModel.errorType ?? 'invalid_symptoms';

                            if (errorType == 'quota_exceeded' ||
                                errorType == 'service_error') {
                              // Show service error dialog (not invalid symptoms)
                              _showServiceErrorDialog(
                                  isWeb, questionModel.errorMessage);
                            } else {
                              // Show invalid symptoms dialog
                              final lang =
                                  questionModel.detectedLanguage ?? 'english';
                              final isUrdu = lang == 'urdu';
                              final isRomanUrdu = lang == 'roman_urdu';

                              String dialogTitle;
                              String buttonText;
                              String defaultErrorMessage;

                              if (isUrdu) {
                                dialogTitle = 'غیر متعلقہ علامات';
                                buttonText = 'دوبارہ کوشش کریں';
                                defaultErrorMessage =
                                    'براہ کرم صرف آنکھوں سے متعلق علامات درج کریں۔\n\nمثال:\n• میری آنکھ میں درد ہے\n• نظر دھندلی ہے\n• آنکھ لال ہے\n\nیہ سسٹم صرف آنکھوں کے مسائل کے لیے ہے۔';
                              } else if (isRomanUrdu) {
                                dialogTitle = 'Ghair Mutaliq Alamat';
                                buttonText = 'Dobara Koshish Karein';
                                defaultErrorMessage =
                                    'Barah karam sirf aankh se mutaliq alamat darj karein.\n\nMaslan:\n• Meri aankh mein dard hai\n• Nazar dhundli hai\n• Aankh laal hai\n\nYeh system sirf aankhon ke maslay ke liye hai.';
                              } else {
                                dialogTitle = 'Invalid Symptoms';
                                buttonText = 'Try Again';
                                defaultErrorMessage =
                                    'Please enter eye-related symptoms only.\n\nFor example:\n• I have blurry vision\n• My eyes are red and itchy\n• I have pain in my eyes\n\nThis system is designed specifically for eye and vision problems.';
                              }

                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Row(
                                      children: [
                                        Icon(Icons.visibility_off,
                                            color: Colors.orange,
                                            size: isWeb ? 28 : 24.sp),
                                        SizedBox(width: isWeb ? 12 : 2.w),
                                        Expanded(
                                          child: Text(
                                            dialogTitle,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontFamily:
                                                  isUrdu ? 'UrduFont' : null,
                                            ),
                                            textDirection: isUrdu
                                                ? TextDirection.rtl
                                                : TextDirection.ltr,
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Directionality(
                                      textDirection: isUrdu
                                          ? TextDirection.rtl
                                          : TextDirection.ltr,
                                      child: Text(
                                        questionModel
                                                    .errorMessage?.isNotEmpty ==
                                                true
                                            ? questionModel.errorMessage!
                                            : defaultErrorMessage,
                                        style: TextStyle(
                                          fontSize: isWeb ? 16 : 15.sp,
                                          height: 1.5,
                                          fontFamily:
                                              isUrdu ? 'UrduFont' : null,
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _symptomsController.clear();
                                        },
                                        child: Text(
                                          buttonText,
                                          style: TextStyle(
                                            color: tealColor,
                                            fontWeight: FontWeight.bold,
                                            fontFamily:
                                                isUrdu ? 'UrduFont' : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          }
                          return;
                        }

                        if (!questionModel.isCompleted &&
                            questionModel.question != null) {
                          Navigator.pushReplacement(
                            context,
                            // M-4 GOING TO MCQ SCREEN
                            MaterialPageRoute(
                              builder: (context) => MCQScreen(
                                questionModel: questionModel,
                                symptomQuestionService: _symptomQuestionService,
                              ),
                            ),
                          );
                        } else {
                          reusableSnackBar(
                              context, "No questions received from server");
                        }
                      } catch (e) {
                        print("Error parsing question model: $e");
                        _showServiceErrorDialog(isWeb, null);
                      }
                    } else {
                      _showServiceErrorDialog(isWeb, null);
                    }
                  } catch (e) {
                    print("Error in triage: $e");
                    _showServiceErrorDialog(isWeb, null);
                  } finally {
                    setLoading(false);
                  }
                } else {
                  reusableSnackBar(context, "Please enter symptoms");
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: tealColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
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
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send,
                      color: Colors.white, size: isWeb ? 24 : 20.sp),
                  SizedBox(width: isWeb ? 12 : 2.w),
                  Text(
                    'Submit Symptoms',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isWeb ? 18 : 17.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Helper method to build specialist type cards
  Widget _buildSpecialistCard({
    required bool isWeb,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorViewScreen(speciality: title),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(isWeb ? 16 : 3.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isWeb ? 10 : 2.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: isWeb ? 24 : 20.sp),
            ),
            SizedBox(width: isWeb ? 16 : 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isWeb ? 15 : 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isWeb ? 13 : 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: isWeb ? 18 : 16.sp,
            ),
          ],
        ),
      ),
    );
  }
}
