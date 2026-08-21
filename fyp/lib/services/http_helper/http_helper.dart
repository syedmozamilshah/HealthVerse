import 'package:http/http.dart' as http;

/// HTTP helper that automatically adds ngrok-skip-browser-warning header
/// to bypass ngrok's interstitial page while keeping all other headers intact.
/// Also works perfectly with localhost/ADB reverse setup.
class HttpHelper {
  static const Duration _timeout = Duration(seconds: 30);
  
  /// Creates headers with ngrok bypass header added
  static Map<String, String> createHeaders({
    String? contentType,
    String? authorization,
    Map<String, String>? additionalHeaders,
  }) {
    final Map<String, String> headers = {
      'ngrok-skip-browser-warning': 'true',
    };

    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }

    if (authorization != null) {
      headers['Authorization'] = authorization;
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// GET request with ngrok bypass and timeout
  static Future<http.Response> get(
    Uri url, {
    String? contentType,
    String? authorization,
    Map<String, String>? additionalHeaders,
    Duration? timeout,
  }) {
    return http.get(
      url,
      headers: createHeaders(
        contentType: contentType,
        authorization: authorization,
        additionalHeaders: additionalHeaders,
      ),
    ).timeout(timeout ?? _timeout);
  }

  /// POST request with ngrok bypass and timeout
  static Future<http.Response> post(
    Uri url, {
    String? contentType,
    String? authorization,
    Object? body,
    Map<String, String>? additionalHeaders,
    Duration? timeout,
  }) {
    return http.post(
      url,
      headers: createHeaders(
        contentType: contentType,
        authorization: authorization,
        additionalHeaders: additionalHeaders,
      ),
      body: body,
    ).timeout(timeout ?? _timeout);
  }

  /// PUT request with ngrok bypass and timeout
  static Future<http.Response> put(
    Uri url, {
    String? contentType,
    String? authorization,
    Object? body,
    Map<String, String>? additionalHeaders,
    Duration? timeout,
  }) {
    return http.put(
      url,
      headers: createHeaders(
        contentType: contentType,
        authorization: authorization,
        additionalHeaders: additionalHeaders,
      ),
      body: body,
    ).timeout(timeout ?? _timeout);
  }

  /// DELETE request with ngrok bypass and timeout
  static Future<http.Response> delete(
    Uri url, {
    String? contentType,
    String? authorization,
    Map<String, String>? additionalHeaders,
    Duration? timeout,
  }) {
    return http.delete(
      url,
      headers: createHeaders(
        contentType: contentType,
        authorization: authorization,
        additionalHeaders: additionalHeaders,
      ),
    ).timeout(timeout ?? _timeout);
  }
}
