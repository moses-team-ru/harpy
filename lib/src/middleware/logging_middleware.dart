import 'package:shelf/shelf.dart' as shelf;
import 'middleware.dart';

/// Request logging middleware
///
/// Logs HTTP requests with timing information and response status codes.
class LoggingMiddleware implements Middleware {
  final bool logBody;
  final bool logHeaders;
  final Function(String)? logger;

  const LoggingMiddleware({
    this.logBody = false,
    this.logHeaders = false,
    this.logger,
  });

  @override
  shelf.Middleware call() =>
      (shelf.Handler innerHandler) => (shelf.Request request) async {
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
                final body = await request.readAsString();
                _log('  Body: $body');
                // Create new request with the same body since it was consumed
                request = request.change(body: body);
              } catch (e) {
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
    } else {
      return '📝'; // Other
    }
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
