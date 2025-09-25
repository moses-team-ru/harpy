# Harpy Backend Framework

A modern, fast, and lightweight backend framework for Dart that makes building REST APIs easy and enjoyable. Built on top of Dart's powerful `shelf` package, Harpy provides an Express.js-like experience for Dart developers.

[![Pub Version](https://img.shields.io/pub/v/harpy.svg)](https://pub.dev/packages/harpy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev)

## ✨ Features

- 🚀 **Fast & Lightweight** - Built on Dart's high-performance HTTP server
- 🛣️ **Powerful Routing** - Express.js-style routing with parameter support
- 🔧 **Middleware System** - Flexible and composable middleware architecture
- 📝 **JSON First** - Built-in JSON parsing and serialization
- ⚙️ **Configuration Management** - Environment-based configuration with file support
- 🔐 **Authentication** - JWT and Basic Auth middleware included
- 🌐 **CORS Support** - Cross-origin resource sharing out of the box
- 📊 **Request Logging** - Comprehensive request/response logging
- 🧪 **Testing Ready** - Easy to test with built-in testing utilities
- 🔧 **CLI Tools** - Project scaffolding and development tools

## 🚀 Quick Start

### Installation

Add Harpy to your `pubspec.yaml`:

```yaml
dependencies:
  harpy: ^0.1.0
```

Or install globally for CLI tools:

```bash
dart pub global activate harpy
```

### Create a New Project

```bash
harpy create my_api
cd my_api
dart pub get
dart run
```

### Basic Usage

```dart
import 'package:harpy/harpy.dart';

void main() async {
  final app = Harpy();
  
  // Enable CORS and logging
  app.enableCors();
  app.enableLogging();
  
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

## 📖 Documentation

### Routing

Harpy supports all standard HTTP methods with parameter support:

```dart
// Basic routes
app.get('/users', handler);
app.post('/users', handler);
app.put('/users/:id', handler);
app.delete('/users/:id', handler);
app.patch('/users/:id', handler);

// Route parameters
app.get('/users/:id/posts/:postId', (req, res) {
  final userId = req.params['id'];
  final postId = req.params['postId'];
  return res.json({'userId': userId, 'postId': postId});
});

// Query parameters
app.get('/search', (req, res) {
  final query = req.query['q'];
  final limit = int.tryParse(req.query['limit'] ?? '10') ?? 10;
  return res.json({'query': query, 'limit': limit});
});

// Multiple methods
app.match(['GET', 'POST'], '/api/data', handler);
app.any('/api/wildcard', handler); // All methods
```

### Request & Response

#### Request Object

```dart
app.post('/api/data', (req, res) async {
  // HTTP method and path
  print(req.method); // POST
  print(req.path);   // /api/data
  
  // Headers
  final contentType = req.headers['content-type'];
  final userAgent = req.userAgent;
  
  // Route parameters
  final id = req.params['id'];
  
  // Query parameters
  final filter = req.query['filter'];
  
  // JSON body
  final body = await req.json();
  
  // Raw body
  final rawBody = await req.text();
  
  // Check content type
  if (req.isJson) {
    // Handle JSON request
  }
  
  return res.json({'received': body});
});
```

#### Response Object

```dart
app.get('/api/examples', (req, res) {
  // JSON response
  return res.json({'data': 'value'});
  
  // Text response
  return res.text('Hello, World!');
  
  // HTML response
  return res.html('<h1>Hello</h1>');
  
  // Status codes
  return res.status(201).json({'created': true});
  
  // Headers
  return res.header('X-Custom', 'value').json({});
  
  // Redirects
  return res.redirect('/new-location');
  
  // File responses
  return res.file(File('path/to/file.pdf'));
  
  // Common status helpers
  return res.ok({'success': true});           // 200
  return res.created({'id': 123});            // 201
  return res.badRequest({'error': 'Invalid'}); // 400
  return res.unauthorized({'error': 'Auth'});  // 401
  return res.notFound({'error': 'Not found'}); // 404
  return res.internalServerError({'error': 'Server error'}); // 500
});
```

### Middleware

#### Built-in Middleware

```dart
final app = Harpy();

// CORS
app.enableCors(
  origin: 'https://myapp.com',
  allowedMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
);

// Logging
app.enableLogging(
  logBody: true,     // Log request/response bodies
  logHeaders: false, // Log headers
);

// Authentication
app.enableAuth(
  jwtSecret: 'your-secret-key',
  excludePaths: ['/login', '/register', '/health'],
);
```

#### Custom Middleware

```dart
import 'package:shelf/shelf.dart' as shelf;

// Custom middleware
shelf.Middleware customMiddleware() {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      print('Before request: ${request.method} ${request.url}');
      
      final response = await innerHandler(request);
      
      print('After request: ${response.statusCode}');
      return response;
    };
  };
}

// Use custom middleware
app.use(customMiddleware());
```

### Configuration

Harpy supports flexible configuration management:

```dart
// From environment variables
final app = Harpy(); // Uses Configuration.fromEnvironment()

// From JSON file
final config = Configuration.fromJsonFile('config.json');
final app = Harpy(config: config);

// From map
final config = Configuration.fromMap({
  'port': 8080,
  'database': {'url': 'postgresql://localhost/mydb'},
});
final app = Harpy(config: config);

// Access configuration
final port = app.config.get<int>('port', 3000);
final dbUrl = app.config.get<String>('database.url');
final debug = app.config.get<bool>('debug', false);

// Required values (throws if missing)
final secret = app.config.getRequired<String>('jwt.secret');
```

### Sub-routers

Organize your routes with sub-routers:

```dart
// Create API router
final apiRouter = Router();
apiRouter.get('/users', getUsersHandler);
apiRouter.post('/users', createUserHandler);
apiRouter.get('/posts', getPostsHandler);

// Create admin router
final adminRouter = Router();
adminRouter.get('/stats', getStatsHandler);
adminRouter.delete('/users/:id', deleteUserHandler);

// Mount routers
app.mount('/api/v1', apiRouter);
app.mount('/admin', adminRouter);

// Routes will be available at:
// GET /api/v1/users
// POST /api/v1/users  
// GET /api/v1/posts
// GET /admin/stats
// DELETE /admin/users/:id
```

### Error Handling

```dart
app.get('/error-example', (req, res) {
  throw Exception('Something went wrong!');
  // Automatically returns 500 with error details
});

// Custom error handling in middleware
shelf.Middleware errorHandler() {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      try {
        return await innerHandler(request);
      } catch (error, stackTrace) {
        print('Error: $error');
        return shelf.Response.internalServerError(
          body: jsonEncode({'error': error.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    };
  };
}

app.use(errorHandler());
```

### Testing

```dart
import 'package:test/test.dart';
import 'package:harpy/harpy.dart';

void main() {
  group('API Tests', () {
    late Harpy app;
    
    setUp(() {
      app = Harpy();
      app.get('/test', (req, res) => res.json({'test': true}));
    });
    
    test('should register routes', () {
      final routes = app.router.routes;
      expect(routes.length, equals(1));
      expect(routes.first.method, equals('GET'));
    });
  });
}
```

## 🛠 CLI Tools

Harpy includes a powerful CLI for project management:

```bash
# Create new project
harpy create my_api

# Show version
harpy version

# Help
harpy help
```

## 🏗 Project Structure

```
my_harpy_project/
├── bin/
│   └── main.dart          # Application entry point
├── lib/
│   ├── handlers/          # Route handlers
│   ├── middleware/        # Custom middleware
│   ├── models/           # Data models
│   └── services/         # Business logic
├── test/                 # Tests
├── config.json           # Configuration file
├── pubspec.yaml
└── README.md
```

## 🔧 Advanced Usage

### Custom Server Configuration

```dart
import 'dart:io';

final app = Harpy();

// Custom host and port
await app.listen(host: '0.0.0.0', port: 8080);

// HTTPS support
final context = SecurityContext()
  ..useCertificateChain('server.crt')
  ..usePrivateKey('server.key');

await app.listen(
  host: 'localhost',
  port: 443,
  securityContext: context,
);
```

### Environment-based Configuration

Create a `config.json` file:

```json
{
  "port": 3000,
  "database": {
    "host": "localhost",
    "port": 5432,
    "name": "myapp"
  },
  "jwt": {
    "secret": "your-secret-key",
    "expiresIn": "24h"
  }
}
```

Use environment variables (takes precedence over config files):

```bash
export PORT=8080
export DATABASE_HOST=prod-db.example.com
export JWT_SECRET=super-secret-key
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

```bash
git clone https://github.com/moses-team-ru/harpy.git
cd harpy
dart pub get
dart test
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built on top of the excellent [Shelf](https://pub.dev/packages/shelf) package
- Inspired by Express.js and other modern web frameworks
- Thanks to the Dart community for their support