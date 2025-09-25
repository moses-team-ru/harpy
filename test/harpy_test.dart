// ignore_for_file: avoid-dynamic

import 'package:harpy/harpy.dart';
import 'package:test/test.dart';

void main() {
  group('Harpy Framework Tests', () {
    late Harpy app;

    setUp(() {
      app = Harpy();
    });

    test('should create Harpy app instance', () {
      expect(app, isA<Harpy>());
      expect(app.isRunning, isFalse);
    });

    test('should register GET route', () {
      app.get(
        '/test',
        (Request req, Response res) =>
            res.json(<String, String>{'message': 'test'}),
      );

      final List<Route> routes = app.router.routes;
      expect(routes.length, equals(1));
      expect(routes.isNotEmpty, isTrue);
      expect(routes.firstOrNull?.method, equals('GET'));
      expect(routes.firstOrNull?.pattern, equals('/test'));
    });

    test('should register multiple routes', () {
      app
        ..get(
          '/get',
          (Request req, Response res) =>
              res.json(<String, String>{'method': 'GET'}),
        )
        ..post(
          '/post',
          (Request req, Response res) =>
              res.json(<String, String>{'method': 'POST'}),
        )
        ..put(
          '/put',
          (Request req, Response res) =>
              res.json(<String, String>{'method': 'PUT'}),
        )
        ..delete(
          '/delete',
          (Request req, Response res) =>
              res.json(<String, String>{'method': 'DELETE'}),
        );

      final List<Route> routes = app.router.routes;
      expect(routes.length, equals(4));

      final List<String> methods = routes.map((Route r) => r.method).toList();
      expect(methods, containsAll(<dynamic>['GET', 'POST', 'PUT', 'DELETE']));
    });

    test('should handle route with parameters', () {
      app.get(
        '/users/:id',
        (Request req, Response res) =>
            res.json(<String, String?>{'userId': req.params['id']}),
      );

      final List<Route> routes = app.router.routes;
      expect(routes.length, equals(1));

      final Route? route = routes.firstOrNull;
      expect(route?.paramNames, contains('id'));
      expect(route?.matches('GET', '/users/123'), isTrue);
      expect(route?.matches('GET', '/users'), isFalse);

      final Map<String, String> params =
          route?.extractParams('/users/123') ?? {};
      expect(params['id'], equals('123'));
    });
  });

  group('Configuration Tests', () {
    test('should create configuration from map', () {
      final Configuration config = Configuration.fromMap(<String, Object?>{
        'port': 8080,
        'host': 'localhost',
        'database': <String, String>{'url': 'postgresql://localhost:5432/test'},
      });

      expect(config.get<int>('port'), equals(8080));
      expect(config.get<String>('host'), equals('localhost'));
      expect(
        config.get<String>('database.url'),
        equals('postgresql://localhost:5432/test'),
      );
    });

    test('should handle missing configuration keys', () {
      final Configuration config = Configuration.fromMap(<String, Object?>{});

      expect(config.get<String>('missing'), isNull);
      expect(config.get<String>('missing', 'default'), equals('default'));
      expect(
        () => config.getRequired<String>('missing'),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('should convert types correctly', () {
      final Configuration config = Configuration.fromMap(<String, Object?>{
        'port': '8080',
        'enabled': 'true',
        'timeout': '30.5',
      });

      expect(config.get<int>('port'), equals(8080));
      expect(config.get<bool>('enabled'), isTrue);
      expect(config.get<double>('timeout'), equals(30.5));
    });
  });

  group('Router Tests', () {
    late Router router;

    setUp(() {
      router = Router();
    });

    test('should mount sub-router correctly', () {
      final Router subRouter = Router()
        ..get(
          '/status',
          (Request req, Response res) =>
              res.json(<String, String>{'status': 'ok'}),
        );

      router.mount('/api/v1', subRouter);

      final List<Route> routes = router.routes;
      expect(routes.length, equals(1));
      expect(routes.firstOrNull?.pattern, equals('/api/v1/status'));
    });

    test('should handle route matching correctly', () {
      router.get(
        '/users/:id/posts/:postId',
        (Request req, Response res) => res.json(<dynamic, dynamic>{}),
      );

      final Route? route = router.routes.firstOrNull;
      expect(route?.matches('GET', '/users/123/posts/456'), isTrue);
      expect(route?.matches('POST', '/users/123/posts/456'), isFalse);
      expect(route?.matches('GET', '/users/123'), isFalse);

      final Map<String, String> params =
          route?.extractParams('/users/123/posts/456') ?? {};
      expect(params['id'], equals('123'));
      expect(params['postId'], equals('456'));
    });
  });
}
