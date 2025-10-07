// ignore_for_file: avoid-dynamic

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:harpy/src/database/database_connection.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:talker/talker.dart';

/// MongoDB database connection implementation using mongo_dart package
class MongoDBAdapter implements DatabaseConnection {
  MongoDBAdapter._(this.config, this._db);

  /// Factory method to create and connect a MongoDB database connection
  static Future<MongoDBAdapter> create(Map<String, dynamic> config) async {
    final String host = config['host'] as String? ?? 'localhost';
    final int port = config['port'] as int? ?? 27017;
    final String database = config['database'] as String;
    final String? username = config['username'] as String?;
    final String? password = config['password'] as String?;

    // Build connection URI
    String uri;
    if (username != null && password != null) {
      uri = 'mongodb://$username:$password@$host:$port/$database';
    } else {
      uri = 'mongodb://$host:$port/$database';
    }

    final mongo.Db db = mongo.Db(uri);
    await db.open();

    return MongoDBAdapter._(config, db);
  }

  @override
  final Map<String, dynamic> config;

  final mongo.Db _db;
  bool _isConnected = true; // Already connected after creation

  /// Talker instance for logging
  final Talker _talker = Talker();

  @override
  bool get isConnected => _isConnected && _db.isConnected;

  @override
  Future<void> connect() async {
    // MongoDB connection is already established in factory
    if (!_isConnected || !_db.isConnected) {
      throw const ConnectionException(
        'Cannot reconnect closed MongoDB connection. Create a new instance.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    if (_isConnected && _db.isConnected) {
      await _db.close();
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
      // Parse MongoDB-style query from SQL-like syntax
      final Map<String, dynamic> mongoQuery = _parseQuery(query, parameters);

      final List<Map<String, dynamic>> rows;
      int affectedRows = 0;
      Object? insertId;

      switch (mongoQuery['operation']) {
        case 'find':
          final mongo.DbCollection collection =
              _db.collection(mongoQuery['collection'] as String);
          final Stream<Map<String, dynamic>> cursor =
              collection.find(mongoQuery['filter']);
          rows = await cursor.toList();
          break;

        case 'insert':
          final mongo.DbCollection collection =
              _db.collection(mongoQuery['collection'] as String);
          final mongo.WriteResult result = await collection
              .insertOne(mongoQuery['document'] as Map<String, dynamic>);
          affectedRows = result.isSuccess ? 1 : 0;
          insertId = result.id;
          rows = <Map<String, dynamic>>[];
          break;

        case 'update':
          final mongo.DbCollection collection =
              _db.collection(mongoQuery['collection'] as String);
          final mongo.WriteResult result = await collection.updateMany(
            mongoQuery['filter'],
            mongoQuery['update'],
          );
          affectedRows = result.nModified;
          rows = <Map<String, dynamic>>[];
          break;

        case 'delete':
          final mongo.DbCollection collection =
              _db.collection(mongoQuery['collection'] as String);
          final mongo.WriteResult result =
              await collection.deleteMany(mongoQuery['filter']);
          affectedRows = result.nRemoved;
          rows = <Map<String, dynamic>>[];
          break;

        default:
          throw QueryException(
            'Unsupported MongoDB operation: ${mongoQuery['operation']}',
          );
      }

      return MongoDBResult(
        affectedRows: affectedRows,
        insertId: insertId,
        rows: rows,
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

    // MongoDB transactions are complex and require replica sets
    // For simplicity, we return a mock transaction
    return MongoDBTransaction._(_db);
  }

  @override
  Future<bool> ping() async {
    if (!isConnected) return false;

    try {
      await _db.collection('test').findOne(<String, dynamic>{});
      return true;
    } on Exception catch (e) {
      _talker.error('MongoDB ping failed: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final Map<String, Object> buildInfoCmd = <String, Object>{'buildInfo': 1};
    final Map<String, dynamic> buildInfo = await _db.runCommand(buildInfoCmd);
    final List<String?> collections = await _db.getCollectionNames();

    return <String, dynamic>{
      'type': 'mongodb',
      'version': buildInfo['version'],
      'host': config['host'],
      'database': config['database'],
      'collections': collections,
      'connected': isConnected,
    };
  }

  /// Parse SQL-like query into MongoDB operations
  /// This is a simplified parser for demonstration
  Map<String, dynamic> _parseQuery(String query, List<Object?>? parameters) {
    final String trimmedQuery = query.trim().toUpperCase();

    if (trimmedQuery.startsWith('SELECT')) {
      // Parse SELECT INTO FIND
      // Example: SELECT * FROM users WHERE age > 18
      final List<String> parts = query.split(RegExp(r'\s+'));
      final int fromIndex =
          parts.indexWhere((String part) => part.toUpperCase() == 'FROM');

      if (fromIndex == -1) {
        throw const QueryException('Invalid SELECT query: missing FROM clause');
      }

      final String? collection = parts.elementAtOrNull(fromIndex + 1);
      final Map<String, dynamic> filter = <String, dynamic>{};

      // Simple WHERE parsing (age > 18 becomes {'age': {'\$gt': 18}})
      final int whereIndex =
          parts.indexWhere((String part) => part.toUpperCase() == 'WHERE');
      if (whereIndex != -1 && parameters != null && parameters.isNotEmpty) {
        // This is a simplified example - in reality you'd need a proper SQL parser
        filter['_id'] = <String, bool>{r'$exists': true}; // Default filter
      }

      return <String, dynamic>{
        'operation': 'find',
        'collection': collection,
        'filter': filter,
      };
    } else if (trimmedQuery.startsWith('INSERT')) {
      // Parse INSERT INTO collection
      final List<String> parts = query.split(RegExp(r'\s+'));
      final int intoIndex =
          parts.indexWhere((String part) => part.toUpperCase() == 'INTO');

      if (intoIndex == -1) {
        throw const QueryException('Invalid INSERT query: missing INTO clause');
      }

      final String collection = parts.elementAtOrNull(intoIndex + 1) ?? '';
      final Map<String, dynamic> document = <String, dynamic>{};

      // In a real implementation, you'd parse VALUES clause
      if (parameters != null && parameters.isNotEmpty) {
        document['data'] = parameters.firstOrNull;
      }

      return <String, dynamic>{
        'operation': 'insert',
        'collection': collection,
        'document': document,
      };
    } else if (trimmedQuery.startsWith('UPDATE')) {
      // Parse UPDATE collection SET field = value WHERE condition
      final List<String> parts = query.split(RegExp(r'\s+'));
      final String collection = parts.elementAtOrNull(1) ?? '';

      return <String, dynamic>{
        'operation': 'update',
        'collection': collection,
        'filter': <String, dynamic>{
          '_id': <String, bool>{r'$exists': true},
        },
        'update': <String, dynamic>{
          r'$set': <String, dynamic>{'updated': true},
        },
      };
    } else if (trimmedQuery.startsWith('DELETE')) {
      // Parse DELETE FROM collection WHERE condition
      final List<String> parts = query.split(RegExp(r'\s+'));
      final int fromIndex =
          parts.indexWhere((String part) => part.toUpperCase() == 'FROM');

      if (fromIndex == -1) {
        throw const QueryException('Invalid DELETE query: missing FROM clause');
      }

      final String collection = parts.elementAtOrNull(fromIndex + 1) ?? '';

      return <String, dynamic>{
        'operation': 'delete',
        'collection': collection,
        'filter': <String, dynamic>{
          '_id': <String, bool>{r'$exists': true},
        },
      };
    }

    throw const QueryException('Unsupported query type');
  }
}

/// MongoDB transaction implementation
class MongoDBTransaction implements DatabaseTransaction {
  MongoDBTransaction._(this._db);

  final mongo.Db _db;
  bool _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  Future<void> commit() async {
    if (!isActive) {
      throw const TransactionException('Transaction is not active');
    }

    try {
      // MongoDB transactions are complex, for simplicity we just mark as inactive
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

    try {
      // For simplicity, delegate to the main adapter logic
      // In a real implementation, you'd execute within the session context
      final MongoDBAdapter adapter = MongoDBAdapter._(
        <String, dynamic>{'database': _db.databaseName},
        _db,
      );

      return await adapter.execute(query, parameters);
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

/// MongoDB database result implementation
class MongoDBResult implements DatabaseResult {
  /// Create a new MongoDB result
  const MongoDBResult({
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
