import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:harpy/src/middleware/middleware.dart';
import 'package:shelf/shelf.dart' as shelf;

/// Authentication middleware
///
/// Provides JWT token validation and basic authentication support.
class AuthMiddleware implements Middleware {
  /// Create authentication middleware
  /// [jwtSecret] is the secret key used to validate JWT tokens.
  /// [excludePaths] is a list of paths to exclude from authentication.
  /// [customValidator] is an optional function to perform custom token validation.
  const AuthMiddleware({
    this.jwtSecret,
    this.excludePaths = const [],
    this.customValidator,
  });

  /// JWT secret for token validation
  final String? jwtSecret;

  /// Paths to exclude from authentication
  final List<String> excludePaths;

  /// Custom token validation function
  final Function(String token)? customValidator;

  @override
  shelf.Middleware call() => (shelf.Handler innerHandler) =>
      (shelf.Request request) async {
        final path = request.requestedUri.path;

        // Skip authentication for excluded paths
        if (_shouldExcludePath(path)) {
          return await innerHandler(request);
        }

        // Extract token from Authorization header
        final authHeader = request.headers['authorization'];
        if (authHeader == null) {
          return _unauthorizedResponse('Missing authorization header');
        }

        String? token;
        if (authHeader.startsWith('Bearer ')) {
          token = authHeader.substring(7);
        } else if (authHeader.startsWith('Basic ')) {
          // Handle basic auth
          return _handleBasicAuth(authHeader, innerHandler, request);
        } else {
          return _unauthorizedResponse('Invalid authorization header format');
        }

        // Validate token (token is already checked to be non-null above)
        if (token.isEmpty) {
          return _unauthorizedResponse('Empty token provided');
        }

        try {
          final isValid = await _validateToken(token);
          if (!isValid) {
            return _unauthorizedResponse('Invalid token');
          }

          // Add user info to request context if needed
          final updatedRequest = request.change(context: {
            ...request.context,
            'auth_token': token,
            'authenticated': true,
          });

          return await innerHandler(updatedRequest);
        } on Exception catch (e) {
          return _unauthorizedResponse('Token validation failed: $e');
        }
      };

  bool _shouldExcludePath(String path) => excludePaths.any((excludePath) {
        if (excludePath.endsWith('*')) {
          final prefix = excludePath.substring(0, excludePath.length - 1);
          return path.startsWith(prefix);
        }
        return path == excludePath;
      });

  Future<bool> _validateToken(String token) async {
    // Use custom validator if provided
    if (customValidator != null) {
      try {
        await customValidator!(token);
        return true;
      } on Exception catch (e) {
        print('Custom token validation failed: $e');
        return false;
      }
    }

    // Simple JWT validation (in production, use a proper JWT library)
    if (jwtSecret != null) {
      return _validateJWT(token);
    }

    // If no validation method is configured, reject
    return false;
  }

  bool _validateJWT(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw ArgumentError('Invalid JWT format: expected 3 parts');
      }

      final header = parts.elementAtOrNull(0);
      final payload = parts.elementAtOrNull(1);
      final signature = parts.elementAtOrNull(2);

      if (header == null || payload == null || signature == null) {
        throw ArgumentError('Invalid JWT format: missing parts');
      }

      // Decode and validate header
      final headerJson =
          jsonDecode(_base64UrlDecode(header)) as Map<String, dynamic>;
      final alg = headerJson['alg'] as String?;
      if (alg == null || alg != 'HS256') {
        throw ArgumentError('Unsupported algorithm: ${alg ?? 'null'}');
      }

      // Decode payload
      final payloadJson =
          jsonDecode(_base64UrlDecode(payload)) as Map<String, dynamic>;

      // Check required fields
      if (!payloadJson.containsKey('iss') || !payloadJson.containsKey('sub')) {
        throw ArgumentError('Missing required JWT claims (iss, sub)');
      }

      // Check expiration
      final exp = payloadJson['exp'] as int?;
      if (exp != null) {
        final expiration = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (DateTime.now().isAfter(expiration)) {
          throw ArgumentError('Token expired');
        }
      }

      // Check not before time
      final nbf = payloadJson['nbf'] as int?;
      if (nbf != null) {
        final notBefore = DateTime.fromMillisecondsSinceEpoch(nbf * 1000);
        if (DateTime.now().isBefore(notBefore)) {
          throw ArgumentError('Token not yet valid');
        }
      }

      // Verify signature if secret is provided
      if (jwtSecret != null) {
        final expectedSignature =
            _generateSignature('$header.$payload', jwtSecret!);
        if (signature != expectedSignature) {
          throw ArgumentError('Invalid token signature');
        }
      }

      return true;
    } on Exception catch (e) {
      print('JWT validation failed: $e');
      return false;
    }
  }

  String _generateSignature(String data, String secret) {
    // В production следует использовать криптографическую библиотеку
    // Здесь упрощенная реализация для демонстрации
    final bytes = utf8.encode(data + secret);
    final hash = bytes.fold<int>(0, (prev, byte) => prev ^ byte);
    return base64UrlEncode(utf8.encode(hash.toString()));
  }

  Future<shelf.Response> _handleBasicAuth(
    String authHeader,
    shelf.Handler innerHandler,
    shelf.Request request,
  ) async {
    try {
      final credentials = authHeader.substring(6);
      final decoded = utf8.decode(base64Decode(credentials));
      final parts = decoded.split(':');

      if (parts.length != 2) {
        return _unauthorizedResponse('Invalid basic auth format');
      }

      final username = parts.elementAtOrNull(0);
      final password = parts.elementAtOrNull(1);

      if (username == null || password == null) {
        return _unauthorizedResponse('Invalid basic auth format');
      }
      // Here you would validate username/password against your user store
      // This is just a placeholder
      if (_validateBasicAuth(username, password)) {
        final updatedRequest = request.change(context: {
          ...request.context,
          'auth_username': username,
          'authenticated': true,
        });

        return await innerHandler(updatedRequest);
      }
      return _unauthorizedResponse('Invalid credentials');
    } on Exception catch (e) {
      return _unauthorizedResponse('Basic auth validation failed: $e');
    }
  }

  bool _validateBasicAuth(String username, String password) =>
      username.isNotEmpty && password.isNotEmpty;

  String _base64UrlDecode(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string');
    }
    return utf8.decode(base64Decode(output));
  }

  shelf.Response _unauthorizedResponse(String message) =>
      shelf.Response.unauthorized(
        jsonEncode({'error': 'Unauthorized', 'message': message}),
        headers: {'content-type': 'application/json'},
      );
}

/// Convenience function to create authentication middleware
shelf.Middleware auth({
  String? jwtSecret,
  List<String> excludePaths = const [],
  Function(String token)? customValidator,
}) =>
    AuthMiddleware(
      jwtSecret: jwtSecret,
      excludePaths: excludePaths,
      customValidator: customValidator,
    ).call();
