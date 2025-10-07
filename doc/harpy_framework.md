# Harpy Framework Overview

Harpy is a modern, fast, and lightweight backend framework for Dart that makes building REST APIs easy and enjoyable. Built on top of Dart's powerful `shelf` package, Harpy provides an Express.js-like experience for Dart developers.

## 🎯 Core Philosophy

Harpy is designed around these principles:
- **Developer Experience** - Intuitive APIs and familiar patterns
- **Performance** - Built on Dart's high-performance HTTP server
- **Flexibility** - Modular architecture with optional components
- **Production Ready** - Enterprise-grade features out of the box
- **Type Safety** - Leverage Dart's strong type system

## 🚀 Getting Started

### Installation

Add Harpy to your `pubspec.yaml`:

```yaml
dependencies:
  harpy: ^0.1.2+1
```

Or install globally for CLI tools:

```bash
dart pub global activate harpy
```

### Your First API

```dart
import 'package:harpy/harpy.dart';

void main() async {
  final app = Harpy();
  
  // Basic route
  app.get('/', (req, res) {
    return res.json({
      'message': 'Welcome to Harpy!',
      'timestamp': DateTime.now().toIso8601String(),
    });
  });
  
  // Route with parameters
  app.get('/users/:id', (req, res) {
    final userId = req.params['id'];
    return res.json({'userId': userId});
  });
  
  // POST route with JSON body
  app.post('/users', (req, res) async {
    final body = await req.json();
    return res.status(201).json({
      'message': 'User created',
      'user': body,
    });
  });
  
  await app.listen(port: 3000);
  print('🚀 Server running on http://localhost:3000');
}
```

## 🏗️ Application Architecture

### Basic Structure

```dart
// lib/my_app.dart
import 'package:harpy/harpy.dart';

class MyApp {
  late final Harpy _app;
  
  MyApp({Configuration? config}) {
    _app = Harpy(config: config);
    _setupMiddleware();
    _setupRoutes();
  }
  
  void _setupMiddleware() {
    _app.enableCors();
    _app.enableLogging();
    _app.enableAuth(jwtSecret: 'your-secret-key');
  }
  
  void _setupRoutes() {
    _setupAuthRoutes();
    _setupAPIRoutes();
    _setupStaticRoutes();
  }
  
  Future<void> start({int port = 3000}) async {
    await _app.listen(port: port);
    print('🚀 Server running on port $port');
  }
  
  Future<void> stop() async {
    await _app.close();
  }
}
```

### Application Lifecycle

```dart
void main() async {
  // 1. Configuration
  final config = Configuration.fromEnvironment();
  
  // 2. Application creation
  final app = MyApp(config: config);
  
  // 3. Graceful shutdown handling
  ProcessSignal.sigint.watch().listen((_) async {
    print('Shutting down...');
    await app.stop();
    exit(0);
  });
  
  // 4. Start server
  final port = config.get<int>('port', 3000);
  await app.start(port: port);
}
```

## 🔧 Core Components

### Request-Response Cycle

```
1. Request arrives → 2. Middleware Stack → 3. Route Matching → 4. Handler Execution → 5. Response
```

```dart
app.get('/example', (req, res) async {
  // 1. Extract data from request
  final userAgent = req.userAgent;
  final query = req.query['q'];
  
  // 2. Process business logic
  final result = await processRequest(query);
  
  // 3. Build and return response
  return res
    .header('X-Response-Time', '${DateTime.now().millisecondsSinceEpoch}')
    .json({'result': result});
});
```

### Configuration Management

```dart
// Environment-based configuration
final app = Harpy(); // Uses environment variables

// File-based configuration
final config = Configuration.fromJsonFile('config.json');
final app = Harpy(config: config);

// Programmatic configuration
final config = Configuration.fromMap({
  'port': 8080,
  'database': {'type': 'sqlite', 'path': './app.db'},
});
final app = Harpy(config: config);

// Access configuration values
final port = app.config.get<int>('port', 3000);
final dbUrl = app.config.getRequired<String>('database.url');
```

## 🛣️ Routing System

### HTTP Methods

```dart
// Standard HTTP methods
app.get('/users', getUsersHandler);
app.post('/users', createUserHandler);
app.put('/users/:id', updateUserHandler);
app.patch('/users/:id', patchUserHandler);
app.delete('/users/:id', deleteUserHandler);

// Multiple methods
app.match(['GET', 'POST'], '/api/data', dataHandler);
app.any('/api/webhook', webhookHandler);
```

### Sub-routers

```dart
// Create API router
final apiRouter = Router();
apiRouter.get('/users', getUsersHandler);
apiRouter.post('/users', createUserHandler);

// Create admin router
final adminRouter = Router();
adminRouter.use(adminAuthMiddleware()); // Apply to all admin routes
adminRouter.get('/stats', getStatsHandler);
adminRouter.delete('/users/:id', deleteUserHandler);

// Mount routers
app.mount('/api/v1', apiRouter);
app.mount('/admin', adminRouter);
```

## 🔧 Middleware System

### Built-in Middleware

```dart
// CORS
app.enableCors(
  origin: 'https://myapp.com',
  allowedMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  credentials: true,
);

// Logging
app.enableLogging(
  logBody: true,
  logHeaders: false,
);

// Authentication
app.enableAuth(
  jwtSecret: 'your-secret-key',
  excludePaths: ['/login', '/register', '/health'],
);

// Database connection
app.enableDatabase(
  type: 'postgresql',
  host: 'localhost',
  database: 'myapp',
);
```

### Custom Middleware

```dart
// Request timing middleware
shelf.Middleware timingMiddleware() {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      final stopwatch = Stopwatch()..start();
      
      final response = await innerHandler(request);
      
      stopwatch.stop();
      return response.change(headers: {
        'X-Response-Time': '${stopwatch.elapsedMilliseconds}ms',
      });
    };
  };
}

app.use(timingMiddleware());
```

## 🗄️ Database Integration

### Quick Database Setup

```dart
void main() async {
  final app = Harpy(config: Configuration.fromMap({
    'database': {
      'type': 'sqlite',
      'path': './app.db',
    }
  }));

  app.get('/users', (req, res) async {
    final result = await req.database.execute('SELECT * FROM users');
    return res.json({'users': result.rows});
  });

  await app.listen(port: 3000);
}
```

### Using Models

```dart
class User extends Model with ActiveRecord {
  @override
  String get tableName => 'users';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get email => get<String>('email');
  set email(String? value) => setAttribute('email', value);

  @override
  List<String> validate() {
    final errors = <String>[];
    if (name == null || name!.isEmpty) errors.add('Name required');
    if (email == null || !email!.contains('@')) errors.add('Valid email required');
    return errors;
  }
}

// Using in handlers
app.post('/users', (req, res) async {
  final userData = await req.json();
  
  final user = User()
    ..name = userData['name']
    ..email = userData['email']
    ..connection = req.database;

  try {
    await user.save();
    return res.created({'user': user.toJson()});
  } on ValidationException catch (e) {
    return res.badRequest({'error': e.message});
  }
});
```

## 📡 HTTP Components

### Request Handling

```dart
app.post('/api/data', (req, res) async {
  // HTTP method and path
  print('${req.method} ${req.path}');
  
  // Headers
  final contentType = req.headers['content-type'];
  final userAgent = req.userAgent;
  
  // Parameters
  final id = req.params['id'];        // Route parameters
  final page = req.query['page'];     // Query parameters
  
  // Body parsing
  if (req.isJson) {
    final jsonData = await req.json();
    return res.json({'received': jsonData});
  }
  
  return res.badRequest({'error': 'JSON required'});
});
```

### Response Building

```dart
app.get('/api/examples', (req, res) {
  // JSON responses
  return res.json({'data': 'value'});
  
  // Status codes
  return res.status(201).json({'created': true});
  
  // Headers
  return res.header('X-Custom', 'value').json({});
  
  // Convenience methods
  return res.ok({'success': true});           // 200
  return res.created({'id': 123});            // 201
  return res.badRequest({'error': 'Invalid'}); // 400
  return res.notFound({'error': 'Not found'}); // 404
});
```

## 🏗️ Project Structure

### Recommended Layout

```
my_harpy_project/
├── bin/
│   └── main.dart              # Application entry point
├── lib/
│   ├── src/
│   │   ├── controllers/       # Request handlers
│   │   │   ├── auth_controller.dart
│   │   │   ├── user_controller.dart
│   │   │   └── post_controller.dart
│   │   ├── middleware/        # Custom middleware
│   │   │   ├── auth_middleware.dart
│   │   │   └── validation_middleware.dart
│   │   ├── models/           # Data models
│   │   │   ├── user.dart
│   │   │   └── post.dart
│   │   ├── services/         # Business logic
│   │   │   ├── user_service.dart
│   │   │   └── auth_service.dart
│   │   ├── database/         # Database-related
│   │   │   ├── migrations/
│   │   │   └── seeders/
│   │   └── utils/           # Utility functions
│   └── my_app.dart          # Main app class
├── test/                    # Tests
├── config/                  # Configuration files
│   ├── development.json
│   ├── production.json
│   └── test.json
├── docker/                  # Docker configuration
├── pubspec.yaml
└── README.md
```

### Modular Architecture

```dart
// lib/src/modules/user_module.dart
class UserModule {
  static void setup(Router router, DatabaseConnection db) {
    final userService = UserService(db);
    final userController = UserController(userService);
    
    router.get('/users', userController.list);
    router.get('/users/:id', userController.get);
    router.post('/users', userController.create);
    router.put('/users/:id', userController.update);
    router.delete('/users/:id', userController.delete);
  }
}

// lib/my_app.dart
void _setupRoutes() {
  final apiRouter = Router();
  
  UserModule.setup(apiRouter, database);
  PostModule.setup(apiRouter, database);
  AuthModule.setup(apiRouter, database);
  
  app.mount('/api/v1', apiRouter);
}
```

## 🧪 Testing

### Unit Testing

```dart
import 'package:test/test.dart';
import 'package:harpy/harpy.dart';

void main() {
  group('User API Tests', () {
    late Harpy app;
    late DatabaseConnection testDb;
    
    setUp(() async {
      // Use in-memory database for tests
      testDb = await SqliteAdapter.create({'path': ':memory:'});
      await runMigrations(testDb);
      
      app = Harpy();
      app.get('/users/:id', userHandler);
    });
    
    tearDown(() async {
      await testDb.close();
    });
    
    test('should get user by ID', () async {
      // Test implementation
    });
  });
}
```

### Integration Testing

```dart
import 'package:shelf_test_handler/shelf_test_handler.dart';

void main() {
  group('Integration Tests', () {
    test('should handle full request cycle', () async {
      final app = createTestApp();
      
      final response = await makeRequest(
        app.handler,
        'POST',
        '/api/users',
        body: jsonEncode({'name': 'Test User', 'email': 'test@example.com'}),
        headers: {'content-type': 'application/json'},
      );
      
      expect(response.statusCode, equals(201));
      final responseBody = jsonDecode(await response.readAsString());
      expect(responseBody['user']['name'], equals('Test User'));
    });
  });
}
```

## 🚀 Deployment

### Environment Configuration

```dart
void main() async {
  final config = Configuration.fromEnvironment();
  final app = MyApp(config: config);
  
  final port = config.get<int>('PORT', 3000);
  await app.start(port: port);
}
```

### Docker Deployment

```dockerfile
# Dockerfile
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.yaml ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/main.dart -o bin/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

EXPOSE 3000
ENTRYPOINT ["/app/bin/server"]
```

### Production Setup

```dart
void main() async {
  final config = Configuration.fromEnvironment();
  
  final app = Harpy(config: config);
  
  // Production middleware
  if (config.get<String>('ENVIRONMENT') == 'production') {
    app.enableAuth(jwtSecret: config.getRequired('JWT_SECRET'));
    app.enableCors(origin: config.get('CORS_ORIGIN'));
    
    // Disable body logging in production
    app.enableLogging(logBody: false);
  } else {
    // Development setup
    app.enableLogging(logBody: true);
  }
  
  final port = config.get<int>('PORT', 3000);
  await app.listen(host: '0.0.0.0', port: port);
}
```

## 🔍 Monitoring and Health Checks

### Health Check Endpoint

```dart
app.get('/health', (req, res) async {
  try {
    // Check database connection
    await req.database.ping();
    
    return res.json({
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
      'uptime': getUptime(),
      'version': getVersion(),
    });
  } catch (e) {
    return res.status(503).json({
      'status': 'unhealthy',
      'error': e.toString(),
    });
  }
});
```

### Metrics Endpoint

```dart
app.get('/metrics', (req, res) {
  return res.json({
    'requests_total': getRequestCount(),
    'requests_per_second': getRequestRate(),
    'response_time_avg': getAverageResponseTime(),
    'database_connections': getDatabaseConnectionCount(),
    'memory_usage': getMemoryUsage(),
  });
});
```

## 🔗 Related Documentation

- **[Configuration System](configuration.md)** - Application configuration
- **[HTTP Components](http.md)** - Request and Response handling  
- **[Routing System](routing.md)** - URL routing and parameters
- **[Database System](database.md)** - ORM and database adapters
- **[Middleware System](middleware.md)** - Cross-cutting concerns
- **[Testing Guide](testing.md)** - Testing strategies

---

This overview provides the foundation for building APIs with Harpy. Explore the specific component documentation for detailed information on each feature.