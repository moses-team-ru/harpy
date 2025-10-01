// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:harpy/harpy.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('Router Edge Cases Tests', () {
    late Harpy app;
    HttpServer? server;
    const int testPort = 8767;

    setUp(() {
      app = Harpy();
    });

    tearDown(() async {
      if (server != null) {
        await server!.close(force: true);
      }
      await app.close();
    });

    test('should handle URL encoded path parameters', () async {
      app.get(
        '/users/:name',
        (Request req, Response res) =>
            res.json(<String, String?>{'name': req.params['name']}),
      );

      server = await app.serve(port: testPort);

      // Test with URL-encoded space
      final http.Response response1 = await http.get(
        Uri.parse('http://localhost:$testPort/users/John%20Doe'),
      );
      expect(response1.statusCode, equals(200));
      final body1 = jsonDecode(response1.body);
      expect(body1['name'], equals('John Doe'));

      // Test with URL-encoded special characters
      final http.Response response2 = await http.get(
        Uri.parse('http://localhost:$testPort/users/user%40example.com'),
      );
      expect(response2.statusCode, equals(200));
      final body2 = jsonDecode(response2.body);
      expect(body2['name'], equals('user@example.com'));
    });

    test('should handle paths with trailing slash normalization', () async {
      app.get(
        '/api/users',
        (Request req, Response res) =>
            res.json(<String, String>{'endpoint': 'users'}),
      );

      server = await app.serve(port: testPort);

      // Without trailing slash
      final http.Response response1 = await http.get(
        Uri.parse('http://localhost:$testPort/api/users'),
      );
      expect(response1.statusCode, equals(200));

      // With trailing slash - should also work due to normalization
      final http.Response response2 = await http.get(
        Uri.parse('http://localhost:$testPort/api/users/'),
      );
      expect(response2.statusCode, equals(200));
    });

    test('should handle root path correctly', () async {
      app.get(
        '/',
        (Request req, Response res) =>
            res.json(<String, String>{'path': 'root'}),
      );

      server = await app.serve(port: testPort);

      final http.Response response =
          await http.get(Uri.parse('http://localhost:$testPort/'));
      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['path'], equals('root'));
    });

    test('should handle nested route parameters', () async {
      app.get(
        '/api/v1/users/:userId/posts/:postId/comments/:commentId',
        (Request req, Response res) => res.json(<String, String?>{
          'userId': req.params['userId'],
          'postId': req.params['postId'],
          'commentId': req.params['commentId'],
        }),
      );

      server = await app.serve(port: testPort);

      final http.Response response = await http.get(
        Uri.parse(
          'http://localhost:$testPort/api/v1/users/1/posts/2/comments/3',
        ),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['userId'], equals('1'));
      expect(body['postId'], equals('2'));
      expect(body['commentId'], equals('3'));
    });

    test('should differentiate between similar routes', () async {
      app
        ..get(
          '/users',
          (Request req, Response res) =>
              res.json(<String, String>{'endpoint': 'list'}),
        )
        ..get(
          '/users/new',
          (Request req, Response res) =>
              res.json(<String, String>{'endpoint': 'new'}),
        )
        ..get(
          '/users/:id',
          (Request req, Response res) => res.json(
            <String, String?>{'endpoint': 'show', 'id': req.params['id']},
          ),
        );

      server = await app.serve(port: testPort);

      final http.Response response1 = await http.get(
        Uri.parse('http://localhost:$testPort/users'),
      );
      expect(jsonDecode(response1.body)['endpoint'], equals('list'));

      final http.Response response2 = await http.get(
        Uri.parse('http://localhost:$testPort/users/new'),
      );
      expect(jsonDecode(response2.body)['endpoint'], equals('new'));

      final http.Response response3 = await http.get(
        Uri.parse('http://localhost:$testPort/users/123'),
      );
      expect(jsonDecode(response3.body)['endpoint'], equals('show'));
      expect(jsonDecode(response3.body)['id'], equals('123'));
    });

    test('should handle empty path segments correctly', () async {
      app.get(
        '/api/test',
        (Request req, Response res) => res.json(<String, bool>{'ok': true}),
      );

      server = await app.serve(port: testPort);

      // Normal request
      final http.Response response1 = await http.get(
        Uri.parse('http://localhost:$testPort/api/test'),
      );
      expect(response1.statusCode, equals(200));

      // Request with double slashes should NOT match
      final http.Response response2 = await http.get(
        Uri.parse('http://localhost:$testPort/api//test'),
      );
      expect(response2.statusCode, equals(404));
    });

    test('should handle numeric route parameters', () async {
      app.get('/api/items/:id', (Request req, Response res) {
        final int? id = int.tryParse(req.params['id'] ?? '');
        if (id == null) {
          return res.badRequest(<String, String>{'error': 'Invalid ID'});
        }
        return res.json(<String, Object>{'id': id, 'type': 'number'});
      });

      server = await app.serve(port: testPort);

      final http.Response response = await http.get(
        Uri.parse('http://localhost:$testPort/api/items/42'),
      );
      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['id'], equals(42));
    });

    test('should handle case-sensitive routes', () async {
      app
        ..get(
          '/api/Test',
          (Request req, Response res) =>
              res.json(<String, String>{'path': 'Test'}),
        )
        ..get(
          '/api/test',
          (Request req, Response res) =>
              res.json(<String, String>{'path': 'test'}),
        );

      server = await app.serve(port: testPort);

      final http.Response response1 = await http.get(
        Uri.parse('http://localhost:$testPort/api/Test'),
      );
      expect(jsonDecode(response1.body)['path'], equals('Test'));

      final http.Response response2 = await http.get(
        Uri.parse('http://localhost:$testPort/api/test'),
      );
      expect(jsonDecode(response2.body)['path'], equals('test'));
    });

    test('should handle routes with dots in path', () async {
      app.get(
        '/files/:filename',
        (Request req, Response res) =>
            res.json(<String, String?>{'filename': req.params['filename']}),
      );

      server = await app.serve(port: testPort);

      final http.Response response = await http.get(
        Uri.parse('http://localhost:$testPort/files/document.pdf'),
      );
      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['filename'], equals('document.pdf'));
    });

    test('should handle routes with hyphens and underscores', () async {
      app
        ..get(
          '/api/some-route',
          (Request req, Response res) =>
              res.json(<String, String>{'type': 'hyphen'}),
        )
        ..get(
          '/api/some_route',
          (Request req, Response res) =>
              res.json(<String, String>{'type': 'underscore'}),
        );

      server = await app.serve(port: testPort);

      final http.Response response1 = await http.get(
        Uri.parse('http://localhost:$testPort/api/some-route'),
      );
      expect(jsonDecode(response1.body)['type'], equals('hyphen'));

      final http.Response response2 = await http.get(
        Uri.parse('http://localhost:$testPort/api/some_route'),
      );
      expect(jsonDecode(response2.body)['type'], equals('underscore'));
    });

    test('should handle complex query strings', () async {
      app.get(
        '/search',
        (Request req, Response res) => res.json(<String, Object>{
          'query': req.query,
          'count': req.query.length,
        }),
      );

      server = await app.serve(port: testPort);

      final http.Response response = await http.get(
        Uri.parse(
          'http://localhost:$testPort/search?q=test&sort=asc&limit=10&offset=0',
        ),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['query']['q'], equals('test'));
      expect(body['query']['sort'], equals('asc'));
      expect(body['query']['limit'], equals('10'));
      expect(body['query']['offset'], equals('0'));
      expect(body['count'], equals(4));
    });

    test('should handle route priority (first match wins)', () async {
      app
        ..get(
          '/api/:resource',
          (Request req, Response res) => res.json(<String, String?>{
            'match': 'param',
            'resource': req.params['resource'],
          }),
        )
        ..get(
          '/api/users',
          (Request req, Response res) =>
              res.json(<String, String>{'match': 'exact'}),
        );

      server = await app.serve(port: testPort);

      // The first route (with parameter) should match since it's registered first
      final http.Response response = await http.get(
        Uri.parse('http://localhost:$testPort/api/users'),
      );
      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['match'], equals('param'));
      expect(body['resource'], equals('users'));
    });

    test('should handle POST with different content types', () async {
      app.post('/data', (Request req, Response res) async {
        if (req.isJson) {
          final Map<String, dynamic> data = await req.json();
          return res.json(<String, Object>{'received': data, 'type': 'json'});
        }
        final String text = await req.text();
        return res.json(<String, String>{'received': text, 'type': 'text'});
      });

      server = await app.serve(port: testPort);

      // JSON content
      final http.Response response1 = await http.post(
        Uri.parse('http://localhost:$testPort/data'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{'key': 'value'}),
      );
      expect(response1.statusCode, equals(200));
      final body1 = jsonDecode(response1.body);
      expect(body1['type'], equals('json'));

      // Plain text content
      final http.Response response2 = await http.post(
        Uri.parse('http://localhost:$testPort/data'),
        headers: <String, String>{'Content-Type': 'text/plain'},
        body: 'Hello World',
      );
      expect(response2.statusCode, equals(200));
      final body2 = jsonDecode(response2.body);
      expect(body2['type'], equals('text'));
    });

    test('should handle route with same path but different methods', () async {
      int getCount = 0;
      int postCount = 0;

      app
        ..get('/counter', (Request req, Response res) {
          getCount++;
          return res.json(<String, Object>{'method': 'GET', 'count': getCount});
        })
        ..post('/counter', (Request req, Response res) {
          postCount++;
          return res
              .json(<String, Object>{'method': 'POST', 'count': postCount});
        });

      server = await app.serve(port: testPort);

      await http.get(Uri.parse('http://localhost:$testPort/counter'));
      await http.get(Uri.parse('http://localhost:$testPort/counter'));
      final http.Response getResp = await http.get(
        Uri.parse('http://localhost:$testPort/counter'),
      );
      expect(jsonDecode(getResp.body)['count'], equals(3));

      await http.post(Uri.parse('http://localhost:$testPort/counter'));
      final http.Response postResp = await http.post(
        Uri.parse('http://localhost:$testPort/counter'),
      );
      expect(jsonDecode(postResp.body)['count'], equals(2));
    });

    test('should handle very long paths', () async {
      const String longPath =
          '/api/v1/users/123/projects/456/tasks/789/comments/012/'
          'attachments/345/metadata/678/settings/901';

      app.get(
        longPath,
        (Request req, Response res) =>
            res.json(<String, String>{'path': 'long'}),
      );

      server = await app.serve(port: testPort);

      final http.Response response = await http.get(
        Uri.parse('http://localhost:$testPort$longPath'),
      );
      expect(response.statusCode, equals(200));
      expect(jsonDecode(response.body)['path'], equals('long'));
    });

    test('should handle request headers correctly', () async {
      app.get(
        '/headers',
        (Request req, Response res) => res.json(<String, Object?>{
          'userAgent': req.userAgent,
          'hasAuth': req.headers.containsKey('authorization'),
          'customHeader': req.headers['x-custom-header'],
        }),
      );

      server = await app.serve(port: testPort);

      final http.Response response = await http.get(
        Uri.parse('http://localhost:$testPort/headers'),
        headers: <String, String>{
          'X-Custom-Header': 'test-value',
          'Authorization': 'Bearer token123',
        },
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['hasAuth'], isTrue);
      expect(body['customHeader'], equals('test-value'));
    });
  });
}
