import 'package:harpy/harpy.dart';
import 'package:test/test.dart';

void main() {
  group('Migration System Tests', () {
    test('should create migration with version and description', () {
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

    test('should create migration with up and down methods', () {
      final migration = Migration(
        version: '002',
        description: 'Add age column to users',
        up: (schema) async {
          await schema.addColumn('users', 'age', 'INTEGER');
        },
        down: (schema) async {
          await schema.dropColumn('users', 'age');
        },
      );

      expect(migration.version, equals('002'));
      expect(migration.description, equals('Add age column to users'));
      expect(migration.up, isNotNull);
      expect(migration.down, isNotNull);
    });
  });

  group('TableBuilder Tests', () {
    test('should create table with id column', () {
      final builder = TableBuilder('users')..id();

      final sql = builder.build();
      expect(sql, contains('CREATE TABLE users'));
      expect(sql, contains('id INTEGER PRIMARY KEY AUTOINCREMENT'));
    });

    test('should create table with string columns', () {
      final builder = TableBuilder('users')
        ..string('name')
        ..string('email', length: 255, nullable: false);

      final sql = builder.build();
      expect(sql, contains('name VARCHAR'));
      expect(sql, contains('email VARCHAR(255) NOT NULL'));
    });

    test('should create table with basic column types', () {
      final builder = TableBuilder('test_table')
        ..id()
        ..string('name')
        ..integer('age')
        ..boolean('active')
        ..text('description')
        ..timestamp('created_at');

      final sql = builder.build();
      expect(sql, contains('CREATE TABLE test_table'));
      expect(sql, contains('name VARCHAR'));
      expect(sql, contains('age INTEGER'));
      expect(sql, contains('active BOOLEAN'));
      expect(sql, contains('description TEXT'));
      expect(sql, contains('created_at TIMESTAMP'));
    });

    test('should create table with constraints', () {
      final builder = TableBuilder('users')
        ..id()
        ..string('email')
        ..unique(['email'])
        ..index(['email']);

      final sql = builder.build();
      expect(sql, contains('UNIQUE (email)'));
      expect(sql, contains('-- INDEX users_email_index ON email'));
    });

    test('should create table with foreign keys', () {
      final builder = TableBuilder('posts')
        ..id()
        ..foreignKey('user_id', 'users');

      final sql = builder.build();
      expect(sql, contains('user_id INTEGER'));
      expect(sql, contains('FOREIGN KEY (user_id) REFERENCES users(id)'));
    });

    test('should create table with timestamps', () {
      final builder = TableBuilder('logs')
        ..id()
        ..timestamps();

      final sql = builder.build();
      expect(
        sql,
        contains('created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP'),
      );
      expect(
        sql,
        contains('updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP'),
      );
    });
  });

  group('Migration Status Tests', () {
    test('should create migration status', () {
      final migration = Migration(
        version: '001',
        description: 'Test migration',
        up: (schema) async {
          await schema.createTable('test', (table) {
            table.id();
          });
        },
      );

      final status = MigrationStatus(migration: migration, isExecuted: true);

      expect(status.migration, equals(migration));
      expect(status.isExecuted, isTrue);
      expect(status.status, equals('executed'));
    });

    test('should show pending status', () {
      final migration = Migration(
        version: '002',
        description: 'Pending migration',
        up: (schema) async {
          await schema.createTable('pending', (table) {
            table.id();
          });
        },
      );

      final status = MigrationStatus(migration: migration, isExecuted: false);

      expect(status.isExecuted, isFalse);
      expect(status.status, equals('pending'));
    });

    test('should convert to string correctly', () {
      final migration = Migration(
        version: '003',
        description: 'String test migration',
        up: (schema) async {
          await schema.createTable('string_test', (table) {
            table.id();
          });
        },
      );

      final status = MigrationStatus(migration: migration, isExecuted: true);
      final statusString = status.toString();

      expect(statusString, contains('003'));
      expect(statusString, contains('executed'));
      expect(statusString, contains('String test migration'));
    });
  });

  group('Migration Edge Cases', () {
    test('should handle empty migration description', () {
      final migration = Migration(
        version: '001',
        description: '',
        up: (schema) async {
          await schema.createTable('test', (table) => table.id());
        },
      );

      expect(migration.description, equals(''));
    });

    test('should handle complex table structures', () {
      final builder = TableBuilder('complex_table')
        ..id()
        ..string('name', nullable: false)
        ..text('description')
        ..boolean('active')
        ..foreignKey('category_id', 'categories')
        ..timestamps()
        ..unique(['name'])
        ..index(['category_id', 'active']);

      final sql = builder.build();

      expect(sql, contains('CREATE TABLE complex_table'));
      expect(sql, contains('id INTEGER PRIMARY KEY AUTOINCREMENT'));
      expect(sql, contains('name VARCHAR NOT NULL'));
      expect(sql, contains('description TEXT'));
      expect(sql, contains('active BOOLEAN'));
      expect(sql, contains('category_id INTEGER'));
      expect(
        sql,
        contains('FOREIGN KEY (category_id) REFERENCES categories(id)'),
      );
      expect(
        sql,
        contains('created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP'),
      );
      expect(sql, contains('UNIQUE (name)'));
      expect(
        sql,
        contains(
          '-- INDEX complex_table_category_id_active_index ON category_id, active',
        ),
      );
    });

    test('should handle special column names', () {
      final builder = TableBuilder('special_table')
        ..string('user_name')
        ..string('email_address')
        ..integer('birth_year')
        ..boolean('is_active');

      final sql = builder.build();

      expect(sql, contains('user_name VARCHAR'));
      expect(sql, contains('email_address VARCHAR'));
      expect(sql, contains('birth_year INTEGER'));
      expect(sql, contains('is_active BOOLEAN'));
    });
  });

  group('Migration SQL Generation', () {
    test('should generate proper SQL for different column types', () {
      final builder = TableBuilder('test_types')
        ..id()
        ..string('varchar_col', length: 100)
        ..text('text_col')
        ..integer('int_col')
        ..boolean('bool_col')
        ..timestamp('timestamp_col');

      final sql = builder.build();

      expect(sql, contains('varchar_col VARCHAR(100)'));
      expect(sql, contains('text_col TEXT'));
      expect(sql, contains('int_col INTEGER'));
      expect(sql, contains('bool_col BOOLEAN'));
      expect(sql, contains('timestamp_col TIMESTAMP'));
    });

    test('should generate proper constraints', () {
      final builder = TableBuilder('constrained_table')
        ..id()
        ..string('required_field', nullable: false)
        ..string('unique_field')
        ..foreignKey('parent_id', 'parents')
        ..unique(['unique_field'])
        ..index(['required_field', 'parent_id']);

      final sql = builder.build();

      expect(sql, contains('required_field VARCHAR NOT NULL'));
      expect(sql, contains('UNIQUE (unique_field)'));
      expect(sql, contains('FOREIGN KEY (parent_id) REFERENCES parents(id)'));
      expect(
        sql,
        contains(
          '-- INDEX constrained_table_required_field_parent_id_index ON required_field, parent_id',
        ),
      );
    });
  });
}
