// ignore_for_file: file_names
import 'package:collection/collection.dart';
import 'package:harpy/harpy.dart';
import 'package:test/test.dart';

void main() {
  group('ActiveRecord Static Methods', () {
    late Database database;
    late ActiveRecordStaticTest Function() userConstructor;

    setUp(() async {
      // Clear registry and register models
      ModelRegistry.clear();
      userConstructor = ActiveRecordStaticTest.new;
      ModelRegistry.register<ActiveRecordStaticTest>(userConstructor);

      // Set up in-memory SQLite database
      database = await Database.connect({
        'type': 'sqlite',
        'path': ':memory:',
      });

      // Set global connection
      ActiveRecord.setGlobalConnection(database.connection);

      // Create test table
      await database.connection.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          age INTEGER,
          active BOOLEAN DEFAULT 1,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Insert test data
      await database.connection.execute('''
        INSERT INTO users (name, email, age, active) VALUES 
        ('John Doe', 'john@example.com', 30, 1),
        ('Jane Smith', 'jane@example.com', 25, 1),
        ('Bob Wilson', 'bob@example.com', 35, 0),
        ('Alice Brown', 'alice@example.com', 28, 1)
      ''');
    });

    tearDown(() async {
      await database.close();
    });

    test('should fetch all models', () async {
      final users = await ActiveRecord.fetchAll<ActiveRecordStaticTest>();

      expect(users.length, equals(4));
      expect(users.firstOrNull?.name, equals('John Doe'));
      expect(users.every((user) => user.exists), isTrue);
    });

    test('should fetch models with where condition', () async {
      final activeUsers = await ActiveRecord.fetchAll<ActiveRecordStaticTest>(
        where: 'active = ?',
        parameters: [1],
      );

      expect(activeUsers.length, equals(3));
      expect(activeUsers.every((user) => user.active ?? false), isTrue);
    });

    test('should fetch models with ordering and limit', () async {
      final users = await ActiveRecord.fetchAll<ActiveRecordStaticTest>(
        orderBy: 'age DESC',
        limit: 2,
      );

      expect(users.length, equals(2));
      expect(users.firstOrNull?.age, equals(35)); // Bob Wilson (oldest)
      expect(users.lastOrNull?.age, equals(30)); // John Doe (second oldest)
    });

    test('should fetch single model', () async {
      final user = await ActiveRecord.fetchOne<ActiveRecordStaticTest>(
        where: 'email = ?',
        parameters: ['john@example.com'],
      );

      expect(user, isNotNull);
      expect(user!.name, equals('John Doe'));
      expect(user.email, equals('john@example.com'));
      expect(user.exists, isTrue);
    });

    test('should return null for non-existent model', () async {
      final user = await ActiveRecord.fetchOne<ActiveRecordStaticTest>(
        where: 'email = ?',
        parameters: ['nonexistent@example.com'],
      );

      expect(user, isNull);
    });

    test('should find model by primary key', () async {
      final user = await ActiveRecord.find<ActiveRecordStaticTest>(1);

      expect(user, isNotNull);
      expect(user!.name, equals('John Doe'));
      expect(user.id, equals(1));
    });

    test('should return null when finding non-existent primary key', () async {
      final user = await ActiveRecord.find<ActiveRecordStaticTest>(999);

      expect(user, isNull);
    });

    test('should find models by where condition', () async {
      final users =
          await ActiveRecord.where<ActiveRecordStaticTest>('active', 1);

      expect(users.length, equals(3));
      expect(users.every((user) => user.active ?? false), isTrue);
    });

    test('should find models with raw where condition', () async {
      final users = await ActiveRecord.whereRaw<ActiveRecordStaticTest>(
        'age > ? AND active = ?',
        [28, 1],
      );

      expect(users.length, equals(1)); // Only John Doe (30, active)
      expect(users.firstOrNull?.name, equals('John Doe'));
    });

    test('should create and save new model', () async {
      final user = await ActiveRecord.create<ActiveRecordStaticTest>({
        'name': 'New User',
        'email': 'new@example.com',
        'age': 22,
      });

      expect(user.name, equals('New User'));
      expect(user.email, equals('new@example.com'));
      expect(user.age, equals(22));
      expect(user.exists, isTrue);
      expect(user.id, isNotNull);

      // Verify it was actually saved
      final userId = user.id;
      expect(userId, isNotNull);
      final found = await ActiveRecord.find<ActiveRecordStaticTest>(userId!);
      expect(found, isNotNull);
      expect(found!.name, equals('New User'));
    });

    test('should count all models', () async {
      final count = await ActiveRecord.count<ActiveRecordStaticTest>();

      expect(count, equals(4));
    });

    test('should count models with condition', () async {
      final activeCount = await ActiveRecord.count<ActiveRecordStaticTest>(
        where: 'active = ?',
        parameters: [1],
      );

      expect(activeCount, equals(3));
    });

    test('should check if any models exist', () async {
      final hasUsers = await ActiveRecord.any<ActiveRecordStaticTest>();
      expect(hasUsers, isTrue);

      final hasAdmins = await ActiveRecord.any<ActiveRecordStaticTest>(
        where: 'name = ?',
        parameters: ['Admin'],
      );
      expect(hasAdmins, isFalse);
    });

    test('should delete models by where condition', () async {
      final deletedCount =
          await ActiveRecord.deleteWhere<ActiveRecordStaticTest>(
        'active = ?',
        [0], // Delete inactive users
      );

      expect(deletedCount, equals(1)); // Bob Wilson

      final remainingCount = await ActiveRecord.count<ActiveRecordStaticTest>();
      expect(remainingCount, equals(3));
    });

    test('should update models by where condition', () async {
      final updatedCount =
          await ActiveRecord.updateWhere<ActiveRecordStaticTest>(
        {'active': 0},
        whereClause: 'age > ?',
        parameters: [30],
      );

      expect(updatedCount, equals(1)); // Bob Wilson (35 years old)

      final activeCount = await ActiveRecord.count<ActiveRecordStaticTest>(
        where: 'active = ?',
        parameters: [1],
      );
      expect(
        activeCount,
        equals(3),
      ); // John (30) is NOT > 30, so he stays active + Jane + Alice
    });

    test('should handle empty results gracefully', () async {
      final users = await ActiveRecord.fetchAll<ActiveRecordStaticTest>(
        where: 'name = ?',
        parameters: ['NonExistent'],
      );

      expect(users, isEmpty);
    });

    test('should handle pagination', () async {
      final firstPage = await ActiveRecord.fetchAll<ActiveRecordStaticTest>(
        orderBy: 'id ASC',
        limit: 2,
        offset: 0,
      );

      final secondPage = await ActiveRecord.fetchAll<ActiveRecordStaticTest>(
        orderBy: 'id ASC',
        limit: 2,
        offset: 2,
      );

      expect(firstPage.length, equals(2));
      expect(secondPage.length, equals(2));
      expect(firstPage.firstOrNull?.id, equals(1));
      expect(secondPage.firstOrNull?.id, equals(3));
    });
  });
}

// Test model
class ActiveRecordStaticTest extends Model with ActiveRecord {
  @override
  String get tableName => 'users';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get email => get<String>('email');
  set email(String? value) => setAttribute('email', value);

  int? get age => get<int>('age');
  set age(int? value) => setAttribute('age', value);

  bool? get active {
    final value = getAttribute('active');
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  set active(bool? value) => setAttribute('active', value);

  DateTime? get createdAt => get<DateTime>('created_at');
  set createdAt(DateTime? value) => setAttribute('created_at', value);
}
