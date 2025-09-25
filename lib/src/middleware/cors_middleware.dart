import 'dart:io';

import 'package:harpy/src/middleware/middleware.dart';
import 'package:shelf/shelf.dart' as shelf;

/// CORS (Cross-Origin Resource Sharing) middleware
///
/// Handles CORS headers to allow cross-origin requests from web browsers.
class CorsMiddleware implements Middleware {
  /// Create CORS middleware
  /// [origin] is the allowed origin for CORS requests. Use '*' to allow all origins.
  /// [allowedMethods] is the list of allowed HTTP methods for CORS requests.
  /// [allowedHeaders] is the list of allowed HTTP headers for CORS requests.
  /// [credentials] indicates whether to allow credentials (cookies, authorization headers, etc.)
  /// [maxAge] is the maximum age (in seconds) for preflight request caching
  const CorsMiddleware({
    this.origin,
    this.allowedMethods = const ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    this.allowedHeaders = const [
      'Origin',
      'Content-Type',
      'Accept',
      'Authorization',
    ],
    this.credentials = false,
    this.maxAge = 86400, // 24 hours
  });

  /// Allowed origin for CORS requests. Use '*' to allow all origins.
  final String? origin;

  /// Allowed HTTP methods for CORS requests.
  final List<String> allowedMethods;

  /// Allowed HTTP headers for CORS requests.
  final List<String> allowedHeaders;

  /// Whether to allow credentials (cookies, authorization headers, etc.)
  final bool credentials;

  /// Maximum age (in seconds) for preflight request caching.
  final int maxAge;

  @override
  shelf.Middleware call() =>
      (shelf.Handler innerHandler) => (shelf.Request request) async {
            // Handle preflight OPTIONS request
            if (request.method == 'OPTIONS') {
              return _createCorsResponse();
            }

            // Process the request and add CORS headers to response
            final response = await innerHandler(request);
            return _addCorsHeaders(response);
          };

  /// Create response for preflight OPTIONS request
  shelf.Response _createCorsResponse() => shelf.Response.ok(
        '',
        headers: _getCorsHeaders(),
      );

  /// Add CORS headers to existing response
  shelf.Response _addCorsHeaders(shelf.Response response) {
    final corsHeaders = _getCorsHeaders();
    final updatedHeaders = Map<String, String>.of(response.headers)
      ..addAll(corsHeaders);

    return response.change(headers: updatedHeaders);
  }

  /// Get CORS headers
  Map<String, String> _getCorsHeaders() {
    final headers = <String, String>{};

    // Set Access-Control-Allow-Origin
    if (origin != null) {
      headers[HttpHeaders.accessControlAllowOriginHeader] = origin!;
    } else {
      headers[HttpHeaders.accessControlAllowOriginHeader] = '*';
    }

    // Set other CORS headers
    headers[HttpHeaders.accessControlAllowMethodsHeader] =
        allowedMethods.join(', ');
    headers[HttpHeaders.accessControlAllowHeadersHeader] =
        allowedHeaders.join(', ');
    headers[HttpHeaders.accessControlMaxAgeHeader] = maxAge.toString();

    if (credentials) {
      headers[HttpHeaders.accessControlAllowCredentialsHeader] = 'true';
    }

    return headers;
  }
}

/// Convenience function to create CORS middleware
shelf.Middleware cors({
  String? origin,
  List<String>? allowedMethods,
  List<String>? allowedHeaders,
  bool credentials = false,
  int maxAge = 86400,
}) =>
    CorsMiddleware(
      origin: origin,
      allowedMethods:
          allowedMethods ?? ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: allowedHeaders ??
          ['Origin', 'Content-Type', 'Accept', 'Authorization'],
      credentials: credentials,
      maxAge: maxAge,
    ).call();
