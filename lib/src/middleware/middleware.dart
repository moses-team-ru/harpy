// ignore_for_file: avoid-dynamic

import 'package:harpy/harpy.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:talker/talker.dart';

/// Function signature for Harpy route handlers
typedef Handler = dynamic Function(Request req, Response res);

/// Function signature for Harpy middleware
typedef HarpyMiddleware = shelf.Middleware Function();

/// Base interface for middleware in Harpy framework
// ignore: one_member_abstracts
abstract class Middleware {
  /// Execute the middleware
  shelf.Middleware call();
}

/// Utility function to convert Harpy handler to Shelf handler
shelf.Handler harpyToShelfHandler(Handler handler) =>
    (shelf.Request request) async {
      final Request req = Request(request);
      final Response res = Response();

      try {
        final result = await handler(req, res);

        // If handler returns a shelf.Response directly, use it
        if (result is shelf.Response) {
          return result;
        }

        // If handler returns data, convert to JSON response
        if (result != null) {
          return res.json(result);
        }

        // Default empty response
        return res.empty();
      } on Exception catch (error, stackTrace) {
        /// Talker instance for logging
        Talker()
          ..error('Error in handler: $error')
          ..error('Stack trace: $stackTrace');

        return res.internalServerError({
          'error': 'Internal server error',
          'message': error.toString(),
        });
      }
    };
