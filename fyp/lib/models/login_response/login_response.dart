import 'package:fyp/models/user_data/user_data.dart';

// M-1 USED FOR AUTHENTICATION
class LoginResponse {
  final bool isSuccess;
  final String message;
  final String token;
  final String refreshToken;
  final int tokenExpired;
  final int refreshExpired;
  final UserData user;

  LoginResponse(
      {required this.isSuccess,
      required this.message,
      required this.token,
      required this.refreshToken,
      required this.tokenExpired,
      required this.refreshExpired,
      required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
        isSuccess: json["isSuccess"] ?? false,
        message: json["message"] ?? '',
        token: json["token"] ?? '',
        refreshToken: json["refreshToken"] ?? '',
        tokenExpired: json["tokenExpired"] ?? 0,
        refreshExpired: json["refreshExpired"] ?? 0,
        user: UserData.fromJson(json["user"] ?? {}));
  }

  factory LoginResponse.fromSessionJson(Map<String, dynamic> json) {
    return LoginResponse(
        isSuccess: json["isSuccess"] ?? false,
        message: json["message"] ?? '',
        token: json["token"] ?? '',
        refreshToken: json["refreshToken"] ?? '',
        tokenExpired: json["tokenExpired"] ?? 0,
        refreshExpired: json["refreshExpired"] ?? 0,
        user: UserData.fromSessionJson(json["user"] ?? {}));
  }

  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'message': message,
      'token': token,
      'refreshToken': refreshToken,
      'tokenExpired': tokenExpired,
      'refreshExpired': refreshExpired,
      'user': user.toMap(),
    };
  }
}
