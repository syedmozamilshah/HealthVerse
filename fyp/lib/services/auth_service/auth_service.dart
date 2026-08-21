import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fyp/models/login_response/login_response.dart';
import 'package:fyp/models/user_data/user_data.dart';
import 'package:fyp/services/api_client/api_client.dart';
import 'package:fyp/services/http_helper/http_helper.dart';
import 'package:fyp/views/links/base_url_link/base_url_link.dart';
import 'package:fyp/views/widgets/app_popup/app_popup.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';

// M-1 CALLING ALL THE BACKEND API RELATED TO AUTHENTICATION
class AuthService {
  final ApiClient apiClient = ApiClient();
  Future<void> registerUser(
    String firstName,
    String lastName,
    String email,
    String password,
    String phoneNumber,
    String gender,
    String dob,
    String address,
    String bloodGroup,
    String patientType,
    context,
    Function(bool) setLoading,
    Function navigateToSignIn,
  ) async {
    setLoading(true);

    try {
      final String baseUrl = base_url;
      final Uri url = Uri.parse('$baseUrl/api/Auth/register');

      final response = await HttpHelper.post(
        url,
        contentType: 'application/json',
        body: jsonEncode({
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'password': password,
          'whatsapp_no': phoneNumber,
          'dob': dob,
          'address': address,
          'blood_group': bloodGroup,
          'gender': gender,
          'profile_type': patientType
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        reusableSnackBar(
          context,
          "Registration successful! Verification email sent. Please check your inbox.",
          onDismiss: () {
            navigateToSignIn();
          },
          autoDismiss: false,
        );
      } else {
        final responseBody = jsonDecode(response.body);
        final serverMessage =
            (responseBody['message'] ?? responseBody['Message'] ?? '')
                .toString();

        final isDuplicateEmail = response.statusCode == 400 &&
            serverMessage.toLowerCase().contains('already exists');

        if (isDuplicateEmail) {
          AppPopup.show(
            context,
            title: 'Email already registered',
            message:
                'This email is already registered with HealthVerse. Please sign in with your existing account, or use a different email to create a new one.',
            type: PopupType.warning,
            autoDismiss: false,
            onDismiss: () {
              navigateToSignIn();
            },
          );
        } else {
          reusableSnackBar(context,
              "Error: ${serverMessage.isNotEmpty ? serverMessage : response.body}");
        }
      }
    } catch (e) {
      reusableSnackBar(context, "Request failed: $e");
    } finally {
      setLoading(false);
    }
  }

  Future<LoginResponse> signInUser(
      String email, String password, context, Function(bool) setLoading) async {
    setLoading(true);

    try {
      String baseUrl = base_url;

      final Uri url = Uri.parse('$baseUrl/api/Auth/login');

      final response = await HttpHelper.post(
        url,
        contentType: 'application/json',
        body: jsonEncode(
            {'email': email, 'password': password, 'profile_type': 'patient'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return LoginResponse.fromJson(json);
      } else {
        final responseBody = jsonDecode(response.body);
        print(LoginResponse.fromJson(responseBody).message);

        return LoginResponse.fromJson(responseBody);
      }
    } catch (e) {
      setLoading(false);
      print("Login error: $e");
      // Show the full exception message so the UI can display detailed network errors
      reusableSnackBar(context, "Network issue: $e");
      return LoginResponse(
          isSuccess: false,
          message: "Network issue: $e",
          token: "",
          refreshToken: "",
          tokenExpired: 0,
          refreshExpired: 0,
          user: const UserData(
              id: '',
              fName: '',
              lName: '',
              email: '',
              number: '',
              gender: '',
              password: '',
              dob: '',
              imageUrl: '',
              address: '',
              bloodGroup: '',
              profileType: ''));
    } finally {
      setLoading(false);
    }
  }

  Future<void> forgotPassword(
    String email,
    context,
    Function(bool) setLoading,
    Function navigateToSignIn,
  ) async {
    setLoading(true);

    try {
      final String baseUrl = base_url;
      final Uri url = Uri.parse('$baseUrl/api/Auth/forgot-password');
      final response = await HttpHelper.post(
        url,
        contentType: 'application/json',
        body: jsonEncode({'email': email, 'profileType': "patient"}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        reusableSnackBar(context, responseBody['message'] ?? response.body);
        navigateToSignIn();
      } else {
        final responseBody = jsonDecode(response.body);
        reusableSnackBar(context, responseBody['message'] ?? response.body);
      }
    } catch (e) {
      setLoading(false);
      reusableSnackBar(context, "Request failed: $e");
      throw Exception("email send failed: $e");
    } finally {
      setLoading(false);
    }
  }

  Future<void> resetPassword(
    String prevPassword,
    String newPassword,
    context,
    Function(bool) setLoading,
    Function navigateToProfileScreen,
  ) async {
    setLoading(true);

    try {
      final response = await apiClient.client.post(
        '/api/Auth/reset-password',
        data: {
          'previousPassword': prevPassword,
          'newPassword': newPassword,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = (response.data);

        print('Reset password response: $responseBody');

        setLoading(false);

        reusableSnackBar(context, 'Password reset successful');

        // Wait a bit before navigating so user can see the message
        await Future.delayed(const Duration(milliseconds: 1500));
        navigateToProfileScreen();
        return; // Exit early to avoid finally block
      } else {
        final responseBody = (response.data);
        String message = responseBody['message'] ??
            responseBody['Message'] ??
            'Password reset failed';
        reusableSnackBar(context, message);
      }
    } on DioException catch (e) {
      setLoading(false);
      String errorMessage = "reset password failed";

      // Extract error message from response
      if (e.response?.data != null) {
        try {
          final errorData = e.response!.data;
          if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          } else if (errorData is Map && errorData.containsKey('Message')) {
            errorMessage = errorData['Message'];
          } else if (errorData is String) {
            errorMessage = errorData;
          }
        } catch (_) {
          errorMessage = "Previous password is incorrect or request failed";
        }
      }

      reusableSnackBar(context, errorMessage);
      throw Exception("reset password failed: $e");
    } catch (e) {
      setLoading(false);
      reusableSnackBar(context, "reset password failed: $e");
      throw Exception("reset password failed: $e");
    } finally {
      setLoading(false);
    }
  }
}
