import 'package:harpy/harpy.dart';

void main() async {
  // Create the Harpy application
  final app = Harpy()

    // Enable CORS for all origins (good for development)
    ..enableCors()

    // Enable request logging
    ..enableLogging(logBody: true)

    // Basic routes
    ..get(
      '/',
      (req, res) => res.json({
        'message': 'Welcome to Harpy Framework!',
        'version': '0.1.0',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    )
    ..get(
      '/health',
      (req, res) => res.json({
        'status': 'healthy',
        'uptime': DateTime.now().difference(DateTime.now()).inSeconds,
      }),
    )

    // Route with parameters
    ..get('/users/:id', (req, res) {
      final userId = req.params['id'] ?? 'unknown';
      return res.json({
        'userId': userId,
        'message': 'User profile for ID: $userId',
      });
    })

    // POST route with JSON body
    ..post('/users', (req, res) async {
      try {
        final body = await req.json();
        final user = {
          'id': DateTime.now().millisecondsSinceEpoch,
          'name': body['name'] ?? 'Unknown',
          'email': body['email'] ?? 'unknown@example.com',
          'created': DateTime.now().toIso8601String(),
        };

        return res.status(201).json({
          'message': 'User created successfully',
          'user': user,
        });
      } catch (e) {
        return res.badRequest({
          'error': 'Invalid JSON body',
          'message': e.toString(),
        });
      }
    })

    // Error handling example
    ..get('/error', (req, res) {
      throw Exception('This is a test error');
    })

    // Route with query parameters
    ..get('/search', (req, res) {
      final query = req.query['q'] ?? '';
      final limit = int.tryParse(req.query['limit'] ?? '10') ?? 10;

      return res.json({
        'query': query,
        'limit': limit,
        'results': [
          {'id': 1, 'title': 'Result 1 for "$query"'},
          {'id': 2, 'title': 'Result 2 for "$query"'},
        ],
      });
    })

    // Different HTTP methods for REST API
    ..put('/users/:id', (req, res) async {
      final userId = req.params['id'];
      final body = await req.json();

      return res.json({
        'message': 'User updated',
        'userId': userId,
        'updates': body,
      });
    })
    ..delete('/users/:id', (req, res) {
      final userId = req.params['id'];
      return res.json({
        'message': 'User deleted',
        'userId': userId,
      });
    });

  // Sub-router example
  final apiRouter = Router()
    ..get(
      '/status',
      (req, res) => res.json({'api': 'v1', 'status': 'active'}),
    )
    ..get(
      '/info',
      (req, res) => res.json({
        'version': '1.0.0',
        'endpoints': ['/api/v1/status', '/api/v1/info'],
      }),
    );

  // Mount the sub-router
  app.mount('/api/v1', apiRouter);

  // Print registered routes
  print(r'\n📋 Registered routes:');
  app.printRoutes();

  // Start the server
  await app.listen(port: 3000);
}
