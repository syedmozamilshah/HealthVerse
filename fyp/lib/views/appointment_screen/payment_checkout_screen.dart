import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/doctor_data/doctor_data.dart';
import '../../services/payment_service/payment_service.dart';
import '../../provider/state_notifier_provider/user_provider.dart';
import '../color/colors.dart';
import '../home_screen/home_screen.dart';

class PaymentCheckoutScreen extends ConsumerStatefulWidget {
  final DoctorData doctor;
  final String appointmentId;
  final int appointmentFee;

  const PaymentCheckoutScreen({
    super.key,
    required this.doctor,
    required this.appointmentId,
    required this.appointmentFee,
  });

  @override
  ConsumerState<PaymentCheckoutScreen> createState() =>
      _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends ConsumerState<PaymentCheckoutScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _startCheckout() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(userProvider);
      final patientId = user.id;

      if (patientId.isEmpty) {
        setState(() {
          _errorMessage = 'Unable to identify patient. Please log in again.';
          _isProcessing = false;
        });
        return;
      }

      // Convert fee to paisa (smallest currency unit)
      final amountInPaisa = widget.appointmentFee * 100;

// M-10 CALLING THE SERVICE TO GET THE CHECKOUT URL FROM THE BACKEND
      final response = await _paymentService.createAppointmentCheckout(
        patientId: patientId,
        doctorId: widget.doctor.id,
        appointmentId: widget.appointmentId,
        amountInPaisa: amountInPaisa,
        successUrl: 'healthverse://payment-success',
        cancelUrl: 'healthverse://payment-cancel',
      );

      if (response.isSuccess && response.sessionUrl.isNotEmpty) {
        // Open Stripe checkout in browser
        final uri = Uri.parse(response.sessionUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          // Show dialog to inform user
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Complete Payment'),
                content: const Text(
                  'A payment page has been opened in your browser. '
                  'Please complete the payment there and return to the app.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text('Return to Home'),
                  ),
                ],
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'Unable to open payment page. Please try again.';
          });
        }
      } else {
        setState(() {
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'Failed to create checkout session. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    }

    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: loginGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Payment',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Doctor Info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: tealColor.withOpacity(0.1),
                              backgroundImage: widget.doctor.imageUrl.isNotEmpty
                                  ? NetworkImage(widget.doctor.imageUrl)
                                  : null,
                              child: widget.doctor.imageUrl.isEmpty
                                  ? Icon(Icons.person,
                                      color: tealColor, size: 30)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dr. ${widget.doctor.fName} ${widget.doctor.lName}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    widget.doctor.speciality,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),

                        // Payment Summary
                        const Text(
                          'Payment Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildSummaryRow(
                            'Consultation Fee', 'Rs. ${widget.appointmentFee}'),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Service Fee', 'Rs. 0',
                            isSecondary: true),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Total Amount',
                          'Rs. ${widget.appointmentFee}',
                          isBold: true,
                          isLarge: true,
                        ),

                        const SizedBox(height: 32),

                        // Payment Info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'You will be redirected to a secure payment page to complete the transaction.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Secure Payment Badge
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                'Secured by Stripe',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Error Message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Pay Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _startCheckout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tealColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Pay Rs. ${widget.appointmentFee}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Cancel Button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
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
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isLarge = false,
    bool isSecondary = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isSecondary ? Colors.grey[500] : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 20 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? tealColor : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
