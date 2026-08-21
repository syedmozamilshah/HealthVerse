import 'package:fyp/utils/pakistan_time_helper.dart';
import '../api_client/api_client.dart';

// M-10 USED FOR  CHECKOUT SESSION, SUBSCRIPTION STATUS, PAYMENT HISTORY AND CALLING APIS
class PaymentService {
  final ApiClient _apiClient = ApiClient();

  // Get Stripe config (publishable key)
  Future<StripeConfigResponse> getStripeConfig() async {
    try {
      final response = await _apiClient.client.get('/api/stripe/config');
      return StripeConfigResponse.fromJson(response.data);
    } catch (e) {
      print('Error getting Stripe config: $e');
      rethrow;
    }
  }

  // Create checkout session for appointment payment
  Future<CheckoutSessionResponse> createAppointmentCheckout({
    required String patientId,
    required String doctorId,
    required String appointmentId,
    required int amountInPaisa,
    required String successUrl,
    required String cancelUrl,
  }) async {
    try {
      final response = await _apiClient.client.post(
        '/api/stripe/create-appointment-checkout',
        data: {
          'patientId': patientId,
          'doctorId': doctorId,
          'appointmentId': appointmentId,
          'amount': amountInPaisa,
          'successUrl': successUrl,
          'cancelUrl': cancelUrl,
        },
      );
      return CheckoutSessionResponse.fromJson(response.data);
    } catch (e) {
      print('Error creating appointment checkout: $e');
      rethrow;
    }
  }

  // Get subscription status for a doctor
  Future<SubscriptionStatusResponse> getDoctorSubscriptionStatus(
      String doctorId) async {
    try {
      final response = await _apiClient.client.get(
        '/api/stripe/subscription-status',
        queryParameters: {'doctorId': doctorId},
      );
      return SubscriptionStatusResponse.fromJson(response.data);
    } catch (e) {
      print('Error getting subscription status: $e');
      rethrow;
    }
  }

  // Get payment history
  Future<List<PaymentHistoryItem>> getPaymentHistory(String doctorId) async {
    try {
      final response = await _apiClient.client.get(
        '/api/stripe/payment-history',
        queryParameters: {'doctorId': doctorId},
      );

      if (response.data['isSuccess'] == true) {
        final List<dynamic> data = response.data['data'];
        return data.map((e) => PaymentHistoryItem.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting payment history: $e');
      rethrow;
    }
  }
}

// Response models
class StripeConfigResponse {
  final String publishableKey;

  StripeConfigResponse({required this.publishableKey});

  factory StripeConfigResponse.fromJson(Map<String, dynamic> json) {
    return StripeConfigResponse(
      publishableKey: json['publishableKey'] ?? '',
    );
  }
}

class CheckoutSessionResponse {
  final bool isSuccess;
  final String message;
  final String sessionId;
  final String sessionUrl;

  CheckoutSessionResponse({
    required this.isSuccess,
    required this.message,
    required this.sessionId,
    required this.sessionUrl,
  });

  factory CheckoutSessionResponse.fromJson(Map<String, dynamic> json) {
    return CheckoutSessionResponse(
      isSuccess: json['isSuccess'] ?? false,
      message: json['message'] ?? '',
      sessionId: json['sessionId'] ?? '',
      sessionUrl: json['sessionUrl'] ?? '',
    );
  }
}

class SubscriptionStatusResponse {
  final bool isSuccess;
  final String message;
  final bool isSubscribed;
  final bool isPaymentCurrent;
  final String subscriptionStatus;
  final DateTime? currentPeriodEnd;
  final DateTime? nextPaymentDate;
  final int amountDue;

  SubscriptionStatusResponse({
    required this.isSuccess,
    required this.message,
    required this.isSubscribed,
    required this.isPaymentCurrent,
    required this.subscriptionStatus,
    this.currentPeriodEnd,
    this.nextPaymentDate,
    required this.amountDue,
  });

  factory SubscriptionStatusResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatusResponse(
      isSuccess: json['isSuccess'] ?? false,
      message: json['message'] ?? '',
      isSubscribed: json['isSubscribed'] ?? false,
      isPaymentCurrent: json['isPaymentCurrent'] ?? false,
      subscriptionStatus: json['subscriptionStatus'] ?? 'not_subscribed',
      currentPeriodEnd: json['currentPeriodEnd'] != null
          ? PakistanTimeHelper.parseUtc(json['currentPeriodEnd'].toString())
          : null,
      nextPaymentDate: json['nextPaymentDate'] != null
          ? PakistanTimeHelper.parseUtc(json['nextPaymentDate'].toString())
          : null,
      amountDue: json['amountDue'] ?? 0,
    );
  }
}

class PaymentHistoryItem {
  final String id;
  final String doctorId;
  final String? patientId;
  final String? appointmentId;
  final int amount;
  final String currency;
  final String paymentType;
  final String status;
  final String description;
  final DateTime createdAt;
  final DateTime? paidAt;

  PaymentHistoryItem({
    required this.id,
    required this.doctorId,
    this.patientId,
    this.appointmentId,
    required this.amount,
    required this.currency,
    required this.paymentType,
    required this.status,
    required this.description,
    required this.createdAt,
    this.paidAt,
  });

  factory PaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryItem(
      id: json['id'] ?? '',
      doctorId: json['doctorId'] ?? '',
      patientId: json['patientId'],
      appointmentId: json['appointmentId'],
      amount: json['amount'] ?? 0,
      currency: json['currency'] ?? 'pkr',
      paymentType: json['paymentType'] ?? '',
      status: json['status'] ?? '',
      description: json['description'] ?? '',
      createdAt: PakistanTimeHelper.parseUtc(json['createdAt'].toString()),
      paidAt: json['paidAt'] != null
          ? PakistanTimeHelper.parseUtc(json['paidAt'].toString())
          : null,
    );
  }

  // Helper to format amount in rupees
  String get formattedAmount {
    return 'Rs. ${(amount / 100).toStringAsFixed(0)}';
  }
}
