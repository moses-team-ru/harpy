// ignore_for_file: avoid_print

import 'package:harpy/harpy.dart';

void main() async {
  print('🗄️  Testing SQLite Adapter with real sqlite3 implementation');

  try {
    // Create SQLite connection
    final SqliteAdapter sqlite = await SqliteAdapter.create(
      <String, dynamic>{'path': './test_database.db'},
    );

    print('✅ SQLite connection created successfully');

    // Get database info
    final Map<String, dynamic> info = await sqlite.getDatabaseInfo();
    print('📊 Database Info:');
    print('   Type: ${info['type']}');
    print('   Version: ${info['version']}');
    print('   Path: ${info['path']}');
    print('   Connected: ${info['connected']}');

    // Create a test table
    await sqlite.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    print('📝 Created users table');

    // Insert test data
    await sqlite.execute(
      'INSERT INTO users (name, email) VALUES (?, ?)',
      <Object?>['John Doe', 'john@example.com'],
    );

    await sqlite.execute(
      'INSERT INTO users (name, email) VALUES (?, ?)',
      <Object?>['Jane Smith', 'jane@example.com'],
    );

    print('➕ Inserted test data');

    // Select data
    final DatabaseResult result =
        await sqlite.execute('SELECT * FROM users ORDER BY id');

    print('📋 Users in database:');
    for (final Map<String, dynamic> row in result.rows) {
      print(
        '   - ID: ${row['id']}, Name: ${row['name']}, Email: ${row['email']}',
      );
    }

    // Test transaction
    final DatabaseTransaction? transaction = await sqlite.beginTransaction();
    if (transaction != null) {
      print('🔄 Starting transaction...');

      try {
        await transaction.execute(
          'INSERT INTO users (name, email) VALUES (?, ?)',
          <Object?>['Transaction User', 'transaction@example.com'],
        );

        // Count users before commit
        final DatabaseResult beforeCommit =
            await transaction.execute('SELECT COUNT(*) as count FROM users');
        print(
          '   Users before commit: ${beforeCommit.rows.firstOrNull?['count']}',
        );

        await transaction.commit();
        print('✅ Transaction committed');

        // Count users after commit
        final DatabaseResult afterCommit =
            await sqlite.execute('SELECT COUNT(*) as count FROM users');
        print(
          '   Users after commit: ${afterCommit.rows.firstOrNull?['count']}',
        );
      } on Exception catch (e) {
        await transaction.rollback();
        print('❌ Transaction rolled back: $e');
      }
    }

    // Test update
    await sqlite.execute(
      'UPDATE users SET name = ? WHERE email = ?',
      <Object?>['John Updated', 'john@example.com'],
    );

    print('✏️  Updated user');

    // Test delete
    await sqlite.execute(
      'DELETE FROM users WHERE email = ?',
      <Object?>['jane@example.com'],
    );

    print('🗑️  Deleted user');

    // Final count
    final DatabaseResult finalResult =
        await sqlite.execute('SELECT COUNT(*) as count FROM users');
    print('📊 Final user count: ${finalResult.rows.firstOrNull?['count']}');

    // Cleanup
    await sqlite.disconnect();
    print('🔌 Database connection closed');
  } on Exception catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
  }
}
