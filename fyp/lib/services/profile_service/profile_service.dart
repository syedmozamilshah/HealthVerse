import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fyp/services/api_client/api_client.dart';
import 'package:fyp/views/widgets/reusable_snack_bar/reusable_snack_bar.dart';
import 'package:image_picker/image_picker.dart';

// M-2 FOR CALLING ALL THE PROFILE RELATED API ENDPOINTS
class ProfileService {
  final ApiClient apiClient = ApiClient();

  // Allowed image extensions
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp'
  ];

  // Maximum file size in bytes (1 MB)
  static const int maxFileSizeBytes = 1 * 1024 * 1024; // 1 MB

  Future<void> updateName(String firstName, String lastName, context,
      Function(bool) setLoading) async {
    try {
      setLoading(true);

      // Build form data - only include lastName if it's not empty
      final Map<String, dynamic> formMap = {
        'FirstName': firstName,
      };
      if (lastName.isNotEmpty) {
        formMap['LastName'] = lastName;
      }

      final formData = FormData.fromMap(formMap);

      final response = await apiClient.client.post(
        '/api/User/profile/update',
        data: formData,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        reusableSnackBar(context, "Name updated");
      } else {
        final responseBody = (response.data);
        reusableSnackBar(
            context, "Error: ${responseBody['message'] ?? response.data}");
      }
    } catch (e) {
      reusableSnackBar(context, "Request failed: $e");
    } finally {
      setLoading(false);
    }
  }

  Future<void> updateAddress(
      String address, context, Function(bool) setLoading) async {
    try {
      setLoading(true);
      final formData = FormData.fromMap({'Address': address});

      final response = await apiClient.client.post(
        '/api/User/profile/update',
        data: formData,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        reusableSnackBar(context, "address updated");
      } else {
        final responseBody = (response.data);
        reusableSnackBar(
            context, "Error: ${responseBody['message'] ?? response.data}");
      }
    } catch (e) {
      reusableSnackBar(context, "Request failed: $e");
    } finally {
      setLoading(false);
    }
  }

  Future<void> updateNumber(
      String number, context, Function(bool) setLoading) async {
    try {
      setLoading(true);
      final formData = FormData.fromMap({'WhatsappNo': number});

      final response = await apiClient.client.post(
        '/api/User/profile/update',
        data: formData,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        reusableSnackBar(context, "number updated");
      } else {
        final responseBody = (response.data);
        reusableSnackBar(
            context, "Error: ${responseBody['message'] ?? response.data}");
      }
    } catch (e) {
      reusableSnackBar(context, "Request failed: $e");
    } finally {
      setLoading(false);
    }
  }

  /// Pick image from gallery - returns XFile which works on both web and mobile
  /// Returns null if image doesn't meet validation requirements
  Future<XFile?> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    return pickedFile;
  }

  /// Validate image file format and size
  /// Returns error message if invalid, null if valid
  Future<String?> validateImage(XFile image) async {
    // Check file extension
    final String fileName = image.name.toLowerCase();
    final String extension =
        fileName.contains('.') ? fileName.split('.').last : '';

    if (!allowedExtensions.contains(extension)) {
      return 'Invalid file format. Allowed formats: ${allowedExtensions.join(', ').toUpperCase()}';
    }

    // Check file size
    final bytes = await image.readAsBytes();
    final int fileSize = bytes.length;

    if (fileSize > maxFileSizeBytes) {
      final double sizeMB = fileSize / (1024 * 1024);
      return 'File size (${sizeMB.toStringAsFixed(2)} MB) exceeds maximum limit of 1 MB';
    }

    return null; // Valid image
  }

  /// Update user profile image - works on both web and mobile platforms
  Future<String?> updateUserProfileImage(
      XFile image, context, Function(bool) setLoading) async {
    try {
      setLoading(true);

      FormData formData;

      if (kIsWeb) {
        // For web: use bytes since dart:io File is not available
        final bytes = await image.readAsBytes();
        formData = FormData.fromMap({
          'ProfileImage': MultipartFile.fromBytes(
            bytes,
            filename: image.name,
          ),
        });
      } else {
        // For mobile: use file path
        formData = FormData.fromMap({
          'ProfileImage': await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
        });
      }

      final response = await apiClient.client.post(
        '/api/User/profile/update',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        reusableSnackBar(context, "Image updated");
        return response.data['imageUrl'];
      } else {
        reusableSnackBar(
            context, "Error: ${response.data['message'] ?? response.data}");
        return null;
      }
    } catch (e) {
      reusableSnackBar(context, "Error: $e");
      return null;
    } finally {
      setLoading(false);
    }
  }

  /// Send forgot password email to reset password
  Future<void> sendForgotPasswordEmail(
      String email, context, Function(bool) setLoading) async {
    try {
      setLoading(true);

      final response = await apiClient.client.post(
        '/api/Auth/forgot-password',
        data: {
          'email': email,
          'profileType': 'patient',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        reusableSnackBar(context,
            response.data['message'] ?? 'Reset link sent to your email!');
      } else {
        reusableSnackBar(context,
            "Error: ${response.data['message'] ?? 'Failed to send reset link'}");
      }
    } catch (e) {
      reusableSnackBar(context, "Error sending reset link: $e");
    } finally {
      setLoading(false);
    }
  }
}
