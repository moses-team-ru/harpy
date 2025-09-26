import 'package:harpy/src/database/database.dart';
import 'package:harpy/src/middleware/middleware.dart';
import 'package:shelf/shelf.dart' as shelf;

/// Database middleware for Harpy framework
///
/// Provides database connection management and dependency injection
class DatabaseMiddleware implements Middleware {
  /// Create database middleware
  /// [database] is the database instance to inject into requests.
  /// [contextKey] is the key used to store the database in the request context.
  const DatabaseMiddleware({
    required this.database,
    this.contextKey = 'database',
  });

  /// Database instance to inject
  final Database database;

  /// Context key for storing database in request context
  final String contextKey;

  @override
  shelf.Middleware call() =>
      (shelf.Handler innerHandler) => (shelf.Request request) async {
            // Add database to request context
            final updatedRequest = request.change(context: {
              ...request.context,
              contextKey: database,
            });

            return await innerHandler(updatedRequest);
          };
}

/// Extension to easily access database from request
extension DatabaseRequest on shelf.Request {
  /// Get database from request context
  Database? get database => context['database'] as Database?;

  /// Get database or throw exception
  Database get db {
    final database = this.database;
    if (database == null) {
      throw StateError(
        'Database not available in request context. Make sure DatabaseMiddleware is configured.',
      );
    }
    return database;
  }
}

/// Convenience function to create database middleware
shelf.Middleware database(Database db, {String contextKey = 'database'}) =>
    DatabaseMiddleware(database: db, contextKey: contextKey).call();
