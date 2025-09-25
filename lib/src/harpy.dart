import 'dart:io';

import 'package:harpy/src/config/configuration.dart';
import 'package:harpy/src/middleware/auth_middleware.dart';
import 'package:harpy/src/middleware/cors_middleware.dart';
import 'package:harpy/src/middleware/logging_middleware.dart';
import 'package:harpy/src/middleware/middleware.dart';
import 'package:harpy/src/routing/router.dart';
import 'package:harpy/src/server/harpy_server.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Main Harpy application class
///
/// This is the primary entry point for creating Harpy web applications.
/// It provides a fluent API for routing, middleware, and server configuration.
class Harpy {
  final Router _router = Router();
  final List<shelf.Middleware> _globalMiddlewares = [];
  final Configuration _config;

  HarpyServer? _server;

  /// Create a new Harpy application
  Harpy({Configuration? config})
      : _config = config ?? Configuration.fromEnvironment();

  /// Add global middleware to the application
  void use(shelf.Middleware middleware) {
    _globalMiddlewares.add(middleware);
  }

  /// Add CORS middleware with default settings
  void enableCors({
    String? origin,
    List<String>? allowedMethods,
    List<String>? allowedHeaders,
    bool credentials = false,
    int maxAge = 86400,
  }) {
    use(cors(
      origin: origin,
      allowedMethods: allowedMethods,
      allowedHeaders: allowedHeaders,
      credentials: credentials,
      maxAge: maxAge,
    ));
  }

  /// Add logging middleware
  void enableLogging({
    bool logBody = false,
    bool logHeaders = false,
    Function(String)? logger,
  }) {
    use(logging(
      logBody: logBody,
      logHeaders: logHeaders,
      logger: logger,
    ));
  }

  /// Add authentication middleware
  void enableAuth({
    String? jwtSecret,
    List<String> excludePaths = const [],
    Function(String token)? customValidator,
  }) {
    use(auth(
      jwtSecret: jwtSecret,
      excludePaths: excludePaths,
      customValidator: customValidator,
    ));
  }

  // Route methods

  /// Add a GET route
  void get(String pattern, Handler handler) {
    _router.get(pattern, handler);
  }

  /// Add a POST route
  void post(String pattern, Handler handler) {
    _router.post(pattern, handler);
  }

  /// Add a PUT route
  void put(String pattern, Handler handler) {
    _router.put(pattern, handler);
  }

  /// Add a DELETE route
  void delete(String pattern, Handler handler) {
    _router.delete(pattern, handler);
  }

  /// Add a PATCH route
  void patch(String pattern, Handler handler) {
    _router.patch(pattern, handler);
  }

  /// Add a HEAD route
  void head(String pattern, Handler handler) {
    _router.head(pattern, handler);
  }

  /// Add a OPTIONS route
  void options(String pattern, Handler handler) {
    _router.options(pattern, handler);
  }

  /// Add a route for any HTTP method
  void any(String pattern, Handler handler) {
    _router.any(pattern, handler);
  }

  /// Add a route for multiple HTTP methods
  void match(List<String> methods, String pattern, Handler handler) {
    _router.match(methods, pattern, handler);
  }

  /// Mount a sub-router with prefix
  void mount(String prefix, Router subrouter) {
    _router.mount(prefix, subrouter);
  }

  /// Create the Shelf pipeline with all middlewares
  shelf.Handler _createPipeline() {
    shelf.Handler handler = _router.toHandler();

    // Apply global middlewares in reverse order (last added applies first)
    for (final middleware in _globalMiddlewares.reversed) {
      handler = middleware(handler);
    }

    return handler;
  }

  /// Start the HTTP server
  Future<void> listen({
    String? host,
    int? port,
    SecurityContext? securityContext,
    bool shared = false,
  }) async {
    final String serverHost =
        host ?? _config.get<String>('host')?.toString() ?? 'localhost';
    final int serverPort =
        port ?? int.tryParse(_config.get<String>('port').toString()) ?? 8080;

    _server = HarpyServer(
      host: serverHost,
      port: serverPort,
      securityContext: securityContext,
      shared: shared,
    );

    final pipeline = _createPipeline();
    await _server!.listen(pipeline);
  }

  /// Start the server using shelf_io.serve directly (for compatibility)
  Future<HttpServer> serve({
    String? host,
    int? port,
    SecurityContext? securityContext,
    bool shared = false,
  }) async {
    final String serverHost =
        host ?? _config.get<String>('host')?.toString() ?? 'localhost';
    final int serverPort =
        port ?? int.tryParse(_config.get<String>('port').toString()) ?? 8080;

    final pipeline = _createPipeline();

    final server = await shelf_io.serve(
      pipeline,
      serverHost,
      serverPort,
      securityContext: securityContext,
      shared: shared,
    );

    final protocol = securityContext != null ? 'https' : 'http';
    print('🚀 Harpy server listening on $protocol://$serverHost:$serverPort');

    return server;
  }

  /// Stop the server
  Future<void> close({bool force = false}) async {
    if (_server != null) {
      await _server!.close(force: force);
      _server = null;
    }
  }

  /// Get application configuration
  Configuration get config => _config;

  /// Get the router instance
  Router get router => _router;

  /// Check if server is running
  bool get isRunning => _server?.isRunning ?? false;

  /// Print all registered routes (for debugging)
  void printRoutes() {
    _router.printRoutes();
  }
}
