import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;

/// Harpy HTTP Request wrapper
///
/// Provides convenient access to request data with additional functionality
/// beyond the standard Shelf Request.
class Request {
  /// Create a new Request from a Shelf Request
  Request(this._request);
  final shelf.Request _request;
  final Map<String, String> _params = {};
  Map<String, dynamic>? _body;

  /// HTTP method (GET, POST, PUT, DELETE, etc.)
  String get method => _request.method;

  /// Request URI
  Uri get uri => _request.requestedUri;

  /// Request path
  String get path => _request.url.path;

  /// Query parameters
  Map<String, String> get query => _request.url.queryParameters;

  /// Request headers
  Map<String, String> get headers => _request.headers;

  /// Route parameters (e.g., /users/:id)
  Map<String, String> get params => Map.unmodifiable(_params);

  /// Add a route parameter
  void addParam(String key, String value) {
    _params[key] = value;
  }

  /// Get request body as string
  Future<String> text() => _request.readAsString();

  /// Parse request body as JSON
  Future<Map<String, dynamic>> json() async {
    if (_body != null) return _body!;

    final bodyString = await text();
    if (bodyString.isEmpty) {
      _body = <String, dynamic>{};
    } else {
      try {
        final decoded = jsonDecode(bodyString);
        if (decoded is! Map<String, dynamic>) {
          throw FormatException(
            'Request body is not a JSON object, got: ${decoded.runtimeType}',
          );
        }
        _body = decoded;
      } catch (e, st) {
        Error.throwWithStackTrace(
          FormatException('Invalid JSON in request body: $e'),
          st,
        );
      }
    }
    return _body!;
  }

  /// Get content type
  String? get contentType => _request.headers[HttpHeaders.contentTypeHeader];

  /// Check if request accepts JSON
  bool get acceptsJson {
    final accept = _request.headers[HttpHeaders.acceptHeader];
    return accept?.contains('application/json') ?? false;
  }

  /// Check if request has JSON content type
  bool get isJson => contentType?.startsWith('application/json') ?? false;

  /// Get user agent
  String? get userAgent => _request.headers[HttpHeaders.userAgentHeader];

  /// Get remote address
  String? get remoteAddress {
    final info = _request.context['shelf.io.connection_info'];
    if (info is HttpConnectionInfo) {
      return info.remoteAddress.address;
    }
    return null;
  }
}
