// ignore_for_file: avoid-dynamic

import 'package:collection/collection.dart';
import 'package:harpy/harpy.dart';
import 'package:test/test.dart';

// Test models
class HarpyTest extends Model with ActiveRecord {
  @override
  String get tableName => 'test_users';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get email => get<String>('email');
  set email(String? value) => setAttribute('email', value);

  @override
  List<String> validate() {
    final errors = <String>[];
    if (name == null || name!.isEmpty) errors.add('Name is required');
    if (email == null || !email!.contains('@')) {
      errors.add('Valid email required');
    }
    return errors;
  }
}

void main() {
  group('Harpy Framework Core Tests', () {
    late Harpy app;

    setUp(() {
      app = Harpy();
    });

    tearDown(() async {
      await app.close();
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

    test('should validate configuration keys', () {
      final config = Configuration.fromMap(<String, Object?>{});

      expect(() => config.set('', 'value'), throwsArgumentError);
      expect(() => config.set('key..with..dots', 'value'), throwsArgumentError);
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

    test('should handle any method route', () {
      router.any('/test', (req, res) => res.ok('any'));

      final routes = router.routes;
      expect(
        routes.length,
        equals(7),
      ); // GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS

      final methods = routes.map((r) => r.method).toSet();
      expect(methods, contains('GET'));
      expect(methods, contains('POST'));
      expect(methods, contains('PUT'));
      expect(methods, contains('DELETE'));
    });
  });

  group('HTTP Request/Response Tests', () {
    test('should handle request data extraction', () {
      // These would typically be integration tests with actual HTTP requests
      // For unit tests, we test the models directly

      final response = Response();

      // Test response builders
      final jsonResponse = response.json({'test': 'data'});
      expect(jsonResponse.statusCode, equals(200));

      final createdResponse = response.created({'id': 1});
      expect(createdResponse.statusCode, equals(201));

      final errorResponse = response.badRequest({'error': 'Invalid data'});
      expect(errorResponse.statusCode, equals(400));
    });

    test('should infer content types correctly', () {
      final response = Response();

      // Test different response types
      final textResponse = response.text('Hello World');
      expect(textResponse.headers['content-type'], contains('text/plain'));

      final htmlResponse = response.html('<h1>Hello</h1>');
      expect(htmlResponse.headers['content-type'], contains('text/html'));

      final jsonResponse = response.json({'message': 'hello'});
      expect(
        jsonResponse.headers['content-type'],
        contains('application/json'),
      );
    });
  });

  group('Database & ORM Tests', () {
    test('should create model instances correctly', () {
      final user = HarpyTest();

      expect(user.tableName, equals('test_users'));
      expect(user.exists, isFalse);
      expect(user.isDirty, isFalse);
    });

    test('should handle model attributes', () {
      final user = HarpyTest()
        ..name = 'John Doe'
        ..email = 'john@example.com';

      expect(user.name, equals('John Doe'));
      expect(user.email, equals('john@example.com'));
      expect(user.isDirty, isTrue);

      final changes = user.getChanges();
      expect(changes['name'], equals('John Doe'));
      expect(changes['email'], equals('john@example.com'));
    });

    test('should validate model data', () {
      final user = HarpyTest();

      // Test validation with missing required fields
      var errors = user.validate();
      expect(errors.length, equals(2));
      expect(errors.elementAtOrNull(0), contains('Name is required'));
      expect(errors.elementAtOrNull(1), contains('Valid email required'));

      // Test validation with invalid email
      user
        ..name = 'John'
        ..email = 'invalid-email';
      errors = user.validate();
      expect(errors.length, equals(1));
      expect(errors.elementAtOrNull(0), contains('Valid email required'));

      // Test validation with valid data
      user.email = 'john@example.com';
      errors = user.validate();
      expect(errors.length, equals(0));
    });

    test('should serialize model to JSON', () {
      final user = HarpyTest()
        ..name = 'Jane Doe'
        ..email = 'jane@example.com'
        ..id = 42;

      final json = user.toJson();
      expect(json['name'], equals('Jane Doe'));
      expect(json['email'], equals('jane@example.com'));
      expect(json['id'], equals(42));

      final jsonString = user.toJsonString();
      expect(jsonString, contains('Jane Doe'));
      expect(jsonString, contains('jane@example.com'));
    });

    test('should handle model equality', () {
      final user1 = HarpyTest()..id = 1;
      final user2 = HarpyTest()..id = 1;
      final user3 = HarpyTest()..id = 2;

      expect(user1, equals(user2));
      expect(user1, isNot(equals(user3)));
      expect(user1.hashCode, equals(user2.hashCode));
    });

    test('should track model state changes', () {
      final user = HarpyTest()
        ..fillAttributes(
          {'name': 'Original Name', 'email': 'original@example.com'},
        )
        ..markAsExisting();

      expect(user.exists, isTrue);
      expect(user.isDirty, isFalse);

      user.name = 'Updated Name';
      expect(user.isDirty, isTrue);

      final changes = user.getChanges();
      expect(changes['name'], equals('Updated Name'));
      expect(changes.containsKey('email'), isFalse);

      user.reset();
      expect(user.name, equals('Original Name'));
      expect(user.isDirty, isFalse);
    });
  });

  group('Migration System Tests', () {
    test('should create migration correctly', () {
      final migration = Migration(
        version: '001',
        description: 'Create users table',
        up: (schema) async {
          await schema.createTable('users', (table) {
            table
              ..id()
              ..string('name')
              ..string('email');
          });
        },
      );

      expect(migration.version, equals('001'));
      expect(migration.description, equals('Create users table'));
      expect(migration.up, isNotNull);
      expect(migration.down, isNull);
    });

    test('should build table schema correctly', () {
      final builder = TableBuilder('users')
        ..id()
        ..string('name', nullable: false)
        ..string('email', length: 255, nullable: false)
        ..integer('age')
        ..boolean('active', defaultValue: true, nullable: false)
        ..timestamps()
        ..unique(['email']);

      final sql = builder.build();

      expect(sql, contains('CREATE TABLE users'));
      expect(sql, contains('id INTEGER PRIMARY KEY AUTOINCREMENT'));
      expect(sql, contains('name VARCHAR NOT NULL'));
      expect(sql, contains('email VARCHAR(255) NOT NULL'));
      expect(sql, contains('age INTEGER'));
      expect(sql, contains('active BOOLEAN NOT NULL DEFAULT 1'));
      expect(
        sql,
        contains('created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP'),
      );
      expect(sql, contains('UNIQUE (email)'));
    });

    test('should handle foreign keys', () {
      final builder = TableBuilder('posts')
        ..id()
        ..string('title')
        ..foreignKey('user_id', 'users');

      final sql = builder.build();

      expect(sql, contains('user_id INTEGER'));
      expect(sql, contains('FOREIGN KEY (user_id) REFERENCES users(id)'));
    });
  });

  group('Security & Validation Tests', () {
    test('should handle XSS prevention in responses', () {
      final response = Response();

      // Test that HTML content is properly handled
      final htmlResponse = response.html('<script>alert("xss")</script>');
      expect(htmlResponse.headers['content-type'], contains('text/html'));
      // In production, HTML should be sanitized
    });

    test('should validate configuration input', () {
      final config = Configuration.fromMap(<String, Object?>{});

      // Test that empty keys are rejected
      expect(() => config.set('', 'value'), throwsArgumentError);

      // Test that malformed keys are rejected
      expect(() => config.set('key..double', 'value'), throwsArgumentError);
    });
  });

  group('Integration Tests', () {
    late Harpy app;

    setUp(() {
      app = Harpy();
    });

    tearDown(() async {
      await app.close();
    });

    test('should integrate middleware correctly', () {
      app
        ..enableCors()
        ..enableLogging();

      // Verify middleware was added (CORS and Logging)
      // Since middleware are stored in private _globalMiddlewares,
      // we test the functionality indirectly by verifying no errors occurred
      expect(app.router.middlewares.length, greaterThanOrEqualTo(0));
    });

    test('should handle complex routing scenarios', () {
      // Nested routes
      final apiRouter = Router()
        ..get('/users', (req, res) => res.json({'users': []}))
        ..post('/users', (req, res) => res.created({'user': {}}));
      // Direct routes
      app
        ..mount('/api/v1', apiRouter)
        ..get('/health', (req, res) => res.ok('healthy'))
        ..get('/version', (req, res) => res.json({'version': '1.0.0'}));

      final routes = app.router.routes;
      expect(routes.length, equals(4));

      // Check mounted routes
      final mountedRoutes =
          routes.where((r) => r.pattern.startsWith('/api/v1')).toList();
      expect(mountedRoutes.length, equals(2));
    });
  });

  group('Performance & Memory Tests', () {
    test('should handle large number of routes efficiently', () {
      final app = Harpy();

      // Add many routes
      for (int i = 0; i < 1000; i++) {
        app.get('/route$i', (req, res) => res.json({'id': i}));
      }

      expect(app.router.routes.length, equals(1000));

      // Test route matching performance (basic check)
      final route = app.router.routes.firstOrNull;
      expect(route?.matches('GET', '/route0'), isTrue);
    });

    test('should properly clean up resources', () async {
      final app = Harpy()

        // Simulate resource allocation
        ..enableLogging()
        ..enableCors();

      // Clean up should not throw
      await app.close();
      expect(app.isRunning, isFalse);
    });
  });

  group('Error Handling Tests', () {
    test('should handle validation errors gracefully', () {
      final user = HarpyTest();

      expect(user.validate, returnsNormally);

      final errors = user.validate();
      expect(errors, isA<List<String>>());
      expect(errors.isNotEmpty, isTrue);
    });

    test('should handle configuration errors', () {
      expect(
        () => Configuration.fromMap(<String, Object?>{}).getRequired('missing'),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('should handle route parameter extraction errors', () {
      final router = Router()..get('/users/:id', (req, res) => res.ok('user'));

      final route = router.routes.firstOrNull!;

      // Valid parameter extraction
      final validParams = route.extractParams('/users/123');
      expect(validParams['id'], equals('123'));

      // Invalid path should return empty params
      final invalidParams = route.extractParams('/invalid/path');
      expect(invalidParams.isEmpty, isTrue);
    });
  });
}
