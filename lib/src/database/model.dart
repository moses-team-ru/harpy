// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes, use_setters_to_change_properties, comment_references

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:harpy/src/database/database_connection.dart';
import 'package:harpy/src/database/model_registry.dart';
import 'package:harpy/src/database/query_builder.dart';
import 'package:harpy/src/database/relationships.dart';

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

  /// Get list of primary key columns (for composite keys)
  /// Override this in models that use composite primary keys
  List<String> get primaryKeys => [primaryKey];

  /// Get the primary key value
  Object? get id => getAttribute(primaryKey);

  /// Set the primary key value
  set id(Object? value) => setAttribute(primaryKey, value);

  /// Get primary key value(s) as a normalized format
  ///
  /// For single primary key: returns the value directly
  /// For composite keys: returns Map<String, Object?> with column -> value pairs
  /// Returns null if any part of the primary key is null
  Object? getPrimaryKeyValue() {
    if (primaryKeys.isEmpty) {
      throw StateError('No primary keys defined for model');
    }

    if (primaryKeys.length == 1) {
      final firstKey = primaryKeys.firstOrNull;
      if (firstKey == null) {
        throw StateError('Primary key list is empty');
      }
      return getAttribute(firstKey);
    }

    // Composite primary key
    final Map<String, Object?> keyValues = {};
    for (final keyColumn in primaryKeys) {
      final value = getAttribute(keyColumn);
      if (value == null) {
        return null; // Any null part makes the whole key null
      }
      keyValues[keyColumn] = value;
    }

    return keyValues;
  }

  /// Set primary key value(s) from various formats
  ///
  /// For single primary key: accepts any Object?
  /// For composite keys: accepts Map<String, Object?> with column -> value pairs
  void setPrimaryKeyValue(Object? value) {
    if (primaryKeys.isEmpty) {
      throw StateError('No primary keys defined for model');
    }

    if (primaryKeys.length == 1) {
      final firstKey = primaryKeys.firstOrNull;
      if (firstKey == null) {
        throw StateError('Primary key list is empty');
      }
      setAttribute(firstKey, value);
      return;
    }

    // Composite primary key
    if (value is! Map<String, Object?>) {
      throw ArgumentError(
        'Composite primary key requires Map<String, Object?>, got ${value.runtimeType}',
      );
    }

    for (final keyColumn in primaryKeys) {
      if (value.containsKey(keyColumn)) {
        setAttribute(keyColumn, value[keyColumn]);
      }
    }
  }

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

  /// Create a copy of this model with optionally modified attributes
  ///
  /// This method creates a new instance of the same model type with all
  /// current attributes copied over, plus any changes specified in [attributes].
  ///
  /// The new model will have the same existence state (exists/new) as the original.
  ///
  /// Example:
  /// ```dart
  /// final user = User()..name = 'John'..email = 'john@test.com';
  /// final updatedUser = user.copyWith({'name': 'Jane'});
  /// // updatedUser.name == 'Jane', updatedUser.email == 'john@test.com'
  /// ```
  T copyWith<T extends Model>({Map<String, Object?>? attributes}) {
    // Use ModelRegistry to create a new instance
    final T copy;
    try {
      copy = ModelRegistry.create<T>();
    } on ModelNotRegisteredException catch (e) {
      Error.throwWithStackTrace(
        UnsupportedError(
          'Cannot use copyWith() with $T. '
          'Register the model with ModelRegistry.register<$T>(() => $T()) '
          'in the model class definition. Original error: ${e.message}',
        ),
        StackTrace.current,
      );
    }

    // Copy all current attributes
    copy.fillAttributes(_attributes);

    // Apply any new attributes
    if (attributes != null) {
      copy.fillAttributes(attributes);
    }

    // Preserve the existence state
    if (_exists) {
      copy.markAsExisting();
    }

    return copy;
  }

  /// Create an exact clone of this model
  ///
  /// This is equivalent to copyWith() with no parameters.
  T clone<T extends Model>() => copyWith<T>();

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

    final thisPK = getPrimaryKeyValue();
    final otherPK = other.getPrimaryKeyValue();

    if (thisPK == null || otherPK == null) return false;

    // For composite keys, compare all key-value pairs
    if (thisPK is Map<String, Object?> && otherPK is Map<String, Object?>) {
      if (thisPK.length != otherPK.length) return false;
      for (final entry in thisPK.entries) {
        if (otherPK[entry.key] != entry.value) return false;
      }
      return true;
    }

    return thisPK == otherPK;
  }

  @override
  int get hashCode {
    final pk = getPrimaryKeyValue();
    if (pk == null) return super.hashCode;

    // For composite keys, combine all hash codes
    if (pk is Map<String, Object?>) {
      var hash = 17;
      for (final entry in pk.entries) {
        hash = hash * 31 + entry.key.hashCode;
        hash = hash * 31 + (entry.value?.hashCode ?? 0);
      }
      return hash;
    }

    return pk.hashCode;
  }

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

  /// Global database connection for static methods
  static DatabaseConnection? _globalConnection;

  /// Set global database connection for static methods
  static void setGlobalConnection(DatabaseConnection connection) =>
      _globalConnection = connection;

  /// Get global database connection for static methods
  static DatabaseConnection get globalConnection {
    if (_globalConnection == null) {
      throw StateError(
        'Global database connection not set. Call ActiveRecord.setGlobalConnection() first.',
      );
    }
    return _globalConnection!;
  }

  /// Set the database connection
  set connection(DatabaseConnection conn) => _connection = conn;

  /// Get the database connection
  DatabaseConnection get connection {
    if (_connection == null) {
      // Try to use global connection as fallback
      if (_globalConnection != null) {
        return _globalConnection!;
      }
      throw StateError(
        'Database connection not set. Call setConnection() or ActiveRecord.setGlobalConnection() first.',
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

  // Static ORM methods

  /// Find models by a where condition
  ///
  /// Usage:
  /// ```dart
  /// final users = await ActiveRecord.where<User>('name', 'John');
  /// final adults = await ActiveRecord.where<User>('age > ?', [18]);
  /// ```
  static Future<List<T>> where<T extends Model>(
    String column,
    Object? value, {
    DatabaseConnection? connection,
  }) async {
    final conn = connection ?? globalConnection;
    final instance = ModelRegistry.create<T>();

    final sql = 'SELECT * FROM ${instance.tableName} WHERE $column = ?';
    final result = await conn.execute(sql, [value]);

    return result.rows.map((row) {
      final model = ModelRegistry.fromJson<T>(row);
      if (model is ActiveRecord) {
        model.connection = conn;
      }
      return model;
    }).toList();
  }

  /// Find models by a complex where condition with parameters
  ///
  /// Usage:
  /// ```dart
  /// final users = await ActiveRecord.whereRaw<User>('age > ? AND name LIKE ?', [18, 'John%']);
  /// ```
  static Future<List<T>> whereRaw<T extends Model>(
    String whereClause,
    List<Object?> parameters, {
    DatabaseConnection? connection,
  }) async {
    final conn = connection ?? globalConnection;
    final instance = ModelRegistry.create<T>();

    final sql = 'SELECT * FROM ${instance.tableName} WHERE $whereClause';
    final result = await conn.execute(sql, parameters);

    return result.rows.map((row) {
      final model = ModelRegistry.fromJson<T>(row);
      if (model is ActiveRecord) {
        model.connection = conn;
      }
      return model;
    }).toList();
  }

  /// Find a single model by where condition
  ///
  /// Returns the first matching model or null if none found.
  ///
  /// Usage:
  /// ```dart
  /// final user = await ActiveRecord.fetchOne<User>(
  ///   where: 'email = ?',
  ///   parameters: ['john@example.com'],
  /// );
  /// ```
  static Future<T?> fetchOne<T extends Model>({
    String? where,
    List<Object?>? parameters,
    DatabaseConnection? connection,
  }) async {
    final conn = connection ?? globalConnection;
    final instance = ModelRegistry.create<T>();

    String sql = 'SELECT * FROM ${instance.tableName}';
    if (where != null) {
      sql += ' WHERE $where';
    }
    sql += ' LIMIT 1';

    final result = await conn.execute(sql, parameters);

    if (result.hasRows) {
      final model = ModelRegistry.fromJson<T>(result.firstRow!);
      if (model is ActiveRecord) {
        model.connection = conn;
      }
      return model;
    }

    return null;
  }

  /// Find all models with optional conditions
  ///
  /// Usage:
  /// ```dart
  /// final allUsers = await ActiveRecord.fetchAll<User>();
  /// final orderedUsers = await ActiveRecord.fetchAll<User>(
  ///   orderBy: 'created_at DESC',
  ///   limit: 10,
  /// );
  /// final filteredUsers = await ActiveRecord.fetchAll<User>(
  ///   where: 'active = ?',
  ///   parameters: [true],
  ///   orderBy: 'name ASC',
  /// );
  /// ```
  static Future<List<T>> fetchAll<T extends Model>({
    String? where,
    List<Object?>? parameters,
    String? orderBy,
    int? limit,
    int? offset,
    DatabaseConnection? connection,
  }) async {
    final conn = connection ?? globalConnection;
    final instance = ModelRegistry.create<T>();

    String sql = 'SELECT * FROM ${instance.tableName}';

    if (where != null) {
      sql += ' WHERE $where';
    }

    if (orderBy != null) {
      sql += ' ORDER BY $orderBy';
    }

    if (limit != null) {
      sql += ' LIMIT $limit';

      if (offset != null) {
        sql += ' OFFSET $offset';
      }
    }

    final result = await conn.execute(sql, parameters);

    return result.rows.map((row) {
      final model = ModelRegistry.fromJson<T>(row);
      if (model is ActiveRecord) {
        model.connection = conn;
      }
      return model;
    }).toList();
  }

  /// Find a model by primary key
  ///
  /// Usage:
  /// ```dart
  /// final user = await ActiveRecord.find<User>(1);
  /// final item = await ActiveRecord.find<OrderItem>({'order_id': 1, 'product_id': 2});
  /// ```
  static Future<T?> find<T extends Model>(
    Object primaryKeyValue, {
    DatabaseConnection? connection,
  }) async {
    final conn = connection ?? globalConnection;
    final instance = ModelRegistry.create<T>();

    String whereClause;
    List<Object?> parameters;

    if (instance.primaryKeys.length == 1) {
      // Single primary key
      final firstKey = instance.primaryKeys.firstOrNull;
      if (firstKey == null) {
        throw StateError('Primary key list is empty');
      }
      whereClause = '$firstKey = ?';
      parameters = [primaryKeyValue];
    } else {
      // Composite primary key
      if (primaryKeyValue is! Map<String, Object?>) {
        throw ArgumentError(
          'Composite primary key requires Map<String, Object?>, got ${primaryKeyValue.runtimeType}',
        );
      }

      final whereConditions = <String>[];
      parameters = <Object?>[];

      for (final keyColumn in instance.primaryKeys) {
        whereConditions.add('$keyColumn = ?');
        parameters.add(primaryKeyValue[keyColumn]);
      }

      whereClause = whereConditions.join(' AND ');
    }

    return fetchOne<T>(
      where: whereClause,
      parameters: parameters,
      connection: conn,
    );
  }

  /// Create a new model and save it to the database
  ///
  /// Usage:
  /// ```dart
  /// final user = await ActiveRecord.create<User>({
  ///   'name': 'John Doe',
  ///   'email': 'john@example.com',
  /// });
  /// ```
  static Future<T> create<T extends Model>(
    Map<String, Object?> attributes, {
    DatabaseConnection? connection,
  }) async {
    final model = ModelRegistry.create<T>()..fillAttributes(attributes);

    if (model is ActiveRecord) {
      final conn = connection ?? globalConnection;
      model.connection = conn;
      await model.save();
    }

    return model;
  }

  /// Count models with optional where condition
  ///
  /// Usage:
  /// ```dart
  /// final totalUsers = await ActiveRecord.count<User>();
  /// final activeUsers = await ActiveRecord.count<User>(
  ///   where: 'active = ?',
  ///   parameters: [true],
  /// );
  /// ```
  static Future<int> count<T extends Model>({
    String? where,
    List<Object?>? parameters,
    DatabaseConnection? connection,
  }) async {
    final conn = connection ?? globalConnection;
    final instance = ModelRegistry.create<T>();

    String sql = 'SELECT COUNT(*) as count FROM ${instance.tableName}';
    if (where != null) {
      sql += ' WHERE $where';
    }

    final result = await conn.execute(sql, parameters);

    if (result.hasRows) {
      return result.firstRow!['count'] as int? ?? 0;
    }

    return 0;
  }

  /// Check if any models exist with optional where condition
  ///
  /// Usage:
  /// ```dart
  /// final hasUsers = await ActiveRecord.any<User>();
  /// final hasAdmins = await ActiveRecord.any<User>(
  ///   where: 'role = ?',
  ///   parameters: ['admin'],
  /// );
  /// ```
  static Future<bool> any<T extends Model>({
    String? where,
    List<Object?>? parameters,
    DatabaseConnection? connection,
  }) async {
    final count = await ActiveRecord.count<T>(
      where: where,
      parameters: parameters,
      connection: connection,
    );
    return count > 0;
  }

  /// Delete models by where condition
  ///
  /// Returns the number of deleted rows.
  ///
  /// Usage:
  /// ```dart
  /// final deletedCount = await ActiveRecord.deleteWhere<User>(
  ///   'active = ?',
  ///   [false],
  /// );
  /// ```
  static Future<int> deleteWhere<T extends Model>(
    String whereClause,
    List<Object?> parameters, {
    DatabaseConnection? connection,
  }) async {
    final conn = connection ?? globalConnection;
    final instance = ModelRegistry.create<T>();

    final sql = 'DELETE FROM ${instance.tableName} WHERE $whereClause';
    final result = await conn.execute(sql, parameters);

    return result.affectedRows;
  }

  /// Update models by where condition
  ///
  /// Returns the number of updated rows.
  ///
  /// Usage:
  /// ```dart
  /// final updatedCount = await ActiveRecord.updateWhere<User>(
  ///   {'active': false},
  ///   whereClause: 'last_login < ?',
  ///   parameters: [DateTime.now().subtract(Duration(days: 90))],
  /// );
  /// ```
  static Future<int> updateWhere<T extends Model>(
    Map<String, Object?> attributes, {
    required String whereClause,
    required List<Object?> parameters,
    DatabaseConnection? connection,
  }) async {
    final conn = connection ?? globalConnection;
    final instance = ModelRegistry.create<T>();

    if (attributes.isEmpty) return 0;

    final setParts = attributes.keys.map((key) => '$key = ?').toList();
    final values = attributes.values.toList()..addAll(parameters);

    final sql =
        'UPDATE ${instance.tableName} SET ${setParts.join(', ')} WHERE $whereClause';
    final result = await conn.execute(sql, values);

    return result.affectedRows;
  }

  // Relationship methods

  /// Create a BelongsTo relationship
  ///
  /// Used when this model has a foreign key pointing to another model.
  ///
  /// Example:
  /// ```dart
  /// class Post extends Model with ActiveRecord {
  ///   Future<User?> get author => belongsTo<User>('user_id');
  /// }
  /// ```
  Future<T?> belongsTo<T extends Model>(
    String localKey, {
    String foreignKey = 'id',
    DatabaseConnection? conn,
  }) {
    final relationship = BelongsTo<T>(
      localKey: localKey,
      foreignKey: foreignKey,
      connection: conn,
    );
    return relationship.getRelated(this);
  }

  /// Create a HasOne relationship
  ///
  /// Used when this model is referenced by another model's foreign key,
  /// but only one related record is expected.
  ///
  /// Example:
  /// ```dart
  /// class User extends Model with ActiveRecord {
  ///   Future<Profile?> get profile => hasOne<Profile>('user_id');
  /// }
  /// ```
  Future<T?> hasOne<T extends Model>(
    String foreignKey, {
    String localKey = 'id',
    DatabaseConnection? conn,
  }) {
    final relationship = HasOne<T>(
      foreignKey: foreignKey,
      localKey: localKey,
      connection: conn,
    );
    return relationship.getRelated(this);
  }

  /// Create a HasMany relationship
  ///
  /// Used when this model is referenced by multiple other models.
  ///
  /// Example:
  /// ```dart
  /// class User extends Model with ActiveRecord {
  ///   Future<List<Post>> get posts => hasMany<Post>('user_id');
  /// }
  /// ```
  Future<List<T>> hasMany<T extends Model>(
    String foreignKey, {
    String localKey = 'id',
    String? orderBy,
    DatabaseConnection? conn,
  }) {
    final relationship = HasMany<T>(
      foreignKey: foreignKey,
      localKey: localKey,
      orderBy: orderBy,
      connection: conn,
    );
    return relationship.getRelatedList(this);
  }

  /// Create a BelongsToMany relationship
  ///
  /// Used when models are related through a pivot table.
  ///
  /// Example:
  /// ```dart
  /// class User extends Model with ActiveRecord {
  ///   Future<List<Role>> get roles => belongsToMany<Role>(
  ///     pivotTable: 'user_roles',
  ///     foreignPivotKey: 'user_id',
  ///     relatedPivotKey: 'role_id',
  ///   );
  /// }
  /// ```
  Future<List<T>> belongsToMany<T extends Model>(
    String pivotTable,
    String foreignPivotKey,
    String relatedPivotKey, {
    String localKey = 'id',
    String foreignKey = 'id',
    String? orderBy,
    DatabaseConnection? conn,
  }) {
    final relationship = BelongsToMany<T>(
      pivotTable: pivotTable,
      foreignPivotKey: foreignPivotKey,
      relatedPivotKey: relatedPivotKey,
      localKey: localKey,
      foreignKey: foreignKey,
      orderBy: orderBy,
      connection: conn,
    );
    return relationship.getRelatedList(this);
  }

  /// Attach a model to a many-to-many relationship
  ///
  /// Example:
  /// ```dart
  /// final user = await User.find(1);
  /// final role = await Role.find(2);
  /// await user.attach<Role>('user_roles', 'user_id', 'role_id', role);
  /// ```
  Future<void> attach<T extends Model>(
    String pivotTable,
    String foreignPivotKey,
    String relatedPivotKey,
    T related, {
    String localKey = 'id',
    String foreignKey = 'id',
    Map<String, Object?>? pivotData,
    DatabaseConnection? conn,
  }) async {
    final relationship = BelongsToMany<T>(
      pivotTable: pivotTable,
      foreignPivotKey: foreignPivotKey,
      relatedPivotKey: relatedPivotKey,
      localKey: localKey,
      foreignKey: foreignKey,
      connection: conn,
    );
    await relationship.attach(this, related, pivotData: pivotData);
  }

  /// Detach a model from a many-to-many relationship
  ///
  /// Example:
  /// ```dart
  /// final user = await User.find(1);
  /// final role = await Role.find(2);
  /// await user.detach<Role>('user_roles', 'user_id', 'role_id', role);
  /// ```
  Future<void> detach<T extends Model>(
    String pivotTable,
    String foreignPivotKey,
    String relatedPivotKey,
    T related, {
    String localKey = 'id',
    String foreignKey = 'id',
    DatabaseConnection? conn,
  }) async {
    final relationship = BelongsToMany<T>(
      pivotTable: pivotTable,
      foreignPivotKey: foreignPivotKey,
      relatedPivotKey: relatedPivotKey,
      localKey: localKey,
      foreignKey: foreignKey,
      connection: conn,
    );
    await relationship.detach(this, related);
  }

  /// Sync a many-to-many relationship
  ///
  /// Example:
  /// ```dart
  /// final user = await User.find(1);
  /// final roles = [role1, role2, role3];
  /// await user.sync<Role>('user_roles', 'user_id', 'role_id', roles);
  /// ```
  Future<void> sync<T extends Model>(
    String pivotTable,
    String foreignPivotKey,
    String relatedPivotKey,
    List<T> related, {
    String localKey = 'id',
    String foreignKey = 'id',
    DatabaseConnection? conn,
  }) async {
    final relationship = BelongsToMany<T>(
      pivotTable: pivotTable,
      foreignPivotKey: foreignPivotKey,
      relatedPivotKey: relatedPivotKey,
      localKey: localKey,
      foreignKey: foreignKey,
      connection: conn,
    );
    await relationship.sync(this, related);
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
