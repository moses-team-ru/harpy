// ignore_for_file: avoid-dynamic

import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:harpy/src/database/database_connection.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:talker/talker.dart';

/// SQLite database connection implementation using sqlite3 package
class SqliteAdapter implements DatabaseConnection {
  SqliteAdapter._(this.config, this._database);

  /// Factory method to create and connect a SQLite database connection
  static Future<SqliteAdapter> create(Map<String, dynamic> config) async {
    final String dbPath = config['path'] as String? ?? ':memory:';

    // Ensure directory exists for file-based databases
    if (dbPath != ':memory:') {
      final File file = File(dbPath);
      final Directory directory = file.parent;
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
    }

    // Open SQLite database
    final Database database = sqlite3.open(dbPath)
      // Enable foreign keys by default
      ..execute('PRAGMA foreign_keys = ON');

    return SqliteAdapter._(config, database);
  }

  @override
  final Map<String, dynamic> config;

  final Database _database;
  bool _isConnected = true; // Already connected after creation

  @override
  bool get isConnected => _isConnected;

  /// Talker instance for logging
  final Talker _talker = Talker();

  @override
  Future<void> connect() async {
    // SQLite connection is already established in factory
    if (!_isConnected) {
      throw const ConnectionException(
        'Cannot reconnect closed SQLite database. Create a new instance.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    if (_isConnected) {
      _database.dispose();
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

      // Handle different types of queries
      if (query.trim().toUpperCase().startsWith('SELECT')) {
        final ResultSet resultSet = _database.select(query, params);
        final List<Map<String, dynamic>> rows =
            resultSet.map(Map<String, dynamic>.from).toList();

        return SqliteResult(affectedRows: 0, insertId: null, rows: rows);
      } // For INSERT, UPDATE, DELETE, CREATE, etc.
      _database.execute(query, params);

      return SqliteResult(
        affectedRows: _database.updatedRows,
        insertId: _database.lastInsertRowId,
        rows: const <Map<String, dynamic>>[],
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

    _database.execute('BEGIN TRANSACTION');
    return SqliteTransaction._(_database);
  }

  @override
  Future<bool> ping() async {
    if (!_isConnected) return false;

    try {
      _database.select('SELECT 1');
      return true;
    } on Exception catch (e) {
      _talker.error('SQLite ping failed: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final ResultSet versionResult =
        _database.select('SELECT sqlite_version() as version');
    final ResultSet tablesResult = _database.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );

    return <String, dynamic>{
      'type': 'sqlite',
      'version': versionResult.firstOrNull?['version'],
      'path': config['path'],
      'tables': tablesResult.map((Row row) => row['name']).toList(),
      'connected': _isConnected,
    };
  }
}

/// SQLite transaction implementation
class SqliteTransaction implements DatabaseTransaction {
  SqliteTransaction._(this._database);

  final Database _database;
  bool _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  Future<void> commit() async {
    if (!_isActive) {
      throw const TransactionException('Transaction is not active');
    }

    try {
      _database.execute('COMMIT');
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
    if (!_isActive) return; // Already rolled back or committed

    try {
      _database.execute('ROLLBACK');
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
    if (!_isActive) {
      throw const TransactionException('Transaction is not active');
    }

    final List<Object?> params = parameters ?? <Object?>[];

    try {
      if (query.trim().toUpperCase().startsWith('SELECT')) {
        final ResultSet resultSet = _database.select(query, params);
        final List<Map<String, dynamic>> rows =
            resultSet.map(Map<String, dynamic>.from).toList();

        return SqliteResult(affectedRows: 0, insertId: null, rows: rows);
      }
      _database.execute(query, params);

      return SqliteResult(
        affectedRows: _database.updatedRows,
        insertId: _database.lastInsertRowId,
        rows: const <Map<String, dynamic>>[],
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
}

/// SQLite database result implementation
class SqliteResult implements DatabaseResult {
  /// Create a new SQLite result
  const SqliteResult({
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
