import 'package:harpy/src/middleware/middleware.dart';

/// Represents a single route with its handler and metadata
class Route {
  /// Create a route
  /// [method] is the HTTP method (GET, POST, etc.)
  /// [pattern] is the route pattern (e.g., '/users/:id')
  /// [handler] is the function to handle requests to this route
  /// [paramNames] is the list of parameter names in the route
  /// [regex] is the compiled regex for matching the route
  const Route({
    required this.method,
    required this.pattern,
    required this.handler,
    this.paramNames = const <String>[],
    this.regex,
  });

  /// Create a route from a pattern like '/users/:id'
  factory Route.fromPattern(String method, String pattern, Handler handler) {
    final List<String> paramNames = <String>[];

    // Convert route pattern to regex
    String regexPattern = pattern;

    // Handle route parameters like :id
    final RegExp paramRegex = RegExp(':([a-zA-Z_][a-zA-Z0-9_]*)');
    final Iterable<RegExpMatch> matches = paramRegex.allMatches(pattern);

    for (final RegExpMatch match in matches) {
      final String paramName = match.group(1)!;
      paramNames.add(paramName);
      regexPattern = regexPattern.replaceFirst(':$paramName', '([^/]+)');
    }

    // Handle wildcard patterns
    regexPattern = regexPattern.replaceAll('*', '.*');

    // Ensure exact match
    if (!regexPattern.startsWith('^')) {
      regexPattern = '^$regexPattern';
    }
    if (!regexPattern.endsWith(r'$')) {
      regexPattern = '$regexPattern\$';
    }

    final RegExp regex = RegExp(regexPattern);

    return Route(
      method: method.toUpperCase(),
      pattern: pattern,
      handler: handler,
      paramNames: paramNames,
      regex: regex,
    );
  }

  /// HTTP method (GET, POST, etc.)
  final String method;

  /// Route pattern (e.g., '/users/:id')
  final String pattern;

  /// Handler function for this route
  final Handler handler;

  /// Names of parameters in the route (e.g., ['id'] for '/users/:id')
  final List<String> paramNames;

  /// Compiled regex for matching the route
  final RegExp? regex;

  /// Check if this route matches the given method and path
  bool matches(String checkMethod, String path) {
    if (method != checkMethod.toUpperCase()) {
      return false;
    }

    return regex?.hasMatch(path) ?? false;
  }

  /// Extract parameters from the path if this route matches
  Map<String, String> extractParams(String path) {
    if (regex == null) return <String, String>{};

    final RegExpMatch? match = regex!.firstMatch(path);
    if (match == null) return <String, String>{};

    final Map<String, String> params = <String, String>{};
    for (int i = 0; i < paramNames.length; i++) {
      final String? paramValue = match.group(i + 1);
      if (paramValue != null) {
        params[paramNames[i]] = Uri.decodeComponent(paramValue);
      }
    }

    return params;
  }

  @override
  String toString() => 'Route($method $pattern)';
}
