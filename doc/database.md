# Database System

Harpy includes a comprehensive database and ORM system that provides a unified interface across multiple database engines. The system is designed for production use with features like connection pooling, transactions, migrations, and type-safe query building.

## 🎯 Overview

### Supported Databases

| Database | Status | Features | Production Ready |
|----------|--------|----------|------------------|
| **SQLite** | ✅ Complete | Full SQL, Transactions, Migrations, File/Memory | ✅ Yes |
| **PostgreSQL** | ✅ Complete | Advanced SQL, JSON, Arrays, Full-text search | ✅ Yes |
| **MySQL** | ✅ Complete | Standard SQL, Stored procedures, Multi-database | ✅ Yes |
| **MongoDB** | ✅ Complete | Document queries, Aggregation pipeline, GridFS | ✅ Yes |
| **Redis** | ⚠️ Stub | Basic key-value operations, Transactions (MULTI/EXEC) | ❌ Development needed |

### Key Features

- 🔗 **Unified Interface** - Same API across all database adapters
- 🏗️ **ORM System** - Active Record and Repository patterns
- 🔄 **Migrations** - Database schema version control
- 🛡️ **ACID Transactions** - Full transaction support with rollback
- 🏊 **Connection Pooling** - Efficient connection management
- 🔒 **Security First** - Built-in SQL injection prevention
- 📊 **Query Builder** - Type-safe, fluent query construction
- 🧪 **Testing Support** - In-memory databases for testing

## 🚀 Quick Start

### Basic Database Connection

```dart
import 'package:harpy/harpy.dart';

void main() async {
  // Connect to SQLite
  final db = await Database.connect({
    'type': 'sqlite',
    'path': './app.db',
  });

  // Create table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Insert data
  await db.execute(
    'INSERT INTO users (name, email) VALUES (?, ?)',
    ['John Doe', 'john@example.com']
  );

  // Query data
  final result = await db.execute('SELECT * FROM users');
  for (final row in result.rows) {
    print('User: ${row['name']} (${row['email']})');
  }

  await db.close();
}
```

### Using with Harpy Framework

```dart
import 'package:harpy/harpy.dart';

void main() async {
  final app = Harpy(config: Configuration.fromMap({
    'database': {
      'type': 'postgresql',
      'host': 'localhost',
      'port': 5432,
      'database': 'myapp',
      'username': 'user',
      'password': 'password',
    }
  }));

  // Database is automatically available in handlers
  app.get('/users', (req, res) async {
    final result = await req.database.execute('SELECT * FROM users');
    return res.json({'users': result.rows});
  });

  await app.listen(port: 3000);
}
```

## 🏗️ ORM System

### Model Definition

```dart
class User extends Model with ActiveRecord {
  @override
  String get tableName => 'users';

  // Properties with getters and setters
  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get email => get<String>('email');
  set email(String? value) => setAttribute('email', value);

  DateTime? get createdAt => get<DateTime>('created_at');

  // Validation
  @override
  List<String> validate() {
    final errors = <String>[];
    if (name == null || name!.trim().isEmpty) {
      errors.add('Name is required');
    }
    if (email == null || !_isValidEmail(email!)) {
      errors.add('Valid email is required');
    }
    return errors;
  }

  bool _isValidEmail(String email) {
    return email.contains('@') && email.contains('.');
  }
}
```

### Active Record Pattern

```dart
void main() async {
  final db = await Database.connect({'type': 'sqlite', 'path': './app.db'});
  
  // Create and save a model
  final user = User()
    ..name = 'Jane Doe'
    ..email = 'jane@example.com'
    ..connection = db;

  if (await user.save()) {
    print('User created with ID: ${user.id}');
  }

  // Find and update
  final foundUser = await User.find(1);
  if (foundUser != null) {
    foundUser.name = 'Jane Smith';
    await foundUser.save();
  }

  // Delete
  await foundUser?.delete();
}
```

### Repository Pattern

```dart
class UserRepository with Repository<User> {
  @override
  final DatabaseConnection connection;
  
  @override
  String get tableName => 'users';
  
  @override
  User Function() get modelConstructor => () => User();

  UserRepository(this.connection);

  // Custom queries
  Future<List<User>> findByEmail(String email) async {
    final result = await connection.execute(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );
    return result.rows.map(_mapRowToModel).toList();
  }

  Future<List<User>> findActive() async {
    final result = await connection.execute(
      'SELECT * FROM users WHERE active = ?',
      [true]
    );
    return result.rows.map(_mapRowToModel).toList();
  }
}

// Usage
final userRepo = UserRepository(database);
final users = await userRepo.findByEmail('john@example.com');
```

## 🔄 Database Migrations

### Creating Migrations

```dart
class CreateUsersTable extends Migration {
  @override
  Future<void> up() async {
    await createTable('users', (table) {
      table.id();
      table.string('name', nullable: false);
      table.string('email', nullable: false);
      table.boolean('active', defaultValue: true);
      table.timestamps();
      
      // Constraints
      table.unique(['email']);
      table.index(['name']);
    });
  }

  @override
  Future<void> down() async {
    await dropTable('users');
  }
}

class AddProfileToUsers extends Migration {
  @override
  Future<void> up() async {
    await alterTable('users', (table) {
      table.json('profile');
      table.string('phone');
    });
  }

  @override
  Future<void> down() async {
    await alterTable('users', (table) {
      table.dropColumn('profile');
      table.dropColumn('phone');
    });
  }
}
```

### Running Migrations

```dart
void main() async {
  final migrator = Migrator(database);
  
  // Add migrations
  migrator.addMigration(CreateUsersTable());
  migrator.addMigration(AddProfileToUsers());
  
  // Run migrations
  await migrator.migrate();
  
  // Rollback if needed
  await migrator.rollback(); // Rolls back last migration
  await migrator.rollback(steps: 2); // Rolls back 2 migrations
}
```

## 🛡️ Transactions

### Manual Transaction Control

```dart
final transaction = await database.beginTransaction();
try {
  await transaction.execute(
    'INSERT INTO users (name, email) VALUES (?, ?)',
    ['Alice', 'alice@example.com']
  );
  
  await transaction.execute(
    'INSERT INTO orders (user_id, total) VALUES (?, ?)',
    [1, 99.99]
  );
  
  await transaction.commit();
  print('Transaction completed successfully');
} catch (e) {
  await transaction.rollback();
  print('Transaction rolled back due to error: $e');
}
```

### Automatic Transaction Management

```dart
await database.transaction((tx) async {
  // All operations in this block are part of the transaction
  await tx.execute('INSERT INTO users (name) VALUES (?)', ['Bob']);
  await tx.execute('UPDATE inventory SET stock = stock - 1 WHERE id = 1');
  
  // Automatically commits on success, rolls back on error
});
```

### Transaction with Models

```dart
await database.transaction((tx) async {
  final user = User()
    ..name = 'Transaction User'
    ..email = 'tx@example.com'
    ..connection = tx;
  
  await user.save();
  
  final order = Order()
    ..userId = user.id
    ..total = 149.99
    ..connection = tx;
  
  await order.save();
});
```

## 📊 Query Builder

### Basic Queries

```dart
// Select queries
final users = await query<User>()
  .where('active', true)
  .orderBy('name')
  .limit(10)
  .get();

// Complex conditions
final result = await query<User>()
  .where('age', '>=', 18)
  .where('city', 'in', ['New York', 'London', 'Tokyo'])
  .orWhere('premium', true)
  .get();

// Joins
final usersWithOrders = await query<User>()
  .join('orders', 'users.id', 'orders.user_id')
  .select(['users.*', 'orders.total'])
  .get();
```

### Aggregations

```dart
// Count
final userCount = await query<User>().count();

// Aggregates
final stats = await query<Order>()
  .select(['COUNT(*) as order_count', 'SUM(total) as total_revenue'])
  .where('status', 'completed')
  .first();

// Group by
final monthlySales = await query<Order>()
  .select(['DATE_FORMAT(created_at, "%Y-%m") as month', 'SUM(total) as revenue'])
  .groupBy('month')
  .orderBy('month')
  .get();
```

## 🔗 Database Adapters

### SQLite Adapter

**Status:** ✅ Production Ready

```dart
final sqlite = await SqliteAdapter.create({
  'path': './database.db',  // File path
  // or 'path': ':memory:'  // In-memory database
});

// Features:
// - Full SQL support
// - ACID transactions
// - Foreign key constraints
// - WAL mode for better concurrency
// - Prepared statements
```

**Documentation:** [sqlite_adapter.md](sqlite_adapter.md)

### PostgreSQL Adapter

**Status:** ✅ Production Ready

```dart
final postgres = await PostgresqlAdapter.create({
  'host': 'localhost',
  'port': 5432,
  'database': 'myapp',
  'username': 'user',
  'password': 'password',
  'sslMode': 'prefer',
  'poolSize': 10,
});

// Advanced features:
// - JSON/JSONB support
// - Arrays and custom types
// - Full-text search
// - Stored procedures
// - Connection pooling
```

**Documentation:** [postgresql_adapter.md](postgresql_adapter.md)

### MySQL Adapter

**Status:** ✅ Production Ready

```dart
final mysql = await MysqlAdapter.create({
  'host': 'localhost',
  'port': 3306,
  'database': 'myapp',
  'username': 'user',
  'password': 'password',
  'charset': 'utf8mb4',
  'poolSize': 5,
});

// Features:
// - Standard SQL support
// - Stored procedures
// - Multiple databases
// - Prepared statements
// - Connection pooling
```

**Documentation:** [mysql_adapter.md](mysql_adapter.md)

### MongoDB Adapter

**Status:** ✅ Production Ready

```dart
final mongo = await MongodbAdapter.create({
  'host': 'localhost',
  'port': 27017,
  'database': 'myapp',
  'username': 'user',
  'password': 'password',
});

// Document operations:
await mongo.execute('INSERT', ['users'], {
  'name': 'John Doe',
  'email': 'john@example.com',
  'profile': {
    'age': 30,
    'interests': ['coding', 'music']
  }
});

// Aggregation pipeline
final result = await mongo.execute('AGGREGATE', ['users'], [
  {'\$match': {'age': {'\$gte': 18}}},
  {'\$group': {'_id': '\$city', 'count': {'\$sum': 1}}},
  {'\$sort': {'count': -1}}
]);
```

**Documentation:** [mongodb_adapter.md](mongodb_adapter.md)

### Redis Adapter

**Status:** ⚠️ Stub Implementation

```dart
final redis = await RedisAdapter.create({
  'host': 'localhost',
  'port': 6379,
  'database': 0,
});

// Current implementation is a stub for demonstration
// Full Redis implementation is planned for future releases
```

**Documentation:** [redis_adapter.md](redis_adapter.md)

## 🏊 Connection Pooling

### Configuration

```dart
final db = await Database.connect({
  'type': 'postgresql',
  'host': 'localhost',
  'poolSize': 10,        // Maximum concurrent connections
  'poolTimeout': 30,     // Connection timeout in seconds
  'maxLifetime': 3600,   // Maximum connection lifetime
});
```

### Pool Monitoring

```dart
final poolInfo = await database.getPoolInfo();
print('Active connections: ${poolInfo['active']}');
print('Idle connections: ${poolInfo['idle']}');
print('Total connections: ${poolInfo['total']}');
```

## 🔒 Security Features

### SQL Injection Prevention

```dart
// ✅ Safe - uses parameterized queries
await db.execute(
  'SELECT * FROM users WHERE email = ? AND status = ?',
  [userEmail, 'active']
);

// ❌ Dangerous - vulnerable to SQL injection
await db.execute(
  "SELECT * FROM users WHERE email = '$userEmail'"
);
```

### Input Validation

```dart
class User extends Model {
  @override
  List<String> validate() {
    final errors = <String>[];
    
    // Validate email format
    if (email != null && !_isValidEmail(email!)) {
      errors.add('Invalid email format');
    }
    
    // Validate length
    if (name != null && name!.length > 255) {
      errors.add('Name too long');
    }
    
    return errors;
  }
}
```

### Connection Security

```dart
// PostgreSQL with SSL
final db = await Database.connect({
  'type': 'postgresql',
  'host': 'secure-db.example.com',
  'sslMode': 'require',
  'sslCert': '/path/to/client-cert.pem',
  'sslKey': '/path/to/client-key.pem',
  'sslRootCert': '/path/to/ca-cert.pem',
});
```

## 🧪 Testing

### In-Memory Databases

```dart
// Use in-memory SQLite for tests
final testDb = await SqliteAdapter.create({'path': ':memory:'});

// Run migrations
await runMigrations(testDb);

// Your tests here
test('should create user', () async {
  final user = User()
    ..name = 'Test User'
    ..email = 'test@example.com'
    ..connection = testDb;
  
  expect(await user.save(), isTrue);
  expect(user.id, isNotNull);
});
```

### Test Utilities

```dart
class DatabaseTestHelper {
  static Future<DatabaseConnection> createTestDatabase() async {
    final db = await SqliteAdapter.create({'path': ':memory:'});
    await runMigrations(db);
    return db;
  }
  
  static Future<void> seedTestData(DatabaseConnection db) async {
    await db.execute(
      'INSERT INTO users (name, email) VALUES (?, ?)',
      ['Test User', 'test@example.com']
    );
  }
  
  static Future<void> clearTestData(DatabaseConnection db) async {
    await db.execute('DELETE FROM users');
  }
}
```

## 📈 Performance Optimization

### Connection Pooling

```dart
// Optimal pool size = number of CPU cores * 2
final poolSize = Platform.numberOfProcessors * 2;

final db = await Database.connect({
  'type': 'postgresql',
  'poolSize': poolSize,
  'poolTimeout': 10,
});
```

### Query Optimization

```dart
// Use indexes
await db.execute('CREATE INDEX idx_users_email ON users(email)');

// Limit results
final users = await query<User>()
  .where('active', true)
  .limit(100)
  .get();

// Use prepared statements (automatic with parameters)
final stmt = await db.prepare('SELECT * FROM users WHERE city = ?');
final result1 = await stmt.execute(['New York']);
final result2 = await stmt.execute(['London']);
```

### Caching

```dart
class CachedUserRepository extends UserRepository {
  final Map<int, User> _cache = {};
  
  @override
  Future<User?> find(int id) async {
    if (_cache.containsKey(id)) {
      return _cache[id];
    }
    
    final user = await super.find(id);
    if (user != null) {
      _cache[id] = user;
    }
    
    return user;
  }
}
```

## 🚨 Error Handling

### Database Exceptions

```dart
try {
  await db.execute('INVALID SQL');
} on QueryException catch (e) {
  print('Query failed: ${e.message}');
  print('Details: ${e.details}');
} on ConnectionException catch (e) {
  print('Connection error: ${e.message}');
} on TransactionException catch (e) {
  print('Transaction error: ${e.message}');
}
```

### Validation Errors

```dart
final user = User()..name = ''; // Invalid

try {
  await user.save();
} on ValidationException catch (e) {
  print('Validation failed: ${e.message}');
  // Handle validation errors
}
```

## 🔗 Related Documentation

- **[SQLite Adapter](sqlite_adapter.md)** - Production-ready SQLite implementation
- **[Configuration](configuration.md)** - Database configuration settings
- **[Migrations](migrations.md)** - Database schema management
- **[Query Builder](query_builder.md)** - Advanced query construction
- **[Testing](testing.md)** - Database testing strategies

---

The database system provides enterprise-grade data persistence for Harpy applications. Choose your adapter and start building! Next, explore [HTTP Components](http.md) for request/response handling.