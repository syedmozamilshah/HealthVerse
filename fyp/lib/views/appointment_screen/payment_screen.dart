import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fyp/services/stripe_service/stripe_service.dart';
import 'package:fyp/utils/pakistan_time_helper.dart';
import 'package:fyp/views/color/colors.dart';
import 'package:fyp/views/home_screen/home_screen.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final String patientId;
  final String doctorId;
  final String doctorName;
  final int amount;
  final String currency;
  final DateTime appointmentDate;
  final DateTime? slotStartTime;
  final DateTime? slotEndTime;
  final Function(bool success)? onPaymentComplete;

  const PaymentScreen({
    super.key,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.amount,
    this.currency = 'pkr',
    required this.appointmentDate,
    this.slotStartTime,
    this.slotEndTime,
    this.onPaymentComplete,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool isLoading = true;
  bool isProcessing = false;
  String? errorMessage;
  String? checkoutUrl;
  WebViewController? webViewController;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }
  // No ticker to dispose

  Future<void> _initializePayment() async {
    await StripeService.initialize();
    await _createCheckoutSession();
  }

// M-10 USED TO CREATE CHECKOUT SESSION
  Future<void> _createCheckoutSession() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final amountInPaisa = widget.amount * 100;

      debugPrint('=== Payment Screen: Creating checkout session ===');
      debugPrint('Patient ID: ${widget.patientId}');
      debugPrint('Doctor ID: ${widget.doctorId}');
      debugPrint('Amount (PKR): ${widget.amount}');
      debugPrint('Amount (Paisa): $amountInPaisa');

      final result = await StripeService.createPatientCheckoutSession(
        patientId: widget.patientId,
        doctorId: widget.doctorId,
        appointmentId:
            'pending', // Will be updated after appointment is created
        amount: amountInPaisa,
        currency: widget.currency,
        successUrl: 'https://healthverse.app/payment-success',
        cancelUrl: 'https://healthverse.app/payment-cancel',
      );

      debugPrint(
          'Result received: isSuccess=${result?.isSuccess}, sessionUrl=${result?.sessionUrl}');

      if (result != null && result.isSuccess && result.sessionUrl != null) {
        setState(() {
          checkoutUrl = result.sessionUrl;
          isLoading = false;
        });

        // On web, open Stripe checkout in a new tab since WebView doesn't work
        if (kIsWeb) {
          await _openStripeCheckoutWeb();
        } else {
          _setupWebView();
        }
      } else {
        debugPrint('Payment session creation failed: ${result?.message}');
        setState(() {
          errorMessage = result?.message ?? 'Failed to create payment session';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Exception in _createCheckoutSession: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // Open Stripe checkout in a new browser tab for web
  Future<void> _openStripeCheckoutWeb() async {
    if (checkoutUrl != null) {
      final uri = Uri.parse(checkoutUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Show a dialog to the user to confirm payment
        if (mounted) {
          _showWebPaymentDialog();
        }
      } else {
        setState(() {
          errorMessage = 'Could not open payment page';
        });
      }
    }
  }

  // Dialog shown on web while user completes payment in new tab
  void _showWebPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: tealColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_new,
                  color: tealColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Complete Payment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: tealColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A new tab has opened for Stripe payment.\nPlease complete the payment there.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(this.context).pop();
                        widget.onPaymentComplete?.call(false);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _onPaymentSuccess();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'I\'ve Paid',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _setupWebView() {
    if (checkoutUrl != null) {
      webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) {
              if (request.url.contains('payment-success')) {
                _onPaymentSuccess();
                return NavigationDecision.prevent;
              } else if (request.url.contains('payment-cancel')) {
                _onPaymentCanceled();
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onPageStarted: (String url) {
              setState(() {
                isProcessing = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                isProcessing = false;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(checkoutUrl!));
      setState(() {});
    }
  }

  void _onPaymentSuccess() {
    widget.onPaymentComplete?.call(true);
    _showSuccessDialog();
  }

  void _onPaymentCanceled() {
    widget.onPaymentComplete?.call(false);
    Navigator.pop(context);
    reusableSnackBar(context, 'Payment was canceled');
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: tealColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: tealColor,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: tealColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your appointment with Dr. ${widget.doctorName} has been confirmed and paid.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                PakistanTimeHelper.formatPakistanTime(widget.appointmentDate, 'd/M/yyyy'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Go to Home',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: tealColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: isLoading
          ? _buildLoadingState()
          : errorMessage != null
              ? _buildErrorState()
              : _buildWebViewState(),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFe8f5e9), Color(0xFFc8e6c9)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lock icon for secure payment
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: EdgeInsets.all(18),
              child: Icon(
                Icons.lock_rounded,
                color: tealColor,
                size: 48,
              ),
            ),
            SizedBox(height: 2.h),
            // Secure badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: tealColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user, color: tealColor, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Secure Payment',
                    style: TextStyle(
                      color: tealColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3.h),
            const CircularProgressIndicator(
              color: tealColor,
              strokeWidth: 3,
            ),
            SizedBox(height: 2.h),
            Text(
              'Setting up secure payment...',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 1.5.h),
            Text(
              'Your payment is protected with bank-level encryption.',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFe8f5e9), Color(0xFFc8e6c9)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red.shade400,
              ),
              SizedBox(height: 2.h),
              Text(
                'Payment Setup Failed',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 4.h),
              ElevatedButton.icon(
                onPressed: _createCheckoutSession,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tealColor,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebViewState() {
    // On web, the payment opens in a new tab, so show a waiting state
    if (kIsWeb) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFe8f5e9), Color(0xFFc8e6c9)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: tealColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_browser,
                  color: tealColor,
                  size: 50,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'Payment Opened',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: tealColor,
                ),
              ),
              SizedBox(height: 1.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: Text(
                  'Complete your payment in the new tab that opened.\nReturn here when done.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onPaymentComplete?.call(false);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: EdgeInsets.symmetric(
                          horizontal: 6.w, vertical: 1.5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  ElevatedButton.icon(
                    onPressed: () {
                      _onPaymentSuccess();
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('I\'ve Paid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tealColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: 6.w, vertical: 1.5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // On mobile, use WebView
    return Stack(
      children: [
        if (webViewController != null)
          WebViewWidget(controller: webViewController!),
        if (isProcessing)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(
                color: tealColor,
              ),
            ),
          ),
      ],
    );
  }
}
