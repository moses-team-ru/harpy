// ignore_for_file: parameter_assignments, avoid_catching_errors

import 'package:harpy/harpy.dart';
import 'package:shelf/shelf.dart' as shelf;

/// Router class for handling HTTP routes
///
/// Provides RESTful routing with parameter support and middleware integration.
class Router {
  final List<Route> _routes = <Route>[];
  final List<shelf.Middleware> _middlewares = <shelf.Middleware>[];

  /// Add middleware to the router
  void use(shelf.Middleware middleware) {
    _middlewares.add(middleware);
  }

  /// Add a GET route
  void get(String pattern, Handler handler) {
    _addRoute('GET', pattern, handler);
  }

  /// Add a POST route
  void post(String pattern, Handler handler) {
    _addRoute('POST', pattern, handler);
  }

  /// Add a PUT route
  void put(String pattern, Handler handler) {
    _addRoute('PUT', pattern, handler);
  }

  /// Add a DELETE route
  void delete(String pattern, Handler handler) {
    _addRoute('DELETE', pattern, handler);
  }

  /// Add a PATCH route
  void patch(String pattern, Handler handler) {
    _addRoute('PATCH', pattern, handler);
  }

  /// Add a HEAD route
  void head(String pattern, Handler handler) {
    _addRoute('HEAD', pattern, handler);
  }

  /// Add a OPTIONS route
  void options(String pattern, Handler handler) {
    _addRoute('OPTIONS', pattern, handler);
  }

  /// Add a route for any HTTP method
  void any(String pattern, Handler handler) {
    const List<String> methods = <String>[
      'GET',
      'POST',
      'PUT',
      'DELETE',
      'PATCH',
      'HEAD',
      'OPTIONS',
    ];
    for (final String method in methods) {
      _addRoute(method, pattern, handler);
    }
  }

  /// Add a route for multiple HTTP methods
  void match(List<String> methods, String pattern, Handler handler) {
    for (final String method in methods) {
      _addRoute(method, pattern, handler);
    }
  }

  /// Add a sub-router with a prefix
  void mount(String prefix, Router subrouter) {
    for (final Route route in subrouter._routes) {
      final String newPattern = _combinePaths(prefix, route.pattern);
      _routes.add(Route.fromPattern(route.method, newPattern, route.handler));
    }
  }

  /// Add a route with custom method
  void _addRoute(String method, String pattern, Handler handler) {
    final Route route = Route.fromPattern(method, pattern, handler);
    _routes.add(route);
  }

  /// Convert router to Shelf handler
  shelf.Handler toHandler() => (shelf.Request request) async {
        final String method = request.method;
        final String path = request.url.path;

        // Find matching route
        for (final Route route in _routes) {
          if (route.matches(method, path)) {
            // Extract route parameters
            final Map<String, String> params = route.extractParams(path);

            // Create Harpy request and add parameters
            final Request req = Request(request);
            for (final MapEntry<String, String> entry in params.entries) {
              req.addParam(entry.key, entry.value);
            }

            // Create response
            final Response res = Response();

            try {
              final result = await route.handler(req, res);

              // Handle different return types
              if (result is shelf.Response) {
                return result;
              } else if (result != null) {
                return res.json(result);
              }
              return res.empty();
            } on FormatException catch (error) {
              print('Format error in route handler: $error');
              return res.badRequest(<String, String>{
                'error': 'Bad Request',
                'message': error.message,
              });
            } on ArgumentError catch (error) {
              print('Argument error in route handler: $error');
              return res.badRequest(<String, dynamic>{
                'error': 'Bad Request',
                'message': error.message,
              });
            } on Exception catch (error, stackTrace) {
              print('Error in route handler: $error');
              print('Stack trace: $stackTrace');

              return res.internalServerError(<String, String>{
                'error': 'Internal server error',
                'message': 'An unexpected error occurred',
                'type': error.runtimeType.toString(),
              });
            }
          }
        }

        // No route found
        return shelf.Response.notFound('Route not found: $method $path');
      };

  /// Get all registered routes
  List<Route> get routes => List.unmodifiable(_routes);

  /// Get all registered middlewares
  List<shelf.Middleware> get middlewares => List.unmodifiable(_middlewares);

  /// Combine two path segments
  String _combinePaths(String prefix, String suffix) {
    // Remove trailing slash from prefix
    if (prefix.endsWith('/') && prefix.length > 1) {
      prefix = prefix.substring(0, prefix.length - 1);
    }

    // Remove leading slash from suffix
    if (suffix.startsWith('/')) {
      suffix = suffix.substring(1);
    }

    // Handle root path
    if (prefix.isEmpty || prefix == '/') {
      return '/$suffix';
    }

    if (suffix.isEmpty) {
      return prefix;
    }

    return '$prefix/$suffix';
  }

  /// Print all registered routes (for debugging)
  void printRoutes() {
    print('Registered routes:');
    for (final Route route in _routes) {
      print('  ${route.method.padRight(7)} ${route.pattern}');
    }
  }
}
