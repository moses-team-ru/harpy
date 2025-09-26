// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'dart:convert';

import 'package:harpy/src/database/database_connection.dart';
import 'package:harpy/src/database/query_builder.dart';

/// Base model class for ORM entities
///
/// Provides common functionality for all model classes including
/// serialization, validation, and basic CRUD operations.
abstract class Model {
  /// Create a new model instance
  /// [initialAttributes] can be provided to set initial values
  Model({Map<String, Object?>? initialAttributes}) {
    if (initialAttributes != null) {
      _attributes.addAll(initialAttributes);
    }
  }

  final Map<String, Object?> _attributes = {};
  final Map<String, Object?> _original = {};
  bool _exists = false;

  /// Get model attributes
  Map<String, Object?> get attributes => Map.unmodifiable(_attributes);

  /// Get original attributes (before changes)
  Map<String, Object?> get original => Map.unmodifiable(_original);

  /// Check if model exists in database
  bool get exists => _exists;

  /// Check if model has been modified
  bool get isDirty => !_compareAttributes(_attributes, _original);

  /// Get the table name for this model
  String get tableName;

  /// Get the primary key column name (default: 'id')
  String get primaryKey => 'id';

  /// Get the primary key value
  Object? get id => getAttribute(primaryKey);

  /// Set the primary key value
  set id(Object? value) => setAttribute(primaryKey, value);

  /// Get an attribute value
  Object? getAttribute(String key) => _attributes[key];

  /// Set an attribute value
  void setAttribute(String key, Object? value) {
    if (!_original.containsKey(key)) {
      _original[key] = _attributes[key];
    }
    _attributes[key] = value;
  }

  /// Get attribute as specific type with null safety
  T? get<T>(String key) {
    final value = getAttribute(key);
    if (value == null) return null;
    if (value is T) return value as T;

    // Type conversion for common cases
    if (T == String) return value.toString() as T?;
    if (T == int && value is String) return int.tryParse(value) as T?;
    if (T == double && value is String) return double.tryParse(value) as T?;
    if (T == bool && value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true as T?;
      if (lower == 'false' || lower == '0') return false as T?;
    }

    return null;
  }

  /// Set multiple attributes
  void fillAttributes(Map<String, Object?> attrs) {
    for (final entry in attrs.entries) {
      setAttribute(entry.key, entry.value);
    }
  }

  /// Reset model to original state
  void reset() => _attributes
    ..clear()
    ..addAll(_original);

  /// Mark model as existing in database
  void markAsExisting() {
    _exists = true;
    _original
      ..clear()
      ..addAll(_attributes);
  }

  /// Get changed attributes
  Map<String, Object?> getChanges() {
    final changes = <String, Object?>{};
    for (final entry in _attributes.entries) {
      if (_original[entry.key] != entry.value) {
        changes[entry.key] = entry.value;
      }
    }
    return changes;
  }

  /// Validate model before save
  List<String> validate() => [];

  /// Convert model to JSON
  Map<String, Object?> toJson() => Map<String, Object?>.of(_attributes);

  /// Convert model to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create model from JSON
  static T fromJson<T extends Model>(
    Map<String, Object?> json,
    T Function() constructor,
  ) {
    final model = constructor()
      ..fillAttributes(json)
      ..markAsExisting();
    return model;
  }

  /// Convert to string representation
  @override
  String toString() => '$runtimeType(${jsonEncode(_attributes)})';

  /// Equality comparison based on primary key
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Model) return false;
    if (runtimeType != other.runtimeType) return false;

    final thisId = id;
    final otherId = other.id;

    if (thisId == null || otherId == null) return false;
    return thisId == otherId;
  }

  @override
  int get hashCode => id?.hashCode ?? super.hashCode;

  /// Compare two attribute maps
  bool _compareAttributes(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;

    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }

    return true;
  }
}

/// Active Record pattern implementation
///
/// Provides instance methods for database operations
mixin ActiveRecord on Model {
  DatabaseConnection? _connection;

  /// Set the database connection
  set connection(DatabaseConnection conn) => _connection = conn;

  /// Get the database connection
  DatabaseConnection get connection {
    if (_connection == null) {
      throw StateError(
        'Database connection not set. Call setConnection() first.',
      );
    }
    return _connection!;
  }

  /// Save the model to database (insert or update)
  Future<bool> save() async {
    final errors = validate();
    if (errors.isNotEmpty) {
      throw ValidationException('Validation failed: ${errors.join(', ')}');
    }

    return exists ? _update() : _insert();
  }

  /// Delete the model from database
  Future<bool> delete() async {
    if (!exists || id == null) return false;

    final result = await connection.execute(
      'DELETE FROM $tableName WHERE $primaryKey = ?',
      [id],
    );

    if (result.affectedRows > 0) {
      _exists = false;
      return true;
    }

    return false;
  }

  /// Refresh model from database
  Future<bool> refresh() async {
    if (!exists || id == null) return false;

    final result = await connection.execute(
      'SELECT * FROM $tableName WHERE $primaryKey = ?',
      [id],
    );

    if (result.hasRows) {
      fillAttributes(result.firstRow!);
      markAsExisting();
      return true;
    }

    return false;
  }

  /// Insert new record
  Future<bool> _insert() async {
    final attributes = Map<String, Object?>.of(_attributes)
      ..remove(primaryKey); // Remove primary key for auto-increment

    if (attributes.isEmpty) return false;

    final columns = attributes.keys.toList();
    final placeholders = List.filled(columns.length, '?').join(', ');
    final values = attributes.values.toList();

    final result = await connection.execute(
      'INSERT INTO $tableName (${columns.join(', ')}) VALUES ($placeholders)',
      values,
    );

    if (result.affectedRows > 0) {
      if (result.insertId != null) {
        setAttribute(primaryKey, result.insertId);
      }
      markAsExisting();
      return true;
    }

    return false;
  }

  /// Update existing record
  Future<bool> _update() async {
    if (!isDirty) return true; // No changes to save

    final changes = getChanges();
    if (changes.isEmpty) return true;

    final setParts = changes.keys.map((key) => '$key = ?').toList();
    final values = changes.values.toList()..add(id);

    final result = await connection.execute(
      'UPDATE $tableName SET ${setParts.join(', ')} WHERE $primaryKey = ?',
      values,
    );

    if (result.affectedRows > 0) {
      markAsExisting();
      return true;
    }

    return false;
  }
}

/// Repository pattern implementation
///
/// Provides static methods for querying models
mixin Repository<T extends Model> {
  /// Get database connection (must be implemented by concrete classes)
  DatabaseConnection get connection;

  /// Get model constructor (must be implemented by concrete classes)
  T Function() get modelConstructor;

  /// Get table name (must be implemented by concrete classes)
  String get tableName;

  /// Create a new query builder
  QueryBuilder<T> query() => QueryBuilder<T>(T, connection);

  /// Find model by primary key
  Future<T?> find(Object id) async {
    final result = await connection.execute(
      'SELECT * FROM $tableName WHERE id = ?',
      [id],
    );

    if (result.hasRows) {
      return _mapRowToModel(result.firstRow!);
    }

    return null;
  }

  /// Find model by primary key or throw exception
  Future<T> findOrFail(Object id) async {
    final model = await find(id);
    if (model == null) {
      throw DatabaseException('Model not found with id: $id');
    }
    return model;
  }

  /// Get all models
  Future<List<T>> all() async {
    final result = await connection.execute('SELECT * FROM $tableName');
    return result.rows.map(_mapRowToModel).toList();
  }

  /// Create a new model
  Future<T> create(Map<String, Object?> attributes) async {
    final model = modelConstructor()..fillAttributes(attributes);

    if (model is ActiveRecord) {
      model.connection = connection;
      await model.save();
    }

    return model;
  }

  /// Update model by primary key
  Future<bool> updateById(Object id, Map<String, Object?> attributes) async {
    if (attributes.isEmpty) return false;

    final setParts = attributes.keys.map((key) => '$key = ?').toList();
    final values = attributes.values.toList()..add(id);

    final result = await connection.execute(
      'UPDATE $tableName SET ${setParts.join(', ')} WHERE id = ?',
      values,
    );

    return result.affectedRows > 0;
  }

  /// Delete model by primary key
  Future<bool> deleteById(Object id) async {
    final result = await connection.execute(
      'DELETE FROM $tableName WHERE id = ?',
      [id],
    );

    return result.affectedRows > 0;
  }

  /// Map database row to model instance
  T _mapRowToModel(Map<String, Object?> row) {
    final model = modelConstructor()
      ..fillAttributes(row)
      ..markAsExisting();

    if (model is ActiveRecord) {
      model.connection = connection;
    }

    return model;
  }
}

/// Validation exception
class ValidationException implements Exception {
  /// Create a new validation exception
  const ValidationException(this.message);

  /// Error message
  final String message;

  @override
  String toString() => 'ValidationException: $message';
}
