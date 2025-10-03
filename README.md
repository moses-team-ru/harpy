# Harpy Backend Framework

<p align="center">
  <img src="assets/logotype.png" alt="Harpy Logo" width="200" height="200">
</p>

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

### 🗄️ Database & ORM Features
- **Production-Ready SQLite** - Full implementation with transactions, migrations, and connection pooling
- **PostgreSQL Support** - Complete adapter with advanced features
- **MySQL Connector** - Native MySQL database integration
- **MongoDB Integration** - NoSQL document database support
- **Redis Cache Layer** - Key-value store support (stub implementation)
- **Active Record Pattern** - Easy model-based database operations
- **Query Builder** - Type-safe, fluent query construction
- **Database Migrations** - Version control for your database schema
- **ACID Transactions** - Full transaction support with automatic rollback
- **Connection Pooling** - Efficient database connection management
- **Security First** - Built-in SQL injection prevention

### 🧪 Development & Testing
- **Testing Ready** - Easy to test with built-in testing utilities
- 🔧 **CLI Tools** - Project scaffolding and development tools

## � Documentation

Complete documentation is available in the [`doc/`](doc/) folder:

- **[📖 Documentation Index](doc/README.md)** - Complete guide and component overview
- **[🚀 Framework Overview](doc/harpy_framework.md)** - Core concepts and getting started
- **[⚙️ Configuration](doc/configuration.md)** - Environment and file-based configuration
- **[🗄️ Database System](doc/database.md)** - ORM, adapters, and migrations
- **[📡 HTTP Components](doc/http.md)** - Request/response handling
- **[🔧 Middleware](doc/middleware.md)** - Authentication, CORS, logging, and custom middleware
- **[🛣️ Routing](doc/routing.md)** - URL routing and parameter extraction
- **[🖥️ Server](doc/server.md)** - Server implementation and deployment

## �🚀 Quick Start

### Installation

Add Harpy to your `pubspec.yaml`:

```yaml
dependencies:
  harpy: ^0.1.1
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
dart run bin/my_api.dart serve
```

The generated project includes:
- `lib/main.dart` - Main application code
- `bin/my_api.dart` - CLI management tool with commands: serve, migrate, help, version

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

### Database & ORM

Harpy includes a complete ORM system with support for multiple databases. The framework provides a unified interface across all database adapters, making it easy to switch between different database systems.

#### Database Adapters Status

| Database | Status | Features | Production Ready |
|----------|--------|----------|------------------|
| **SQLite** | ✅ Complete | Full SQL, Transactions, Migrations, Connection pooling | ✅ Yes |
| **PostgreSQL** | ✅ Complete | Advanced SQL features, JSON support, Full-text search | ✅ Yes |
| **MySQL** | ✅ Complete | Standard SQL, Stored procedures, Multi-database | ✅ Yes |
| **MongoDB** | ✅ Complete | Document queries, Aggregation pipeline, GridFS | ✅ Yes |
| **Redis** | ⚠️ Stub Implementation | Basic key-value operations, Transactions (MULTI/EXEC) | ❌ Development needed |

> **Note:** The Redis adapter is currently implemented as a stub for demonstration purposes. A full Redis implementation is planned for future releases. See the [TODO](#-todo) section for more details.

#### SQLite (Production Ready)

The SQLite adapter provides the most mature and feature-complete implementation:

```dart
import 'package:harpy/harpy.dart';

void main() async {
  // Direct SQLite connection
  final db = await SqliteAdapter.create({
    'path': './database.db', // or ':memory:' for in-memory DB
  });

  // Create tables
  await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Insert with parameters (prevents SQL injection)
  await db.execute(
    'INSERT INTO users (name, email) VALUES (?, ?)',
    ['John Doe', 'john@example.com']
  );

  // Query data
  final result = await db.execute('SELECT * FROM users WHERE name LIKE ?', ['%John%']);
  for (final user in result.rows) {
    print('User: ${user['name']} (${user['email']})');
  }

  // Transactions
  final transaction = await db.beginTransaction();
  try {
    await transaction.execute('INSERT INTO users (name, email) VALUES (?, ?)', 
                             ['Alice', 'alice@example.com']);
    await transaction.execute('INSERT INTO users (name, email) VALUES (?, ?)', 
                             ['Bob', 'bob@example.com']);
    await transaction.commit();
  } on Exception catch (e) {
    await transaction.rollback();
    rethrow;
  }

  await db.disconnect();
}
```

#### PostgreSQL

Full-featured PostgreSQL support with advanced capabilities:

```dart
// PostgreSQL connection
final db = await PostgresqlAdapter.create({
  'host': 'localhost',
  'port': 5432,
  'database': 'myapp',
  'username': 'user',
  'password': 'password',
});

// Advanced PostgreSQL features
await db.execute('''
  CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    metadata JSONB,
    search_vector TSVECTOR,
    created_at TIMESTAMP DEFAULT NOW()
  )
''');

// JSON queries
final result = await db.execute(
  "SELECT * FROM products WHERE metadata->>'category' = ?",
  ['electronics']
);
```

#### MySQL

Native MySQL support with connection pooling:

```dart
// MySQL connection
final db = await MysqlAdapter.create({
  'host': 'localhost',
  'port': 3306,
  'database': 'myapp',
  'username': 'user',
  'password': 'password',
});

// MySQL-specific features
await db.execute('''
  CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB
''');
```

#### MongoDB

Document-oriented database support:

```dart
// MongoDB connection
final db = await MongodbAdapter.create({
  'host': 'localhost',
  'port': 27017,
  'database': 'myapp',
  'username': 'user',
  'password': 'password',
});

// Document operations
await db.execute('INSERT', ['users'], {
  'name': 'John Doe',
  'email': 'john@example.com',
  'profile': {
    'age': 30,
    'interests': ['coding', 'music']
  }
});

// Query documents
final result = await db.execute('FIND', ['users'], {
  'filter': {'profile.age': {'\$gte': 25}},
  'sort': {'name': 1}
});
```

#### Redis (Stub Implementation)

⚠️ **Current Status:** The Redis adapter is implemented as a stub for demonstration and testing purposes.

```dart
// Redis connection (stub implementation)
final db = await RedisAdapter.create({
  'host': 'localhost',
  'port': 6379,
  'database': 0,
});

// Basic operations (simulated)
await db.execute('SET key value');
final result = await db.execute('GET key');

// Note: This is a stub implementation
// Full Redis features are planned for future releases
```

#### Using Database Manager

```dart
// Connect through Database manager (supports multiple DB types)
final database = await Database.connect({
  'type': 'sqlite',           // sqlite, postgresql, mysql, mongodb, redis
  'path': './app_database.db',
});

// Use with automatic transaction handling
await database.transaction((tx) async {
  await tx.execute('INSERT INTO orders (user_id, total) VALUES (?, ?)', [1, 99.99]);
  await tx.execute('UPDATE inventory SET stock = stock - 1 WHERE id = ?', [1]);
  // Automatically commits on success, rolls back on error
});

// Get database info
final info = await database.getInfo();
print('Database: ${info['type']} v${info['version']}');
```

#### Models & Migrations

```dart
// Define models
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
    if (name == null || name!.trim().isEmpty) {
      errors.add('Name is required');
    }
    if (email == null || !email!.contains('@')) {
      errors.add('Valid email is required');
    }
    return errors;
  }
}

// Database migrations
class CreateUsersTable extends Migration {
  @override
  Future<void> up() async {
    await createTable('users', (table) {
      table.id();
      table.string('name', nullable: false);
      table.string('email', nullable: false);
      table.timestamps();
      table.unique(['email']);
      table.index(['name']);
    });
  }

  @override
  Future<void> down() async {
    await dropTable('users');
  }
}
```

#### Database Features

- ✅ **Multiple Database Support**: SQLite (production-ready), PostgreSQL, MySQL, MongoDB
- ⚠️ **Redis Support**: Basic key-value operations (stub implementation - full version planned)
- ✅ **ACID Transactions**: Full transaction support with automatic rollback
- ✅ **Query Builder**: Type-safe, fluent query construction
- ✅ **Active Record Pattern**: Easy model-based database operations  
- ✅ **Repository Pattern**: Clean separation of data access logic
- ✅ **Database Migrations**: Version control for your database schema
- ✅ **Connection Pooling**: Efficient database connection management
- ✅ **Security**: Built-in SQL injection prevention

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

## 📋 TODO

### High Priority
- [ ] **Complete Redis Adapter Implementation**
  - Replace stub implementation with full Redis client integration
  - Add support for all Redis data types (Strings, Lists, Sets, Sorted Sets, Hashes)
  - Implement Redis-specific features (Pub/Sub, Lua scripts, Streams)
  - Add connection pooling and cluster support
  - Comprehensive testing suite

### Medium Priority
- [ ] **Enhanced Query Builder**
  - Add support for complex JOIN operations across all adapters
  - Implement subquery support
  - Add query optimization hints

- [ ] **Advanced ORM Features**
  - Model relationships (One-to-Many, Many-to-Many)
  - Lazy loading and eager loading
  - Model validation and serialization
  - Schema synchronization

### Low Priority
- [ ] **Additional Database Adapters**
  - CouchDB support
  - InfluxDB for time-series data
  - Neo4j for graph databases

- [ ] **Performance Optimizations**
  - Query result caching
  - Connection pool optimization
  - Benchmark suite and performance monitoring

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