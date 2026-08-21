import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/login_response/login_response.dart';

// M-1 STORING THE SESSION IN SECURE STORAGE
class AuthStorage {
  final _storage = const FlutterSecureStorage();
  final _key = 'sessionState';

  Future<void> saveSession(LoginResponse response) async {
    await _storage.write(key: _key, value: jsonEncode(response.toJson()));
  }

  Future<LoginResponse?> getSession() async {
    final data = await _storage.read(key: _key);
    if (data == null) {
      return null;
    }
    final map = jsonDecode(data) as Map<String, dynamic>;
    final response = LoginResponse.fromSessionJson(map);
    return response;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _key);
  }
}
