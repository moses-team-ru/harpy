import 'dart:async';

import 'package:harpy/src/database/database_connection.dart';

/// Database schema migration system
///
/// Provides version control for database schema changes
class Migration {
  /// Create a new migration
  /// [version] is a unique identifier for the migration (e.g. timestamp or sequential number)
  /// [description] is a brief description of the migration
  /// [up] is the function to apply the migration
  /// [down] is the optional function to rollback the migration
  const Migration({
    required this.version,
    required this.description,
    required this.up,
    this.down,
  });

  /// Migration version (typically timestamp or sequential number)
  final String version;

  /// Migration description
  final String description;

  /// Function to apply the migration
  final Future<void> Function(SchemaBuilder schema) up;

  /// Function to rollback the migration (optional)
  final Future<void> Function(SchemaBuilder schema)? down;

  @override
  String toString() => 'Migration($version: $description)';
}

/// Migration manager
class MigrationManager {
  /// Create a new migration manager
  /// [connection] is the database connection to use for migrations
  MigrationManager(this.connection);

  /// Database connection
  final DatabaseConnection connection;

  /// List of registered migrations
  final List<Migration> _migrations = <Migration>[];

  /// Name of the migrations tracking table
  static const String _migrationsTable = '_harpy_migrations';

  /// Add a migration
  void addMigration(Migration migration) {
    _migrations
      ..add(migration)
      ..sort((Migration a, Migration b) => a.version.compareTo(b.version));
  }

  /// Initialize migration tracking table
  Future<void> initialize() async {
    await connection.execute('''
      CREATE TABLE IF NOT EXISTS $_migrationsTable (
        version VARCHAR(255) PRIMARY KEY,
        description TEXT NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  /// Get list of executed migrations
  Future<Set<String>> getExecutedMigrations() async {
    try {
      final DatabaseResult result =
          await connection.execute('SELECT version FROM $_migrationsTable');
      return result.rows
          .map((Map<String, dynamic> row) => row['version'] as String)
          .toSet();
    } on Exception catch (e) {
      // If the migrations table doesn't exist yet, return empty set
      print('Warning: Failed to fetch executed migrations: $e');
      // Table might not exist yet
      return <String>{};
    }
  }

  /// Run pending migrations
  Future<List<String>> migrate() async {
    await initialize();
    final Set<String> executed = await getExecutedMigrations();
    final List<Migration> pending = _migrations
        .where((Migration m) => !executed.contains(m.version))
        .toList();

    if (pending.isEmpty) {
      print('No pending migrations.');
      return <String>[];
    }

    final List<String> migrated = <String>[];

    for (final Migration migration in pending) {
      print('Running migration ${migration.version}: ${migration.description}');

      try {
        final SchemaBuilder schema = SchemaBuilder(connection);
        await migration.up(schema);

        // Record migration as executed
        await connection.execute(
          'INSERT INTO $_migrationsTable (version, description) VALUES (?, ?)',
          <Object?>[migration.version, migration.description],
        );

        migrated.add(migration.version);
        print('✅ Migration ${migration.version} completed');
      } catch (e, stackTrace) {
        print('❌ Migration ${migration.version} failed: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }

    return migrated;
  }

  /// Rollback migrations
  Future<List<String>> rollback([int steps = 1]) async {
    final Set<String> executed = await getExecutedMigrations();
    final List<Migration> toRollback = _migrations
        .where((Migration m) => executed.contains(m.version))
        .toList()
        .reversed
        .take(steps)
        .toList();

    if (toRollback.isEmpty) {
      print('No migrations to rollback.');
      return <String>[];
    }

    final List<String> rolledBack = <String>[];

    for (final Migration migration in toRollback) {
      if (migration.down == null) {
        print(
          '❌ Migration ${migration.version} cannot be rolled back (no down function)',
        );
        break;
      }

      print(
        'Rolling back migration ${migration.version}: ${migration.description}',
      );

      try {
        final SchemaBuilder schema = SchemaBuilder(connection);
        await migration.down!(schema);

        // Remove migration record
        await connection.execute(
          'DELETE FROM $_migrationsTable WHERE version = ?',
          <Object?>[migration.version],
        );

        rolledBack.add(migration.version);
        print('✅ Migration ${migration.version} rolled back');
      } catch (e, stackTrace) {
        print('❌ Rollback of ${migration.version} failed: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }

    return rolledBack;
  }

  /// Get migration status
  Future<List<MigrationStatus>> getStatus() async {
    final Set<String> executed = await getExecutedMigrations();

    return _migrations
        .map((Migration migration) => MigrationStatus(
              migration: migration,
              isExecuted: executed.contains(migration.version),
            ))
        .toList();
  }

  /// Reset all migrations (dangerous!)
  Future<void> reset() async {
    print('⚠️  Resetting all migrations...');

    final Set<String> executed = await getExecutedMigrations();
    final List<Migration> toRollback = _migrations
        .where((Migration m) => executed.contains(m.version))
        .toList()
        .reversed
        .toList();

    for (final Migration migration in toRollback) {
      if (migration.down != null) {
        try {
          final SchemaBuilder schema = SchemaBuilder(connection);
          await migration.down!(schema);
        } on Exception catch (e) {
          print('Warning: Failed to rollback ${migration.version}: $e');
        }
      }
    }

    // Clear migration table
    await connection.execute('DELETE FROM $_migrationsTable');
    print('✅ All migrations reset');
  }
}

/// Migration status information
class MigrationStatus {
  /// Create migration status
  /// [migration] is the migration instance
  /// [isExecuted] indicates if the migration has been executed
  const MigrationStatus({required this.migration, required this.isExecuted});

  /// Migration instance
  final Migration migration;

  /// Whether the migration has been executed
  final bool isExecuted;

  /// Status string
  String get status => isExecuted ? 'executed' : 'pending';

  @override
  String toString() =>
      '${migration.version} [$status] ${migration.description}';
}

/// Schema builder for creating database schema changes
class SchemaBuilder {
  /// Create a new schema builder
  /// [connection] is the database connection to use for schema changes
  const SchemaBuilder(this.connection);

  /// Database connection
  final DatabaseConnection connection;

  /// Create a new table
  Future<void> createTable(
    String tableName,
    void Function(TableBuilder table) callback,
  ) async {
    final TableBuilder table = TableBuilder(tableName);
    callback(table);

    final String sql = table.build();
    await connection.execute(sql);
  }

  /// Drop a table
  Future<void> dropTable(String tableName) async {
    await connection.execute('DROP TABLE IF EXISTS $tableName');
  }

  /// Rename a table
  Future<void> renameTable(String oldName, String newName) async {
    await connection.execute('ALTER TABLE $oldName RENAME TO $newName');
  }

  /// Add a column to existing table
  Future<void> addColumn(
    String tableName,
    String columnName,
    String definition,
  ) async {
    await connection
        .execute('ALTER TABLE $tableName ADD COLUMN $columnName $definition');
  }

  /// Drop a column
  Future<void> dropColumn(String tableName, String columnName) async {
    await connection.execute('ALTER TABLE $tableName DROP COLUMN $columnName');
  }

  /// Create an index
  Future<void> createIndex(
    String indexName,
    String tableName,
    List<String> columns, {
    bool unique = false,
  }) async {
    final String uniqueKeyword = unique ? 'UNIQUE' : '';
    final String columnList = columns.join(', ');
    await connection.execute(
      'CREATE $uniqueKeyword INDEX $indexName ON $tableName ($columnList)',
    );
  }

  /// Drop an index
  Future<void> dropIndex(String indexName) async {
    await connection.execute('DROP INDEX IF EXISTS $indexName');
  }

  /// Execute raw SQL
  Future<void> execute(String sql, [List<Object?>? parameters]) async {
    await connection.execute(sql, parameters);
  }
}

/// Table builder for creating table definitions
class TableBuilder {
  /// Create a new table builder
  /// [tableName] is the name of the table to create
  TableBuilder(this.tableName);

  /// Table name
  final String tableName;

  /// List of column definitions
  final List<String> _columns = <String>[];

  /// List of table constraints
  final List<String> _constraints = <String>[];

  /// Add auto-incrementing primary key
  void id([String columnName = 'id']) {
    _columns.add('$columnName INTEGER PRIMARY KEY AUTOINCREMENT');
  }

  /// Add string column
  void string(String columnName, {int? length, bool nullable = true}) {
    final String lengthPart = length != null ? '($length)' : '';
    final String nullablePart = nullable ? '' : ' NOT NULL';
    _columns.add('$columnName VARCHAR$lengthPart$nullablePart');
  }

  /// Add text column
  void text(String columnName, {bool nullable = true}) {
    final String nullablePart = nullable ? '' : ' NOT NULL';
    _columns.add('$columnName TEXT$nullablePart');
  }

  /// Add integer column
  void integer(String columnName, {bool nullable = true}) {
    final String nullablePart = nullable ? '' : ' NOT NULL';
    _columns.add('$columnName INTEGER$nullablePart');
  }

  /// Add decimal column
  void decimal(
    String columnName, {
    int precision = 10,
    int scale = 2,
    bool nullable = true,
  }) {
    final String nullablePart = nullable ? '' : ' NOT NULL';
    _columns.add('$columnName DECIMAL($precision, $scale)$nullablePart');
  }

  /// Add boolean column
  void boolean(
    String columnName, {
    bool nullable = true,
    bool defaultValue = false,
  }) {
    final String nullablePart = nullable ? '' : ' NOT NULL';
    final String defaultPart = ' DEFAULT ${defaultValue ? 1 : 0}';
    _columns.add('$columnName BOOLEAN$nullablePart$defaultPart');
  }

  /// Add timestamp column
  void timestamp(
    String columnName, {
    bool nullable = true,
    bool useCurrentAsDefault = false,
  }) {
    final String nullablePart = nullable ? '' : ' NOT NULL';
    final String defaultPart =
        useCurrentAsDefault ? ' DEFAULT CURRENT_TIMESTAMP' : '';
    _columns.add('$columnName TIMESTAMP$nullablePart$defaultPart');
  }

  /// Add created_at and updated_at timestamps
  void timestamps() {
    timestamp('created_at', nullable: false, useCurrentAsDefault: true);
    timestamp('updated_at', nullable: false, useCurrentAsDefault: true);
  }

  /// Add foreign key constraint
  void foreignKey(
    String columnName,
    String referencedTable, {
    String referencedColumn = 'id',
  }) {
    integer(columnName);
    _constraints.add(
      'FOREIGN KEY ($columnName) REFERENCES $referencedTable($referencedColumn)',
    );
  }

  /// Add unique constraint
  void unique(List<String> columns) {
    _constraints.add('UNIQUE (${columns.join(', ')})');
  }

  /// Add index
  void index(List<String> columns, {String? name}) {
    final String indexName = name ?? '${tableName}_${columns.join('_')}_index';
    // Note: This would need to be executed separately after table creation
    // For now, just store it as a comment
    _constraints.add('-- INDEX $indexName ON ${columns.join(', ')}');
  }

  /// Build the CREATE TABLE SQL
  String build() {
    if (_columns.isEmpty) {
      throw StateError('Table must have at least one column');
    }

    final List<String> allParts = <String>[..._columns, ..._constraints];
    return 'CREATE TABLE $tableName (\n  ${allParts.join(',\n  ')}\n)';
  }
}
