// ignore_for_file: avoid-dynamic

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:harpy/src/database/database_connection.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:talker/talker.dart';

/// PostgreSQL database connection implementation using postgres package
class PostgreSQLAdapter implements DatabaseConnection {
  PostgreSQLAdapter._(this.config, this._connection);

  /// Factory method to create and connect a PostgreSQL database connection
  static Future<PostgreSQLAdapter> create(Map<String, dynamic> config) async {
    final endpoint = pg.Endpoint(
      host: config['host'] as String? ?? 'localhost',
      port: config['port'] as int? ?? 5432,
      database: config['database'] as String,
      username: config['username'] as String,
      password: config['password'] as String?,
    );

    final connection = await pg.Connection.open(
      endpoint,
      settings: pg.ConnectionSettings(
        sslMode: _getSslMode(config['sslMode'] as String?),
        connectTimeout: Duration(
          seconds: config['connectTimeout'] as int? ?? 30,
        ),
        queryTimeout: Duration(
          seconds: config['queryTimeout'] as int? ?? 30,
        ),
      ),
    );

    return PostgreSQLAdapter._(config, connection);
  }

  @override
  final Map<String, dynamic> config;

  final pg.Connection _connection;
  bool _isConnected = true; // Already connected after creation

  /// Talker instance for logging
  final Talker _talker = Talker();

  @override
  bool get isConnected => _isConnected && _connection.isOpen;

  @override
  Future<void> connect() async {
    // PostgreSQL connection is already established in factory
    if (!_isConnected || !_connection.isOpen) {
      throw const ConnectionException(
        'Cannot reconnect closed PostgreSQL connection. Create a new instance.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    if (_isConnected && _connection.isOpen) {
      await _connection.close();
      _isConnected = false;
    }
  }

  @override
  Future<DatabaseResult> execute(
    String query, [
    List<Object?>? parameters,
  ]) async {
    if (!isConnected) {
      throw const ConnectionException('Database connection is not active');
    }

    try {
      final List<Object?> params = parameters ?? <Object?>[];

      // Convert query to use PostgreSQL parameter syntax ($1, $2, etc.)
      final pgQuery = _convertParameterSyntax(query, params.length);

      final pg.Result result =
          await _connection.execute(pgQuery, parameters: params);

      return PostgreSQLResult(
        affectedRows: result.affectedRows,
        insertId: null, // PostgreSQL doesn't have lastInsertId concept
        rows: result
            .map((row) => Map<String, dynamic>.of(row.toColumnMap()))
            .toList(),
      );
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        QueryException('Query execution failed: $e', details: <String, dynamic>{
          'query': query,
          'parameters': parameters,
        }),
        stackTrace,
      );
    }
  }

  @override
  Future<DatabaseTransaction?> beginTransaction() async {
    if (!isConnected) {
      throw const ConnectionException('Database connection is not active');
    }

    await _connection.execute('BEGIN');
    return PostgreSQLTransaction._(_connection);
  }

  @override
  Future<bool> ping() async {
    if (!isConnected) return false;

    try {
      await _connection.execute('SELECT 1');
      return true;
    } on Exception catch (e) {
      _talker.error('PostgreSQL ping failed: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final versionResult =
        await _connection.execute('SELECT version() as version');
    final tablesResult = await _connection.execute(
      "SELECT tablename FROM pg_tables WHERE schemaname = 'public'",
    );

    return <String, dynamic>{
      'type': 'postgresql',
      'version': versionResult.firstOrNull?.toColumnMap()['version'],
      'host': config['host'],
      'database': config['database'],
      'tables':
          tablesResult.map((row) => row.toColumnMap()['tablename']).toList(),
      'connected': isConnected,
    };
  }

  /// Convert ? parameter syntax to PostgreSQL $1, $2, etc.
  String _convertParameterSyntax(String query, int paramCount) {
    String result = query;
    for (int i = 0; i < paramCount; i++) {
      result = result.replaceFirst('?', '\$${i + 1}');
    }
    return result;
  }

  /// Get SSL mode from string
  static pg.SslMode _getSslMode(String? mode) =>
      mode?.toLowerCase() == 'disable'
          ? pg.SslMode.disable
          : pg.SslMode.require;
}

/// PostgreSQL transaction implementation
class PostgreSQLTransaction implements DatabaseTransaction {
  PostgreSQLTransaction._(this._connection);

  final pg.Connection _connection;
  bool _isActive = true;

  @override
  bool get isActive => _isActive && _connection.isOpen;

  @override
  Future<void> commit() async {
    if (!isActive) {
      throw const TransactionException('Transaction is not active');
    }

    try {
      await _connection.execute('COMMIT');
      _isActive = false;
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        TransactionException('Failed to commit transaction: $e'),
        stackTrace,
      );
    }
  }

  @override
  Future<void> rollback() async {
    if (!isActive) return; // Already rolled back or committed

    try {
      await _connection.execute('ROLLBACK');
      _isActive = false;
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        TransactionException('Failed to rollback transaction: $e'),
        stackTrace,
      );
    }
  }

  @override
  Future<DatabaseResult> execute(
    String query, [
    List<Object?>? parameters,
  ]) async {
    if (!isActive) {
      throw const TransactionException('Transaction is not active');
    }

    final List<Object?> params = parameters ?? <Object?>[];

    try {
      // Convert query to use PostgreSQL parameter syntax
      final pgQuery = _convertParameterSyntax(query, params.length);

      final pg.Result result =
          await _connection.execute(pgQuery, parameters: params);

      return PostgreSQLResult(
        affectedRows: result.affectedRows,
        insertId: null,
        rows: result
            .map((row) => Map<String, dynamic>.of(row.toColumnMap()))
            .toList(),
      );
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        QueryException(
          'Transaction query execution failed: $e',
          details: <String, dynamic>{
            'query': query,
            'parameters': parameters,
          },
        ),
        stackTrace,
      );
    }
  }

  /// Convert ? parameter syntax to PostgreSQL $1, $2, etc.
  String _convertParameterSyntax(String query, int paramCount) {
    String result = query;
    for (int i = 0; i < paramCount; i++) {
      result = result.replaceFirst('?', '\$${i + 1}');
    }
    return result;
  }
}

/// PostgreSQL database result implementation
class PostgreSQLResult implements DatabaseResult {
  /// Create a new PostgreSQL result
  const PostgreSQLResult({
    required this.affectedRows,
    required this.insertId,
    required this.rows,
    this.metadata = const <String, dynamic>{},
  });

  @override
  final int affectedRows;

  @override
  final Object? insertId;

  @override
  final List<Map<String, dynamic>> rows;

  @override
  final Map<String, dynamic> metadata;

  @override
  bool get hasRows => rows.isNotEmpty;

  @override
  Map<String, dynamic>? get firstRow => hasRows ? rows.firstOrNull : null;
}
