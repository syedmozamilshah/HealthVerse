import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../views/links/base_url_link/base_url_link.dart';

// M-10 ALL PAYMENT-RELATED API CALLS AND STRIPE INTEGRATION WITH UI
class StripeService {
  static final String _baseUrl = base_url;

  // Initialize Stripe
  static Future<void> initialize() async {
    Stripe.publishableKey =
        'pk_test_51SbZXqI0kIulCigoPxGSnq0N46xomVby23cdovAzyYb4vr99Kb46nwQqvHyuPL3dUuCWeQ7V51F1zHVPzvl84BmN00HxNz1Yvl';
    await Stripe.instance.applySettings();
  }

  // Create payment intent for patient appointment
  static Future<PaymentIntentResult?> createPatientPaymentIntent({
    required String patientId,
    required String doctorId,
    required String appointmentId,
    required int amount,
    String currency = 'pkr',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/Stripe/patient/create-payment-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'patientId': patientId,
          'doctorId': doctorId,
          'appointmentId': appointmentId,
          'amount': amount,
          'currency': currency,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['isSuccess'] == true) {
          return PaymentIntentResult(
            isSuccess: true,
            clientSecret: data['clientSecret'],
            paymentIntentId: data['paymentIntentId'],
          );
        }
      }

      return PaymentIntentResult(
        isSuccess: false,
        message: 'Failed to create payment intent',
      );
    } catch (e) {
      return PaymentIntentResult(
        isSuccess: false,
        message: e.toString(),
      );
    }
  }

  // Create checkout session for patient appointment (redirects to Stripe hosted page)
  static Future<CheckoutSessionResult?> createPatientCheckoutSession({
    required String patientId,
    required String doctorId,
    required String appointmentId,
    required int amount,
    String currency = 'pkr',
    required String successUrl,
    required String cancelUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      debugPrint('=== Creating Patient Checkout Session ===');
      debugPrint('PatientId: $patientId');
      debugPrint('DoctorId: $doctorId');
      debugPrint('Amount: $amount');
      debugPrint('Token present: ${token != null && token.isNotEmpty}');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/Stripe/patient/create-checkout-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'patientId': patientId,
          'doctorId': doctorId,
          'appointmentId': appointmentId,
          'amount': amount,
          'currency': currency,
          'successUrl': successUrl,
          'cancelUrl': cancelUrl,
        }),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['isSuccess'] == true) {
          debugPrint('Checkout session created successfully!');
          debugPrint('Session URL: ${data['sessionUrl']}');
          return CheckoutSessionResult(
            isSuccess: true,
            sessionId: data['sessionId'],
            sessionUrl: data['sessionUrl'],
          );
        } else {
          debugPrint(
              'API returned isSuccess: false, message: ${data['message']}');
          return CheckoutSessionResult(
            isSuccess: false,
            message: data['message'] ?? 'Failed to create checkout session',
          );
        }
      } else {
        debugPrint('HTTP error: ${response.statusCode}');
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(response.body);
          return CheckoutSessionResult(
            isSuccess: false,
            message:
                errorData['message'] ?? 'Server error: ${response.statusCode}',
          );
        } catch (_) {
          return CheckoutSessionResult(
            isSuccess: false,
            message: 'Server error: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      debugPrint('Exception in createPatientCheckoutSession: $e');
      return CheckoutSessionResult(
        isSuccess: false,
        message: e.toString(),
      );
    }
  }

  // Process payment using payment sheet
  static Future<PaymentResult> processPaymentWithSheet({
    required String clientSecret,
    required String merchantDisplayName,
  }) async {
    try {
      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName,
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF2e7d32),
            ),
          ),
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      return PaymentResult(isSuccess: true, message: 'Payment successful');
    } on StripeException catch (e) {
      return PaymentResult(
        isSuccess: false,
        message: e.error.localizedMessage ?? 'Payment failed',
      );
    } catch (e) {
      return PaymentResult(
        isSuccess: false,
        message: e.toString(),
      );
    }
  }

  // Open checkout URL in browser
  static Future<bool> openCheckoutUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  // Get Stripe configuration
  static Future<StripeConfig?> getStripeConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/Stripe/config'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return StripeConfig(
          publishableKey: data['publishableKey'],
          doctorMonthlyFee: data['doctorMonthlyFee'],
          currency: data['currency'],
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting Stripe config: $e');
      return null;
    }
  }
}

class PaymentIntentResult {
  final bool isSuccess;
  final String? clientSecret;
  final String? paymentIntentId;
  final String? message;

  PaymentIntentResult({
    required this.isSuccess,
    this.clientSecret,
    this.paymentIntentId,
    this.message,
  });
}

class CheckoutSessionResult {
  final bool isSuccess;
  final String? sessionId;
  final String? sessionUrl;
  final String? message;

  CheckoutSessionResult({
    required this.isSuccess,
    this.sessionId,
    this.sessionUrl,
    this.message,
  });
}

class PaymentResult {
  final bool isSuccess;
  final String message;

  PaymentResult({
    required this.isSuccess,
    required this.message,
  });
}

class StripeConfig {
  final String publishableKey;
  final int doctorMonthlyFee;
  final String currency;

  StripeConfig({
    required this.publishableKey,
    required this.doctorMonthlyFee,
    required this.currency,
  });
}
