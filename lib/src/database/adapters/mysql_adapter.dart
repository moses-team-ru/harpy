// ignore_for_file: avoid-dynamic

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:harpy/src/database/database_connection.dart';
import 'package:mysql1/mysql1.dart' as mysql;

/// MySQL database connection implementation using mysql1 package
class MySQLAdapter implements DatabaseConnection {
  MySQLAdapter._(this.config, this._connection);

  /// Factory method to create and connect a MySQL database connection
  static Future<MySQLAdapter> create(Map<String, dynamic> config) async {
    final connectionSettings = mysql.ConnectionSettings(
      host: config['host'] as String? ?? 'localhost',
      port: config['port'] as int? ?? 3306,
      user: config['username'] as String,
      password: config['password'] as String?,
      db: config['database'] as String,
      useSSL: config['useSSL'] as bool? ?? false,
      timeout: Duration(seconds: config['timeout'] as int? ?? 30),
    );

    final connection = await mysql.MySqlConnection.connect(connectionSettings);

    return MySQLAdapter._(config, connection);
  }

  @override
  final Map<String, dynamic> config;

  final mysql.MySqlConnection _connection;
  bool _isConnected = true; // Already connected after creation

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    // MySQL connection is already established in factory
    if (!_isConnected) {
      throw const ConnectionException(
        'Cannot reconnect closed MySQL connection. Create a new instance.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    if (_isConnected) {
      await _connection.close();
      _isConnected = false;
    }
  }

  @override
  Future<DatabaseResult> execute(
    String query, [
    List<Object?>? parameters,
  ]) async {
    if (!_isConnected) {
      throw const ConnectionException('Database connection is not active');
    }

    try {
      final List<Object?> params = parameters ?? <Object?>[];

      final mysql.Results results = await _connection.query(query, params);

      return MySQLResult(
        affectedRows: results.affectedRows ?? 0,
        insertId: results.insertId,
        rows: results
            .map((row) => Map<String, dynamic>.of(_rowToMap(row)))
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
    if (!_isConnected) {
      throw const ConnectionException('Database connection is not active');
    }

    await _connection.query('START TRANSACTION');
    return MySQLTransaction._(_connection);
  }

  @override
  Future<bool> ping() async {
    if (!_isConnected) return false;

    try {
      await _connection.query('SELECT 1');
      return true;
    } on Exception catch (e) {
      print('MySQL ping failed: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final versionResult =
        await _connection.query('SELECT VERSION() as version');
    final tablesResult = await _connection.query(
      'SHOW TABLES FROM ${config['database']}',
    );

    return <String, dynamic>{
      'type': 'mysql',
      'version': versionResult.firstOrNull?.firstOrNull,
      'host': config['host'],
      'database': config['database'],
      'tables': tablesResult.map((row) => row.firstOrNull).toList(),
      'connected': _isConnected,
    };
  }

  /// Convert MySQL row to Map
  Map<String, dynamic> _rowToMap(mysql.ResultRow row) {
    final Map<String, dynamic> map = <String, dynamic>{};
    for (int i = 0; i < row.fields.length; i++) {
      // ignore: collection_methods_unrelated_type
      map[row.fields[i].name!] = row.elementAtOrNull(i);
    }
    return map;
  }
}

/// MySQL transaction implementation
class MySQLTransaction implements DatabaseTransaction {
  const MySQLTransaction._(this._connection);

  final mysql.MySqlConnection _connection;

  @override
  bool get isActive => true; // MySQL1 doesn't expose transaction state

  @override
  Future<void> commit() async {
    if (!isActive) {
      throw const TransactionException('Transaction is not active');
    }

    try {
      await _connection.query('COMMIT');
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        TransactionException('Failed to commit transaction: $e'),
        stackTrace,
      );
    }
  }

  @override
  Future<void> rollback() async {
    try {
      await _connection.query('ROLLBACK');
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
      final mysql.Results results = await _connection.query(query, params);

      return MySQLResult(
        affectedRows: results.affectedRows ?? 0,
        insertId: results.insertId,
        rows: results
            .map((row) => Map<String, dynamic>.of(_rowToMap(row)))
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

  /// Convert MySQL row to Map
  Map<String, dynamic> _rowToMap(mysql.ResultRow row) {
    final Map<String, dynamic> map = <String, dynamic>{};
    for (int i = 0; i < row.fields.length; i++) {
      // ignore: collection_methods_unrelated_type
      map[row.fields[i].name!] = row.elementAtOrNull(i);
    }
    return map;
  }
}

/// MySQL database result implementation
class MySQLResult implements DatabaseResult {
  /// Create a new MySQL result
  const MySQLResult({
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
