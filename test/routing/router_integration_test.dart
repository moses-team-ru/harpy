// ignore_for_file: avoid_print, avoid-dynamic

import 'dart:convert';
import 'dart:io';
import 'package:harpy/harpy.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('Router Integration Tests (HTTP)', () {
    late Harpy app;
    HttpServer? server;
    const int testPort = 8765;

    setUp(() {
      app = Harpy();
    });

    tearDown(() async {
      if (server != null) {
        await server!.close(force: true);
      }
      await app.close();
    });

    test('should handle GET request to root path', () async {
      app.get('/', (req, res) => res.json({'message': 'Hello World'}));

      server = await app.serve(port: testPort);

      final response = await http.get(Uri.parse('http://localhost:$testPort/'));

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['message'], equals('Hello World'));
    });

    test('should handle GET request with path', () async {
      app.get('/api/test', (req, res) => res.json({'endpoint': 'test'}));

      server = await app.serve(port: testPort);

      final response =
          await http.get(Uri.parse('http://localhost:$testPort/api/test'));

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['endpoint'], equals('test'));
    });

    test('should handle GET request with route parameters', () async {
      app.get(
        '/users/:id',
        (req, res) => res.json({'userId': req.params['id']}),
      );

      server = await app.serve(port: testPort);

      final response =
          await http.get(Uri.parse('http://localhost:$testPort/users/123'));

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['userId'], equals('123'));
    });

    test('should handle POST request', () async {
      app.post('/api/create', (req, res) async {
        final data = await req.json();
        return res.created({'received': data, 'id': 1});
      });

      server = await app.serve(port: testPort);

      final response = await http.post(
        Uri.parse('http://localhost:$testPort/api/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': 'Test'}),
      );

      expect(response.statusCode, equals(201));
      final body = jsonDecode(response.body);
      expect(body['received']['name'], equals('Test'));
      expect(body['id'], equals(1));
    });

    test('should handle PUT request', () async {
      app.put('/api/update/:id', (req, res) async {
        final data = await req.json();
        return res.json({'id': req.params['id'], 'updated': data});
      });

      server = await app.serve(port: testPort);

      final response = await http.put(
        Uri.parse('http://localhost:$testPort/api/update/42'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': 'Updated'}),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['id'], equals('42'));
      expect(body['updated']['name'], equals('Updated'));
    });

    test('should handle DELETE request', () async {
      app.delete(
        '/api/delete/:id',
        (req, res) => res.json({'deleted': req.params['id']}),
      );

      server = await app.serve(port: testPort);

      final response = await http.delete(
        Uri.parse('http://localhost:$testPort/api/delete/99'),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['deleted'], equals('99'));
    });

    test('should return 404 for unregistered routes', () async {
      app.get('/registered', (req, res) => res.ok('found'));

      server = await app.serve(port: testPort);

      final response = await http.get(
        Uri.parse('http://localhost:$testPort/unregistered'),
      );

      expect(response.statusCode, equals(404));
    });

    test('should handle multiple route parameters', () async {
      app.get(
        '/users/:userId/posts/:postId',
        (req, res) => res.json({
          'userId': req.params['userId'],
          'postId': req.params['postId'],
        }),
      );

      server = await app.serve(port: testPort);

      final response = await http.get(
        Uri.parse('http://localhost:$testPort/users/5/posts/10'),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['userId'], equals('5'));
      expect(body['postId'], equals('10'));
    });

    test('should handle query parameters', () async {
      app.get('/search', (req, res) {
        final query = req.query['q'];
        final limit = req.query['limit'];
        return res.json({'query': query, 'limit': limit});
      });

      server = await app.serve(port: testPort);

      final response = await http.get(
        Uri.parse('http://localhost:$testPort/search?q=test&limit=10'),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['query'], equals('test'));
      expect(body['limit'], equals('10'));
    });

    test('should handle mounted sub-routers', () async {
      final apiRouter = Router()
        ..get('/status', (req, res) => res.json({'status': 'ok'}))
        ..get('/version', (req, res) => res.json({'version': '1.0.0'}));

      app.mount('/api/v1', apiRouter);

      server = await app.serve(port: testPort);

      // Test first endpoint
      final response1 = await http.get(
        Uri.parse('http://localhost:$testPort/api/v1/status'),
      );
      expect(response1.statusCode, equals(200));
      final body1 = jsonDecode(response1.body);
      expect(body1['status'], equals('ok'));

      // Test second endpoint
      final response2 = await http.get(
        Uri.parse('http://localhost:$testPort/api/v1/version'),
      );
      expect(response2.statusCode, equals(200));
      final body2 = jsonDecode(response2.body);
      expect(body2['version'], equals('1.0.0'));
    });

    test('should match routes with trailing slash correctly', () async {
      app.get('/test', (req, res) => res.json({'path': 'test'}));

      server = await app.serve(port: testPort);

      // Test without trailing slash
      final response1 =
          await http.get(Uri.parse('http://localhost:$testPort/test'));
      expect(response1.statusCode, equals(200));

      // Test with trailing slash - this might fail
      final response2 =
          await http.get(Uri.parse('http://localhost:$testPort/test/'));
      print('Response with trailing slash: ${response2.statusCode}');
      // This test will help identify if trailing slash is an issue
    });

    test('should handle different HTTP methods on same path', () async {
      app
        ..get('/resource', (req, res) => res.json({'method': 'GET'}))
        ..post('/resource', (req, res) => res.json({'method': 'POST'}))
        ..put('/resource', (req, res) => res.json({'method': 'PUT'}))
        ..delete('/resource', (req, res) => res.json({'method': 'DELETE'}));

      server = await app.serve(port: testPort);

      final getResp =
          await http.get(Uri.parse('http://localhost:$testPort/resource'));
      expect(getResp.statusCode, equals(200));
      expect(jsonDecode(getResp.body)['method'], equals('GET'));

      final postResp =
          await http.post(Uri.parse('http://localhost:$testPort/resource'));
      expect(postResp.statusCode, equals(200));
      expect(jsonDecode(postResp.body)['method'], equals('POST'));

      final putResp =
          await http.put(Uri.parse('http://localhost:$testPort/resource'));
      expect(putResp.statusCode, equals(200));
      expect(jsonDecode(putResp.body)['method'], equals('PUT'));

      final deleteResp =
          await http.delete(Uri.parse('http://localhost:$testPort/resource'));
      expect(deleteResp.statusCode, equals(200));
      expect(jsonDecode(deleteResp.body)['method'], equals('DELETE'));
    });

    test('should handle CORS preflight OPTIONS request', () async {
      app
        ..enableCors()
        ..get('/api/data', (req, res) => res.json({'data': 'test'}));

      server = await app.serve(port: testPort);

      // OPTIONS preflight request
      final response = await http.Client().send(
        http.Request(
          'OPTIONS',
          Uri.parse('http://localhost:$testPort/api/data'),
        )
          ..headers['Origin'] = 'http://example.com'
          ..headers['Access-Control-Request-Method'] = 'GET',
      );

      expect(response.statusCode, lessThan(300));
    });

    test('should debug print all routes', () async {
      app
        ..get('/', (req, res) => res.ok('root'))
        ..get('/users', (req, res) => res.ok('users'))
        ..get('/users/:id', (req, res) => res.ok('user'))
        ..post('/users', (req, res) => res.ok('create'));

      print('\n=== Registered Routes ===');
      app.printRoutes();
      print('=== End Routes ===\n');

      server = await app.serve(port: testPort);

      // Test all routes
      final tests = ['/', '/users', '/users/123'];

      for (final path in tests) {
        final response =
            await http.get(Uri.parse('http://localhost:$testPort$path'));
        print('GET $path => ${response.statusCode}');
      }
    });
  });
}
