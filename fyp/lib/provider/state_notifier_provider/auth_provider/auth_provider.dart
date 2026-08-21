import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/login_response/login_response.dart';
import '../../../models/user_data/user_data.dart';
import '../../../services/auth_storage/auth_storage.dart';

// M-1 USED FOR STORING THE AUTH SESSION
class AuthProvider extends ChangeNotifier {
  final AuthStorage _storage = AuthStorage();
  LoginResponse? _session;

  LoginResponse? get session => _session;
  bool get isAuthenticated => _session != null;

  Future<void> loadSession() async {
    _session = await _storage.getSession();
    notifyListeners();
  }

  Future<void> login(LoginResponse response) async {
    _session = response;
    print(response.message);
    print(response.user.fName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _session!.token);
    await _storage.saveSession(response);
    notifyListeners();
  }

  Future<void> logout() async {
    _session = null;
    await _storage.clearSession();
    notifyListeners();
  }

  Future<void> updateUserInSession(UserData user) async {
    if (_session == null) return;

    _session = LoginResponse(
        isSuccess: true,
        message: "updated",
        token: session!.token,
        refreshToken: session!.refreshToken,
        tokenExpired: session!.tokenExpired,
        refreshExpired: session!.refreshExpired,
        user: user);

    await _storage.saveSession(_session!);
    notifyListeners();
  }
}

final authProviderNotifier = ChangeNotifierProvider<AuthProvider>((ref) {
  return AuthProvider();
});
