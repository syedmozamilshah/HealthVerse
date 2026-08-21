// import 'package:dio/dio.dart';
// import 'package:dio/io.dart';
// import 'package:fyp/views/links/base_url_link/base_url_link.dart';
// import 'dart:io';

// import '../../models/login_response/login_response.dart';
// import '../../provider/state_notifier_provider/auth_provider/auth_provider.dart';

// class ApiClient {
//   static final ApiClient _instance = ApiClient._internal();
//   factory ApiClient() => _instance;
//   ApiClient._internal();

//   late Dio _dio;
//   AuthProvider? _authProvider;
//   bool _isRefreshing = false;
//   final List<RequestOptions> _pendingRequests = [];
//   bool _initialized = false;

//   void init(AuthProvider authProvider) {
//     _authProvider = authProvider;

//     // Create BaseOptions with token if available
//     final headers = <String, dynamic>{
//       'Content-Type': 'application/json',
//       'ngrok-skip-browser-warning': 'true',
//     };

//     if (authProvider.session?.token != null) {
//       headers['Authorization'] = 'Bearer ${authProvider.session?.token}';
//     }

//     _dio = Dio(BaseOptions(
//       baseUrl: base_url,
//       headers: headers,
//     ));
//     _configureHttpClient();
//     _setupInterceptor();
//     _initialized = true;
//   }

//   Dio get client {
//     if (!_initialized) {
//       final headers = <String, dynamic>{
//         'Content-Type': 'application/json',
//         'ngrok-skip-browser-warning': 'true',
//       };

//       if (_authProvider?.session?.token != null) {
//         headers['Authorization'] = 'Bearer ${_authProvider?.session?.token}';
//       }

//       _dio = Dio(BaseOptions(
//         baseUrl: base_url,
//         headers: headers,
//       ));
//       _configureHttpClient();
//     }
//     return _dio;
//   }

//   void _configureHttpClient() {
//     // Configure HttpClient for HTTPS support
//     _dio.httpClientAdapter = IOHttpClientAdapter(
//       onHttpClientCreate: (client) {
//         client.badCertificateCallback =
//             (X509Certificate cert, String host, int port) => true;
//         return client;
//       },
//     );
//   }

//   void _setupInterceptor() {
//     _dio.interceptors.clear();
//     _dio.interceptors.add(
//       InterceptorsWrapper(
//         onRequest: (options, handler) async {
//           // Add ngrok bypass header to all requests
//           options.headers['ngrok-skip-browser-warning'] = 'true';

//           final session = _authProvider?.session;
//           final token = session?.token;

//           if (session != null && token != null) {
//             final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

//             // Check if token is expired
//             if (session.tokenExpired < now) {
//               if (session.refreshExpired < now) {
//                 await _authProvider?.logout();
//                 return handler.next(options);
//               } else {
//                 // Token is expired but refresh token is valid
//                 if (!_isRefreshing) {
//                   // Start refresh process
//                   _isRefreshing = true;
//                   await _refreshToken(session.refreshToken);
//                   _isRefreshing = false;

//                   // Process pending requests
//                   for (final pendingRequest in _pendingRequests) {
//                     pendingRequest.headers['Authorization'] =
//                         'Bearer ${_authProvider?.session?.token}';
//                   }
//                   _pendingRequests.clear();
//                 } else {
//                   // Already refreshing, add to pending requests
//                   _pendingRequests.add(options);
//                   return handler.next(options);
//                 }
//               }
//             }

//             // Add authorization header
//             options.headers['Authorization'] = 'Bearer $token';
//           } else {}

//           return handler.next(options);
//         },
//         onResponse: (response, handler) {},
//         onError: (DioException error, handler) {
//           return handler.next(error);
//         },
//       ),
//     );
//   }

//   Future<void> _refreshToken(String refreshToken) async {
//     try {
//       // Create a new Dio instance to avoid interceptor recursion
//       final refreshDio = Dio(BaseOptions(
//         baseUrl: base_url,
//         headers: {'ngrok-skip-browser-warning': 'true'},
//       ));

//       // Configure HTTPS for refresh Dio as well
//       refreshDio.httpClientAdapter = IOHttpClientAdapter(
//         onHttpClientCreate: (client) {
//           client.badCertificateCallback =
//               (X509Certificate cert, String host, int port) => true;
//           return client;
//         },
//       );

//       final res = await refreshDio.get(
//         '/api/Auth/loginByRefreshToken',
//         queryParameters: {'refreshToken': refreshToken},
//       );
//       final newSession = LoginResponse.fromJson(res.data);
//       await _authProvider?.login(newSession);
//     } catch (e) {
//       await _authProvider?.logout();
//     }
//   }
// }

import 'package:dio/dio.dart';
import 'package:fyp/views/links/base_url_link/base_url_link.dart';

import '../../models/login_response/login_response.dart';
import '../../provider/state_notifier_provider/auth_provider/auth_provider.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late Dio _dio;
  AuthProvider? _authProvider;
  bool _isRefreshing = false;
  final List<RequestOptions> _pendingRequests = [];
  bool _initialized = false;

  void init(AuthProvider authProvider) {
    _authProvider = authProvider;
    // Always reinitialize Dio with current base_url
    _dio = Dio(BaseOptions(baseUrl: base_url));
    _setupInterceptor();
    _initialized = true;

    print("Done with api client");
    print("ApiClient initialized with base_url: $base_url");
    print("ApiClient initialized with token: ${authProvider.session?.token}");
  }

  Dio get client {
    if (!_initialized) {
      _dio = Dio(BaseOptions(baseUrl: base_url));
    }
    return _dio;
  }

  void _setupInterceptor() {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add ngrok bypass header to all requests
          options.headers['ngrok-skip-browser-warning'] = 'true';

          final session = _authProvider?.session;

          if (session != null) {
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

            // Check if token is expired
            if (session.tokenExpired < now) {
              if (session.refreshExpired < now) {
                // Refresh token is also expired, logout
                await _authProvider?.logout();
                return handler.next(options);
              } else {
                // Token is expired but refresh token is valid
                if (!_isRefreshing) {
                  // Start refresh process
                  _isRefreshing = true;
                  await _refreshToken(session.refreshToken);
                  _isRefreshing = false;

                  // Process pending requests
                  for (final pendingRequest in _pendingRequests) {
                    pendingRequest.headers['Authorization'] =
                        'Bearer ${_authProvider?.session?.token}';
                  }
                  _pendingRequests.clear();
                } else {
                  // Already refreshing, add to pending requests
                  _pendingRequests.add(options);
                  return handler.next(options);
                }
              }
            }

            // Add authorization header
            options.headers['Authorization'] =
                'Bearer ${_authProvider?.session?.token}';
          }
          print("Interceptor attached, authProvider: $_authProvider");
          return handler.next(options);
        },
      ),
    );
  }

  Future<void> _refreshToken(String refreshToken) async {
    print("calling to get the access token from refresh token");
    try {
      // Create a new Dio instance to avoid interceptor recursion
      final refreshDio = Dio(BaseOptions(
        baseUrl: base_url,
        headers: {'ngrok-skip-browser-warning': 'true'},
      ));
      final res = await refreshDio.get(
        '/api/Auth/loginByRefreshToken',
        queryParameters: {'refreshToken': refreshToken},
      );
      final newSession = LoginResponse.fromJson(res.data);
      await _authProvider?.login(newSession);
    } catch (e) {
      print("Error refreshing token: $e");
      await _authProvider?.logout();
    }
  }
}
