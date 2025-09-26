import 'dart:convert';

import 'package:harpy/src/middleware/middleware.dart';
import 'package:shelf/shelf.dart' as shelf;

/// Request logging middleware
///
/// Logs HTTP requests with timing information and response status codes.
class LoggingMiddleware implements Middleware {
  /// Create logging middleware
  /// [logBody] determines whether to log request bodies (for POST, PUT, PATCH requests).
  /// [logHeaders] determines whether to log request headers.
  /// [logger] is an optional custom logging function (defaults to print).
  const LoggingMiddleware({
    this.logBody = false,
    this.logHeaders = false,
    this.logger,
  });

  /// Whether to log request bodies (for POST, PUT, PATCH requests)
  final bool logBody;

  /// Whether to log request headers
  final bool logHeaders;

  /// Custom logger function (defaults to print)
  final Function(String)? logger;

  @override
  shelf.Middleware call() => (shelf.Handler innerHandler) =>
      (shelf.Request request) async {
        final startTime = DateTime.now();
        final method = request.method;
        final path = request.requestedUri.path;
        final query = request.requestedUri.query;
        final fullPath = query.isEmpty ? path : '$path?$query';

        _log('→ $method $fullPath');

        if (logHeaders) {
          _log('  Headers: ${request.headers}');
        }

        if (logBody && _hasBody(request)) {
          try {
            // Read body only once and create new request with it
            final bodyBytes = await request.read().toList();
            final bodyString =
                utf8.decode(bodyBytes.expand((chunk) => chunk).toList());
            _log(
              '  Body: ${bodyString.isNotEmpty ? bodyString : '[Empty body]'}',
            );

            // Create new request with the body stream
            request = request.change(
              body: Stream.value(bodyBytes.expand((chunk) => chunk).toList()),
            );
          } on Exception catch (e) {
            _log('  Body: [Error reading body: $e]');
          }
        }

        try {
          final response = await innerHandler(request);
          final duration = DateTime.now().difference(startTime);
          final statusCode = response.statusCode;
          final statusEmoji = _getStatusEmoji(statusCode);

          _log(
            '← $statusEmoji $method $fullPath - $statusCode (${duration.inMilliseconds}ms)',
          );

          return response;
        } catch (error, stackTrace) {
          final duration = DateTime.now().difference(startTime);
          _log(
            '← ❌ $method $fullPath - ERROR (${duration.inMilliseconds}ms): $error',
          );

          if (logHeaders) {
            _log('  Stack trace: $stackTrace');
          }

          rethrow;
        }
      };

  void _log(String message) {
    if (logger != null) {
      logger!(message);
    } else {
      print(message);
    }
  }

  bool _hasBody(shelf.Request request) {
    final method = request.method.toUpperCase();
    return method == 'POST' || method == 'PUT' || method == 'PATCH';
  }

  String _getStatusEmoji(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return '✅'; // Success
    } else if (statusCode >= 300 && statusCode < 400) {
      return '↩️'; // Redirect
    } else if (statusCode >= 400 && statusCode < 500) {
      return '⚠️'; // Client error
    } else if (statusCode >= 500) {
      return '❌'; // Server error
    }
    return '📝';
  }
}

/// Convenience function to create logging middleware
shelf.Middleware logging({
  bool logBody = false,
  bool logHeaders = false,
  Function(String)? logger,
}) =>
    LoggingMiddleware(
      logBody: logBody,
      logHeaders: logHeaders,
      logger: logger,
    ).call();
