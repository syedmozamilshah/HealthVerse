import 'package:flutter/material.dart';
import 'package:fyp/models/question/question_model.dart';
import 'package:fyp/services/symptoms_question_service/symptoms_question_service.dart';
import 'package:fyp/views/appointment_screen/doctor_view_screen/doctor_view_screen.dart';
import 'package:fyp/utils/responsive_helper.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class MCQScreen extends StatefulWidget {
  final QuestionModel questionModel;
  final SymptomQuestionService symptomQuestionService;

  const MCQScreen({
    super.key,
    required this.questionModel,
    required this.symptomQuestionService,
  });

  @override
  State<MCQScreen> createState() => _MCQScreenState();
}

class _MCQScreenState extends State<MCQScreen> {
  late QuestionModel currentQuestionModel;
  String? selectedOption;
  bool isLoading = false;
  int questionNumber = 1;
  bool showOtherTextField = false;
  final TextEditingController _otherTextController = TextEditingController();
  final SymptomQuestionService _symptomQuestionService =
      SymptomQuestionService();

  static const Color tealColor = Color(0xFF1F8A70);
  static const Color lightTealColor = Color(0xFF80CBC4);

  @override
  void initState() {
    super.initState();
    currentQuestionModel = widget.questionModel;
    questionNumber = currentQuestionModel.questionsAnswered + 1;
  }

  @override
  void dispose() {
    _otherTextController.dispose();
    super.dispose();
  }

  void setLoading(bool loading) {
    setState(() {
      isLoading = loading;
    });
  }

  /// Check if this is an "Other" option based on text patterns
  bool _isOtherOption(String text) {
    final lowerText = text.toLowerCase().trim();
    return lowerText == 'other' ||
        lowerText == 'others' ||
        lowerText == 'دیگر' ||
        lowerText == 'dusra' ||
        lowerText == 'dusra/other' ||
        lowerText == 'other/دیگر' ||
        lowerText == 'other/دیگر/dusra' ||
        lowerText.contains('دیگر') ||
        (lowerText.contains('other') && lowerText.length < 20);
  }

  /// Detect if text contains Urdu script
  bool _isUrduText(String text) {
    final urduPattern =
        RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]');
    return urduPattern.hasMatch(text);
  }

  /// Get text direction based on content
  TextDirection _getTextDirection(String text) {
    return _isUrduText(text) ? TextDirection.rtl : TextDirection.ltr;
  }

  Future<void> handleAnswer(String optionId, {String? customText}) async {
    if (isLoading) return;

    setLoading(true);

    try {
      if (currentQuestionModel.question == null) {
        throw Exception("No question available");
      }

      final currentQuestion = currentQuestionModel.question!;

      // M-4 CALLING PYTHON SERVICES TO GET THE NEXT QUESTION OR FINAL RESULT
      final result = await widget.symptomQuestionService.sendAnswer(
        currentQuestionModel.sessionId,
        currentQuestion.questionId,
        optionId,
        setLoading,
        customText: customText,
      );

      if (result != null) {
        if (result['is_completed'] == false) {
          final newQuestionModel = QuestionModel.fromJson(result);

          setState(() {
            currentQuestionModel = newQuestionModel;
            selectedOption = null;
            showOtherTextField = false;
            _otherTextController.clear();
            questionNumber = newQuestionModel.questionsAnswered + 1;
          });
        } else if (result['is_completed'] == true) {
          if (mounted) {
            _symptomQuestionService.getInitialSummary(
              currentQuestionModel.sessionId,
            );
            Navigator.of(context).pop();
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const DoctorViewScreen(speciality: 'Optometrist')));
          }
        }
      } else {
        if (mounted) {
          reusableSnackBar(context, "Error: No response from server");
        }
      }
    } catch (e) {
      if (mounted) {
        reusableSnackBar(context, "Error: $e");
      }
    } finally {
      setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);
    final contentMaxWidth = ResponsiveHelper.getContentWidth(context);

    if (currentQuestionModel.question == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("No Question"),
          backgroundColor: tealColor,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: const Center(
          child: Text("No question available"),
        ),
      );
    }

    final question = currentQuestionModel.question!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Question $questionNumber",
          style: TextStyle(fontSize: isWeb ? 20 : null, color: Colors.white),
        ),
        backgroundColor: tealColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: currentQuestionModel.totalQuestions > 0
                ? currentQuestionModel.questionsAnswered /
                    currentQuestionModel.totalQuestions
                : 0.0,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(lightTealColor),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1F8A70),
              Color(0xFF80CBC4),
              Color(0xFFE0F2F1),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Padding(
                padding: EdgeInsets.all(isWeb ? 24 : 5.w),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isWeb ? 24 : 4.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(vertical: isWeb ? 8 : 1.h),
                          child: Row(
                            children: [
                              Icon(
                                Icons.question_answer,
                                color: tealColor,
                                size: isWeb ? 28 : null,
                              ),
                              SizedBox(width: isWeb ? 12 : 2.w),
                              Text(
                                "Question $questionNumber",
                                style: TextStyle(
                                  fontSize: isWeb ? 20 : 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: tealColor,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "${currentQuestionModel.questionsAnswered}/${currentQuestionModel.totalQuestions}",
                                style: TextStyle(
                                  fontSize: isWeb ? 16 : 14.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        SizedBox(height: isWeb ? 20 : 2.h),
                        Directionality(
                          textDirection:
                              _getTextDirection(question.questionText),
                          child: Text(
                            question.questionText,
                            style: TextStyle(
                              fontSize: isWeb ? 24 : 18.sp,
                              fontWeight: FontWeight.w600,
                              fontFamily: _isUrduText(question.questionText)
                                  ? 'UrduFont'
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(height: isWeb ? 32 : 4.h),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: isWeb ? 16 : 2.w,
                                  runSpacing: isWeb ? 12 : 1.5.h,
                                  children: question.options.map((opt) {
                                    final bool isSelected =
                                        selectedOption == opt.optionId;
                                    final bool isOther =
                                        _isOtherOption(opt.text);
                                    final bool isUrdu = _isUrduText(opt.text);

                                    return MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: Directionality(
                                        textDirection: isUrdu
                                            ? TextDirection.rtl
                                            : TextDirection.ltr,
                                        child: GestureDetector(
                                          onTap: () {
                                            if (!isLoading) {
                                              setState(() {
                                                selectedOption = opt.optionId;
                                                showOtherTextField = isOther;
                                              });
                                              // If not "Other", submit immediately
                                              if (!isOther) {
                                                handleAnswer(opt.optionId);
                                              }
                                            }
                                          },
                                          child: Container(
                                            constraints: BoxConstraints(
                                              maxWidth: isWeb
                                                  ? 400
                                                  : MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.9,
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isWeb ? 20 : 4.w,
                                              vertical: isWeb ? 14 : 1.5.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? tealColor
                                                  : Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isSelected
                                                    ? tealColor
                                                    : Colors.grey.shade400,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Text(
                                              opt.text,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: isWeb ? 16 : 14,
                                                fontWeight: FontWeight.w500,
                                                fontFamily:
                                                    isUrdu ? 'UrduFont' : null,
                                              ),
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                // Show text field when "Other" is selected
                                if (showOtherTextField) ...[
                                  SizedBox(height: isWeb ? 24 : 3.h),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: tealColor.withOpacity(0.5)),
                                    ),
                                    child: TextField(
                                      controller: _otherTextController,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        hintText: _isUrduText(
                                                question.questionText)
                                            ? 'براہ کرم اپنا جواب یہاں لکھیں...'
                                            : 'Please type your answer here...',
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontFamily:
                                              _isUrduText(question.questionText)
                                                  ? 'UrduFont'
                                                  : null,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            EdgeInsets.all(isWeb ? 16 : 3.w),
                                      ),
                                      style: TextStyle(
                                        fontSize: isWeb ? 16 : 15.sp,
                                        fontFamily:
                                            _isUrduText(question.questionText)
                                                ? 'UrduFont'
                                                : null,
                                      ),
                                      textDirection:
                                          _isUrduText(question.questionText)
                                              ? TextDirection.rtl
                                              : TextDirection.ltr,
                                    ),
                                  ),
                                  SizedBox(height: isWeb ? 16 : 2.h),
                                  SizedBox(
                                    width: isWeb ? 200 : double.infinity,
                                    child: ElevatedButton(
                                      onPressed: isLoading
                                          ? null
                                          : () {
                                              if (_otherTextController.text
                                                  .trim()
                                                  .isNotEmpty) {
                                                handleAnswer(
                                                  selectedOption!,
                                                  customText:
                                                      _otherTextController.text
                                                          .trim(),
                                                );
                                              } else {
                                                reusableSnackBar(
                                                  context,
                                                  _isUrduText(
                                                          question.questionText)
                                                      ? 'براہ کرم اپنا جواب لکھیں'
                                                      : 'Please enter your answer',
                                                );
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: tealColor,
                                        padding: EdgeInsets.symmetric(
                                            vertical: isWeb ? 14 : 1.5.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        _isUrduText(question.questionText)
                                            ? 'جمع کرائیں'
                                            : 'Submit',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isWeb ? 16 : 15.sp,
                                          fontWeight: FontWeight.w600,
                                          fontFamily:
                                              _isUrduText(question.questionText)
                                                  ? 'UrduFont'
                                                  : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (isLoading) ...[
                          SizedBox(height: isWeb ? 24 : 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: tealColor),
                              SizedBox(width: isWeb ? 16 : 3.w),
                              Text(
                                "Processing your answer...",
                                style: TextStyle(fontSize: isWeb ? 18 : 16.sp),
                              ),
                            ],
                          ),
                        ]
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
