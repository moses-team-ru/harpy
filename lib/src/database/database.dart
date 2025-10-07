import 'dart:async';

import 'package:harpy/src/database/adapters/sqlite_adapter.dart' as sqlite;
import 'package:harpy/src/database/database_connection.dart';
import 'package:harpy/src/database/model.dart';
import 'package:harpy/src/database/query_builder.dart';
import 'package:talker/talker.dart';

/// Main database manager class
///
/// Provides high-level database operations and connection management
class Database {
  Database._({required this.connection, required this.config});

  /// Database connection instance
  final DatabaseConnection connection;

  /// Database configuration
  final Map<String, dynamic> config;

  /// Talker instance for logging
  final Talker _talker = Talker();

  /// Registered model registries
  final Map<String, ModelRegistry> _modelRegistries = {};

  /// Create database instance
  static Future<Database> connect(Map<String, dynamic> config) async {
    final adapter = _getAdapter(config['type'] as String);
    final connection = adapter.createConnection(config);
    await connection.connect();

    return Database._(connection: connection, config: config);
  }

  /// Register a model with the database
  void registerModel<T extends Model>(
    String tableName,
    T Function() constructor,
  ) {
    _modelRegistries[T.toString()] = ModelRegistry<T>(
      tableName: tableName,
      modelConstructor: constructor,
      connection: connection,
    );
  }

  /// Get model registry
  ModelRegistry<T> getModelRegistry<T extends Model>() {
    final registry = _modelRegistries[T.toString()];
    if (registry == null) {
      throw StateError(
        'Model $T is not registered. Call registerModel<$T>() first.',
      );
    }
    return registry as ModelRegistry<T>;
  }

  /// Create a query builder for a model
  QueryBuilder<T> table<T extends Model>() {
    final registry = getModelRegistry<T>();
    return QueryBuilder<T>(T, connection)..table(registry.tableName);
  }

  /// Execute raw query
  Future<DatabaseResult> query(String sql, [List<Object?>? parameters]) =>
      connection.execute(sql, parameters);

  /// Start a transaction
  Future<DatabaseTransaction?> beginTransaction() =>
      connection.beginTransaction();

  /// Execute multiple operations in a transaction
  Future<T> transaction<T>(
    Future<T> Function(DatabaseTransaction transaction) callback,
  ) async {
    DatabaseTransaction? transaction;
    try {
      transaction = await beginTransaction();
      if (transaction == null) {
        throw const DatabaseException('Database does not support transactions');
      }

      final result = await callback(transaction);
      await transaction.commit();
      return result;
    } on Exception catch (e) {
      _talker.error('Transaction failed: $e');
      await transaction?.rollback();
      rethrow;
    }
  }

  /// Close database connection
  Future<void> close() async {
    await connection.disconnect();
  }

  /// Check if database is connected
  bool get isConnected => connection.isConnected;

  /// Ping database
  Future<bool> ping() => connection.ping();

  /// Get database information
  Future<Map<String, dynamic>> getInfo() => connection.getDatabaseInfo();

  /// Get adapter for database type
  static DatabaseAdapter _getAdapter(String type) {
    switch (type.toLowerCase()) {
      case 'sqlite':
        return const SqliteDatabaseAdapter();
      case 'postgresql':
      case 'postgres':
        return const PostgreSQLAdapter();
      case 'mysql':
        return const MySQLAdapter();
      case 'mongodb':
      case 'mongo':
        return const MongoDBAdapter();
      case 'redis':
        return const RedisAdapter();
      default:
        throw ArgumentError('Unsupported database type: $type');
    }
  }
}

/// Model registry for managing model metadata
class ModelRegistry<T extends Model> with Repository<T> {
  /// Create model registry
  ModelRegistry({
    required this.tableName,
    required this.modelConstructor,
    required this.connection,
  });

  @override
  final String tableName;

  @override
  final T Function() modelConstructor;

  @override
  final DatabaseConnection connection;
}

/// SQLite database adapter implementation
class SqliteDatabaseAdapter implements DatabaseAdapter {
  /// Singleton instance
  const SqliteDatabaseAdapter();

  @override
  DatabaseConnection createConnection(Map<String, dynamic> config) =>
      _SqliteConnectionWrapper(config);

  @override
  String get type => 'sqlite';

  @override
  Set<DatabaseFeature> get supportedFeatures => {
        DatabaseFeature.transactions,
        DatabaseFeature.foreignKeys,
        DatabaseFeature.indexing,
        DatabaseFeature.fullTextSearch,
        DatabaseFeature.jsonSupport,
      };

  @override
  bool validateConfig(Map<String, dynamic> config) =>
      config.containsKey('path');
}

/// Wrapper to handle async creation of SQLite connection
class _SqliteConnectionWrapper implements DatabaseConnection {
  _SqliteConnectionWrapper(this.config);

  @override
  final Map<String, dynamic> config;

  sqlite.SqliteAdapter? _adapter;

  @override
  bool get isConnected => _adapter?.isConnected ?? false;

  @override
  Future<void> connect() async {
    _adapter ??= await sqlite.SqliteAdapter.create(config);
  }

  @override
  Future<void> disconnect() async {
    await _adapter?.disconnect();
  }

  @override
  Future<DatabaseResult> execute(
    String query, [
    List<Object?>? parameters,
  ]) async {
    if (_adapter == null) {
      await connect();
    }
    return _adapter!.execute(query, parameters);
  }

  @override
  Future<DatabaseTransaction?> beginTransaction() async {
    if (_adapter == null) {
      await connect();
    }
    return _adapter!.beginTransaction();
  }

  @override
  Future<bool> ping() async {
    if (_adapter == null) return false;
    return _adapter!.ping();
  }

  @override
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    if (_adapter == null) {
      await connect();
    }
    return _adapter!.getDatabaseInfo();
  }
}

/// Placeholder adapters (to be implemented in separate files)
class PostgreSQLAdapter implements DatabaseAdapter {
  /// Singleton instance
  const PostgreSQLAdapter();

  @override
  DatabaseConnection createConnection(Map<String, dynamic> config) {
    throw UnimplementedError('PostgreSQL adapter not implemented yet');
  }

  @override
  String get type => 'postgresql';

  @override
  Set<DatabaseFeature> get supportedFeatures => {
        DatabaseFeature.transactions,
        DatabaseFeature.foreignKeys,
        DatabaseFeature.indexing,
        DatabaseFeature.fullTextSearch,
        DatabaseFeature.jsonSupport,
        DatabaseFeature.geoSpatial,
        DatabaseFeature.replication,
      };

  @override
  bool validateConfig(Map<String, dynamic> config) =>
      config.containsKey('host') &&
      config.containsKey('database') &&
      config.containsKey('username');
}

/// Placeholder adapters (to be implemented in separate files)
class MySQLAdapter implements DatabaseAdapter {
  /// Singleton instance
  const MySQLAdapter();

  @override
  DatabaseConnection createConnection(Map<String, dynamic> config) {
    throw UnimplementedError('MySQL adapter not implemented yet');
  }

  @override
  String get type => 'mysql';

  @override
  Set<DatabaseFeature> get supportedFeatures => {
        DatabaseFeature.transactions,
        DatabaseFeature.foreignKeys,
        DatabaseFeature.indexing,
        DatabaseFeature.fullTextSearch,
        DatabaseFeature.jsonSupport,
        DatabaseFeature.replication,
      };

  @override
  bool validateConfig(Map<String, dynamic> config) =>
      config.containsKey('host') &&
      config.containsKey('database') &&
      config.containsKey('username');
}

/// Placeholder adapters (to be implemented in separate files)
class MongoDBAdapter implements DatabaseAdapter {
  /// Singleton instance
  const MongoDBAdapter();

  @override
  DatabaseConnection createConnection(Map<String, dynamic> config) {
    throw UnimplementedError('MongoDB adapter not implemented yet');
  }

  @override
  String get type => 'mongodb';

  @override
  Set<DatabaseFeature> get supportedFeatures => {
        DatabaseFeature.indexing,
        DatabaseFeature.fullTextSearch,
        DatabaseFeature.jsonSupport,
        DatabaseFeature.geoSpatial,
        DatabaseFeature.aggregation,
        DatabaseFeature.replication,
        DatabaseFeature.sharding,
      };

  @override
  bool validateConfig(Map<String, dynamic> config) =>
      config.containsKey('uri') ||
      (config.containsKey('host') && config.containsKey('database'));
}

/// Placeholder adapters (to be implemented in separate files)
class RedisAdapter implements DatabaseAdapter {
  /// Singleton instance
  const RedisAdapter();

  @override
  DatabaseConnection createConnection(Map<String, dynamic> config) {
    throw UnimplementedError('Redis adapter not implemented yet');
  }

  @override
  String get type => 'redis';

  @override
  Set<DatabaseFeature> get supportedFeatures => {
        DatabaseFeature.streaming,
        DatabaseFeature.replication,
      };

  @override
  bool validateConfig(Map<String, dynamic> config) =>
      config.containsKey('host');
}
