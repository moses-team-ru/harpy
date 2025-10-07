# SQLite Database Adapter

Harpy framework now includes a production-ready SQLite adapter built on the `sqlite3` package.

## Features

- ✅ **Real SQLite3 integration** - Uses the official `sqlite3` Dart package
- ✅ **Full transaction support** - ACID compliant transactions
- ✅ **Foreign key constraints** - Automatically enabled
- ✅ **Type-safe queries** - Proper parameter binding
- ✅ **Connection management** - Automatic connection handling
- ✅ **Error handling** - Comprehensive error reporting with stack traces

## Installation

The SQLite adapter is included with Harpy framework. The required dependencies are:

```yaml
dependencies:
  harpy: ^0.1.2+1
  sqlite3: ^2.4.2  # Automatically included
```

## Basic Usage

### Direct SQLite Connection

```dart
import 'package:harpy/harpy.dart';

void main() async {
  // Create SQLite connection
  final sqlite = await SqliteAdapter.create({
    'path': './my_database.db',  // File path
    // or 'path': ':memory:' for in-memory database
  });

  // Create table
  await sqlite.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Insert data with parameters
  await sqlite.execute(
    'INSERT INTO users (name, email) VALUES (?, ?)',
    ['John Doe', 'john@example.com']
  );

  // Query data
  final result = await sqlite.execute('SELECT * FROM users');
  for (final row in result.rows) {
    print('User: ${row['name']} (${row['email']})');
  }

  // Close connection
  await sqlite.disconnect();
}
```

### Using with Harpy Database Manager

```dart
import 'package:harpy/harpy.dart';

void main() async {
  // Connect through Database manager
  final db = await Database.connect({
    'type': 'sqlite',
    'path': './app_database.db',
  });

  // Execute queries
  await db.query('''
    CREATE TABLE posts (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT,
      user_id INTEGER REFERENCES users(id)
    )
  ''');

  // Use transactions
  await db.transaction((tx) async {
    await tx.execute('INSERT INTO users (name, email) VALUES (?, ?)', 
                    ['Alice', 'alice@example.com']);
    await tx.execute('INSERT INTO posts (title, user_id) VALUES (?, ?)', 
                    ['First Post', 1]);
  });

  await db.close();
}
```

## Configuration Options

```dart
final config = {
  'path': './database.db',     // Database file path
  // OR
  'path': ':memory:',          // In-memory database
};

final sqlite = await SqliteAdapter.create(config);
```

## Transaction Support

```dart
// Manual transaction control
final transaction = await sqlite.beginTransaction();
try {
  await transaction.execute('INSERT INTO users (name) VALUES (?)', ['User 1']);
  await transaction.execute('INSERT INTO users (name) VALUES (?)', ['User 2']);
  await transaction.commit();
} on Exception catch (e) {
  await transaction.rollback();
  rethrow;
}

// Or use Database.transaction() for automatic handling
await db.transaction((tx) async {
  await tx.execute('INSERT INTO users (name) VALUES (?)', ['User 3']);
  await tx.execute('INSERT INTO users (name) VALUES (?)', ['User 4']);
  // Automatically commits on success, rolls back on error
});
```

## Database Information

```dart
final info = await sqlite.getDatabaseInfo();
print('Database type: ${info['type']}');
print('SQLite version: ${info['version']}');
print('Database path: ${info['path']}');
print('Tables: ${info['tables']}');
print('Connected: ${info['connected']}');
```

## Error Handling

The SQLite adapter provides comprehensive error handling:

```dart
try {
  await sqlite.execute('INVALID SQL');
} on QueryException catch (e) {
  print('Query failed: ${e.message}');
  print('Details: ${e.details}');
} on ConnectionException catch (e) {
  print('Connection error: ${e.message}');
} on TransactionException catch (e) {
  print('Transaction error: ${e.message}');
}
```

## Best Practices

### 1. Use Parameters for User Input
```dart
// ✅ Good - prevents SQL injection
await sqlite.execute('SELECT * FROM users WHERE email = ?', [userEmail]);

// ❌ Bad - vulnerable to SQL injection
await sqlite.execute('SELECT * FROM users WHERE email = \'$userEmail\'');
```

### 2. Enable Foreign Keys
Foreign keys are automatically enabled, but you can verify:
```dart
final result = await sqlite.execute('PRAGMA foreign_keys');
print('Foreign keys enabled: ${result.rows.first['foreign_keys']}');
```

### 3. Use Transactions for Multiple Operations
```dart
// ✅ Good - atomic operations
await db.transaction((tx) async {
  await tx.execute('INSERT INTO orders (user_id, total) VALUES (?, ?)', [userId, total]);
  await tx.execute('UPDATE inventory SET stock = stock - ? WHERE product_id = ?', [quantity, productId]);
});
```

### 4. Proper Connection Management
```dart
// ✅ Good - always close connections
final sqlite = await SqliteAdapter.create(config);
try {
  // ... use database
} finally {
  await sqlite.disconnect();
}
```

### 5. Handle Concurrent Access
SQLite handles concurrent reads well, but writes are serialized:

```dart
// Multiple readers are fine
final users = await sqlite.execute('SELECT * FROM users');
final posts = await sqlite.execute('SELECT * FROM posts');

// Writes are automatically serialized by SQLite
await sqlite.execute('INSERT INTO users ...');
await sqlite.execute('INSERT INTO posts ...');
```

## Performance Tips

1. **Use Prepared Statements**: Parameters are automatically prepared
2. **Batch Operations**: Use transactions for multiple inserts/updates
3. **Indexing**: Create appropriate indexes for your queries
4. **PRAGMA Settings**: Optimize for your use case

```dart
// Performance optimization examples
await sqlite.execute('PRAGMA journal_mode=WAL');        // Better concurrency
await sqlite.execute('PRAGMA synchronous=NORMAL');      // Faster writes
await sqlite.execute('PRAGMA cache_size=10000');        // More memory cache
await sqlite.execute('PRAGMA temp_store=MEMORY');       // Memory temp storage
```

## Migration Support

Use with Harpy's migration system:

```dart
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

## Thread Safety

SQLite in Harpy is thread-safe when using separate connections per isolate. For shared access, use proper synchronization or connection pooling.

## Limitations

- **Single Writer**: SQLite allows only one writer at a time
- **File Locking**: File-based databases may have locking issues on some systems
- **Size Limits**: Practical limits for very large datasets (>100GB)

## Troubleshooting

### Common Issues

1. **Database Locked**: Another connection is writing
   ```dart
   // Solution: Use transactions or retry logic
   await Future.delayed(Duration(milliseconds: 10));
   ```

2. **File Permissions**: Database file not writable
   ```dart
   // Ensure directory exists and is writable
   final file = File(dbPath);
   await file.parent.create(recursive: true);
   ```

3. **Foreign Key Violations**: 
   ```dart
   // Check foreign key status
   await sqlite.execute('PRAGMA foreign_key_check');
   ```

This production-ready SQLite adapter provides enterprise-grade database functionality for Harpy applications!