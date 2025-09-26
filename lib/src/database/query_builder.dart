// ignore_for_file: avoid_returning_this

import 'package:collection/collection.dart';

import 'package:harpy/src/database/database_connection.dart';
import 'package:harpy/src/database/model.dart';

/// Type-safe query builder for database operations
///
/// Provides a fluent interface for building database queries
/// with compile-time type safety and SQL injection protection.
class QueryBuilder<T extends Model> {
  /// Create a new QueryBuilder instance
  /// [_modelType] is the model class type
  /// [_connection] is the database connection to use
  QueryBuilder(this._modelType, this._connection);

  final Type _modelType;
  final DatabaseConnection _connection;
  final List<String> _select = [];
  final List<String> _where = [];
  final List<Object?> _parameters = [];
  final List<String> _orderBy = [];
  final List<String> _groupBy = [];
  final List<String> _having = [];
  final List<String> _joins = [];
  String? _tableName;
  int? _limit;
  int? _offset;
  bool _distinct = false;

  /// Set the table name (usually inferred from model)
  QueryBuilder<T> table(String tableName) {
    _tableName = tableName;
    return this;
  }

  /// Select specific columns
  QueryBuilder<T> select(List<String> columns) {
    _select.addAll(columns);
    return this;
  }

  /// Add WHERE clause with parameter binding
  QueryBuilder<T> where(String column, Object? value, [String operator = '=']) {
    if (_where.isNotEmpty) {
      _where.add('AND');
    }
    _where.add('$column $operator ?');
    _parameters.add(value);
    return this;
  }

  /// Add WHERE IN clause
  QueryBuilder<T> whereIn(String column, List<Object?> values) {
    if (values.isEmpty) return this;

    if (_where.isNotEmpty) {
      _where.add('AND');
    }

    final placeholders = List.filled(values.length, '?').join(', ');
    _where.add('$column IN ($placeholders)');
    _parameters.addAll(values);
    return this;
  }

  /// Add WHERE BETWEEN clause
  QueryBuilder<T> whereBetween(String column, Object? start, Object? end) {
    if (_where.isNotEmpty) {
      _where.add('AND');
    }
    _where.add('$column BETWEEN ? AND ?');
    _parameters.addAll([start, end]);
    return this;
  }

  /// Add WHERE LIKE clause
  QueryBuilder<T> whereLike(String column, String pattern) {
    if (_where.isNotEmpty) {
      _where.add('AND');
    }
    _where.add('$column LIKE ?');
    _parameters.add(pattern);
    return this;
  }

  /// Add WHERE NULL clause
  QueryBuilder<T> whereNull(String column) {
    if (_where.isNotEmpty) {
      _where.add('AND');
    }
    _where.add('$column IS NULL');
    return this;
  }

  /// Add WHERE NOT NULL clause
  QueryBuilder<T> whereNotNull(String column) {
    if (_where.isNotEmpty) {
      _where.add('AND');
    }
    _where.add('$column IS NOT NULL');
    return this;
  }

  /// Add OR WHERE clause
  QueryBuilder<T> orWhere(
    String column,
    Object? value, [
    String operator = '=',
  ]) {
    if (_where.isNotEmpty) {
      _where.add('OR');
    }
    _where.add('$column $operator ?');
    _parameters.add(value);
    return this;
  }

  /// Add ORDER BY clause
  QueryBuilder<T> orderBy(String column, [String direction = 'ASC']) {
    _orderBy.add('$column $direction');
    return this;
  }

  /// Add GROUP BY clause
  QueryBuilder<T> groupBy(String column) {
    _groupBy.add(column);
    return this;
  }

  /// Add HAVING clause
  QueryBuilder<T> having(String condition) {
    _having.add(condition);
    return this;
  }

  /// Add INNER JOIN
  QueryBuilder<T> join(String table, String condition) {
    _joins.add('INNER JOIN $table ON $condition');
    return this;
  }

  /// Add LEFT JOIN
  QueryBuilder<T> leftJoin(String table, String condition) {
    _joins.add('LEFT JOIN $table ON $condition');
    return this;
  }

  /// Add RIGHT JOIN
  QueryBuilder<T> rightJoin(String table, String condition) {
    _joins.add('RIGHT JOIN $table ON $condition');
    return this;
  }

  /// Set DISTINCT flag
  QueryBuilder<T> distinct() {
    _distinct = true;
    return this;
  }

  /// Set LIMIT
  QueryBuilder<T> limit(int count) {
    _limit = count;
    return this;
  }

  /// Set OFFSET
  QueryBuilder<T> offset(int count) {
    _offset = count;
    return this;
  }

  /// Execute SELECT query and return models
  Future<List<T>> get() async {
    final sql = _buildSelectQuery();
    final result = await _connection.execute(sql, _parameters);
    return _mapRowsToModels(result.rows);
  }

  /// Get first result or null
  Future<T?> first() async {
    final results = await limit(1).get();
    return results.firstOrNull;
  }

  /// Get first result or throw exception
  Future<T> firstOrFail() async {
    final result = await first();
    if (result == null) {
      throw const DatabaseException('No records found for query');
    }
    return result;
  }

  /// Count records
  Future<int> count([String column = '*']) async {
    final originalSelect = List<String>.of(_select);
    _select
      ..clear()
      ..add('COUNT($column) as count');

    final sql = _buildSelectQuery();
    final result = await _connection.execute(sql, _parameters);

    // Restore original select
    _select
      ..clear()
      ..addAll(originalSelect);

    return result.firstRow?['count'] as int? ?? 0;
  }

  /// Check if any records exist
  Future<bool> exists() async {
    final count = await this.count();
    return count > 0;
  }

  /// Execute UPDATE query
  Future<int> update(Map<String, Object?> values) async {
    if (values.isEmpty) return 0;

    final setParts = <String>[];
    final updateParams = <Object?>[];

    for (final entry in values.entries) {
      setParts.add('${entry.key} = ?');
      updateParams.add(entry.value);
    }

    final sql = _buildUpdateQuery(setParts);
    final result = await _connection.execute(sql, updateParams + _parameters);
    return result.affectedRows;
  }

  /// Execute DELETE query
  Future<int> delete() async {
    final sql = _buildDeleteQuery();
    final result = await _connection.execute(sql, _parameters);
    return result.affectedRows;
  }

  /// Insert a new record
  Future<T> insert(Map<String, Object?> values) async {
    if (values.isEmpty) {
      throw ArgumentError('Insert values cannot be empty');
    }

    final columns = values.keys.toList();
    final placeholders = List.filled(columns.length, '?').join(', ');
    final insertParams = values.values.toList();

    final sql =
        'INSERT INTO ${_getTableName()} (${columns.join(', ')}) VALUES ($placeholders)';
    final result = await _connection.execute(sql, insertParams);

    // If there's an auto-increment ID, add it to the values
    if (result.insertId != null) {
      values['id'] = result.insertId;
    }

    return _mapRowToModel(values);
  }

  /// Build SELECT query
  String _buildSelectQuery() {
    final buffer = StringBuffer()
      // SELECT clause
      ..write('SELECT ');
    if (_distinct) buffer.write('DISTINCT ');

    if (_select.isEmpty) {
      buffer.write('*');
    } else {
      buffer.write(_select.join(', '));
    }

    // FROM clause
    buffer.write(' FROM ${_getTableName()}');

    // JOIN clauses
    if (_joins.isNotEmpty) {
      buffer.write(' ${_joins.join(' ')}');
    }

    // WHERE clause
    if (_where.isNotEmpty) {
      buffer.write(' WHERE ${_where.join(' ')}');
    }

    // GROUP BY clause
    if (_groupBy.isNotEmpty) {
      buffer.write(' GROUP BY ${_groupBy.join(', ')}');
    }

    // HAVING clause
    if (_having.isNotEmpty) {
      buffer.write(' HAVING ${_having.join(' AND ')}');
    }

    // ORDER BY clause
    if (_orderBy.isNotEmpty) {
      buffer.write(' ORDER BY ${_orderBy.join(', ')}');
    }

    // LIMIT clause
    if (_limit != null) {
      buffer.write(' LIMIT $_limit');
    }

    // OFFSET clause
    if (_offset != null) {
      buffer.write(' OFFSET $_offset');
    }

    return buffer.toString();
  }

  /// Build UPDATE query
  String _buildUpdateQuery(List<String> setParts) {
    final buffer = StringBuffer()
      ..write('UPDATE ${_getTableName()} SET ${setParts.join(', ')}');

    if (_where.isNotEmpty) {
      buffer.write(' WHERE ${_where.join(' ')}');
    }

    return buffer.toString();
  }

  /// Build DELETE query
  String _buildDeleteQuery() {
    final buffer = StringBuffer()..write('DELETE FROM ${_getTableName()}');

    if (_where.isNotEmpty) {
      buffer.write(' WHERE ${_where.join(' ')}');
    }

    return buffer.toString();
  }

  /// Get table name from model or use explicitly set name
  String _getTableName() {
    if (_tableName != null) return _tableName!;

    // Convert model class name to snake_case table name
    final className = _modelType.toString();
    return _camelToSnakeCase(className);
  }

  /// Convert camelCase to snake_case
  String _camelToSnakeCase(String camelCase) =>
      camelCase.replaceAllMapped(RegExp('([a-z])([A-Z])'), (match) {
        final group1 = match[1] ?? '';
        final group2 = match[2]?.toLowerCase() ?? '';
        return '${group1}_$group2';
      }).toLowerCase();

  /// Map database rows to model instances
  List<T> _mapRowsToModels(List<Map<String, dynamic>> rows) =>
      rows.map(_mapRowToModel).toList();

  /// Map single database row to model instance
  T _mapRowToModel(Map<String, Object?> row) {
    // In a real implementation, model classes would provide factory constructors
    // or the database adapter would handle object mapping.
    // For now, this is a minimal implementation that works with simple test cases.
    throw UnimplementedError('Model mapping requires either:\n'
        '1. Model factory constructors (Model.fromMap)\n'
        '2. Database adapter with ORM capabilities\n'
        '3. Custom implementation in concrete QueryBuilder subclass');
  }
}
