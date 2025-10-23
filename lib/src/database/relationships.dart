/// Relationship system for ORM models
///
/// This library provides a comprehensive system for managing relationships
/// between models, including BelongsTo, HasMany, BelongsToMany, and HasOne relationships.
// ignore_for_file: library_names
library;

import 'package:collection/collection.dart';
import 'package:harpy/src/database/database_connection.dart';
import 'package:harpy/src/database/model.dart';
import 'package:harpy/src/database/model_registry.dart';

/// Base class for all relationship types
///
/// Relationships define how models are connected to each other
/// and provide methods for loading and managing related data.
abstract class Relationships<T extends Model> {
  /// Create a new relationship
  const Relationships({
    required this.localKey,
    required this.foreignKey,
    this.connection,
  });

  /// The local key (column in the current model)
  final String localKey;

  /// The foreign key (column in the related model)
  final String foreignKey;

  /// Database connection for queries
  final DatabaseConnection? connection;

  /// Load the related model(s)
  Future<T?> getRelated(Model parent);

  /// Load a list of related models
  Future<List<T>> getRelatedList(Model parent);

  /// Get the database connection to use
  DatabaseConnection _getConnection(Model parent) {
    if (connection != null) return connection!;
    if (parent is ActiveRecord) return parent.connection;
    throw StateError('No database connection available for relationship');
  }
}

/// BelongsTo relationship (many-to-one)
///
/// Used when the current model has a foreign key pointing to another model.
///
/// Example: A Post belongs to a User
/// ```dart
/// class Post extends Model {
///   Future<User?> get user => belongsTo<User>('user_id');
/// }
/// ```
class BelongsTo<T extends Model> extends Relationships<T> {
  /// Create a BelongsTo relationship
  const BelongsTo({
    required super.localKey,
    super.foreignKey = 'id',
    super.connection,
  });

  @override
  Future<T?> getRelated(Model parent) async {
    final foreignKeyValue = parent.getAttribute(localKey);
    if (foreignKeyValue == null) return null;

    final conn = _getConnection(parent);
    final instance = ModelRegistry.create<T>();

    final sql =
        'SELECT * FROM ${instance.tableName} WHERE $foreignKey = ? LIMIT 1';
    final result = await conn.execute(sql, [foreignKeyValue]);

    if (result.hasRows) {
      final model = ModelRegistry.fromJson<T>(result.firstRow!);
      if (model is ActiveRecord) {
        model.connection = conn;
      }
      return model;
    }

    return null;
  }

  @override
  Future<List<T>> getRelatedList(Model parent) async {
    final related = await getRelated(parent);
    return related != null ? [related] : [];
  }
}

/// HasOne relationship (one-to-one)
///
/// Used when the current model is referenced by another model's foreign key,
/// but only one related record is expected.
///
/// Example: A User has one Profile
/// ```dart
/// class User extends Model {
///   Future<Profile?> get profile => hasOne<Profile>('user_id');
/// }
/// ```
class HasOne<T extends Model> extends Relationships<T> {
  /// Create a HasOne relationship
  const HasOne({
    required super.foreignKey,
    super.localKey = 'id',
    super.connection,
  });

  @override
  Future<T?> getRelated(Model parent) async {
    final localKeyValue = parent.getAttribute(localKey);
    if (localKeyValue == null) return null;

    final conn = _getConnection(parent);
    final instance = ModelRegistry.create<T>();

    final sql =
        'SELECT * FROM ${instance.tableName} WHERE $foreignKey = ? LIMIT 1';
    final result = await conn.execute(sql, [localKeyValue]);

    if (result.hasRows) {
      final model = ModelRegistry.fromJson<T>(result.firstRow!);
      if (model is ActiveRecord) {
        model.connection = conn;
      }
      return model;
    }

    return null;
  }

  @override
  Future<List<T>> getRelatedList(Model parent) async {
    final related = await getRelated(parent);
    return related != null ? [related] : [];
  }
}

/// HasMany relationship (one-to-many)
///
/// Used when the current model is referenced by multiple other models.
///
/// Example: A User has many Posts
/// ```dart
/// class User extends Model {
///   Future<List<Post>> get posts => hasMany<Post>('user_id');
/// }
/// ```
class HasMany<T extends Model> extends Relationships<T> {
  /// Create a HasMany relationship
  const HasMany({
    required super.foreignKey,
    super.localKey = 'id',
    this.orderBy,
    super.connection,
  });

  /// Optional ORDER BY clause for the query
  final String? orderBy;

  @override
  Future<T?> getRelated(Model parent) async {
    final related = await getRelatedList(parent);
    return related.firstOrNull;
  }

  @override
  Future<List<T>> getRelatedList(Model parent) async {
    final localKeyValue = parent.getAttribute(localKey);
    if (localKeyValue == null) return [];

    final conn = _getConnection(parent);
    final instance = ModelRegistry.create<T>();

    String sql = 'SELECT * FROM ${instance.tableName} WHERE $foreignKey = ?';
    if (orderBy != null) {
      sql += ' ORDER BY $orderBy';
    }

    final result = await conn.execute(sql, [localKeyValue]);

    return result.rows.map((row) {
      final model = ModelRegistry.fromJson<T>(row);
      if (model is ActiveRecord) {
        model.connection = conn;
      }
      return model;
    }).toList();
  }
}

/// BelongsToMany relationship (many-to-many)
///
/// Used when models are related through a pivot table.
///
/// Example: A User belongs to many Roles through user_roles table
/// ```dart
/// class User extends Model {
///   Future<List<Role>> get roles => belongsToMany<Role>(
///     pivotTable: 'user_roles',
///     foreignPivotKey: 'user_id',
///     relatedPivotKey: 'role_id',
///   );
/// }
/// ```
class BelongsToMany<T extends Model> extends Relationships<T> {
  /// Create a BelongsToMany relationship
  const BelongsToMany({
    required this.pivotTable,
    required this.foreignPivotKey,
    required this.relatedPivotKey,
    super.localKey = 'id',
    super.foreignKey = 'id',
    this.orderBy,
    super.connection,
  });

  /// The pivot table name
  final String pivotTable;

  /// The foreign key in the pivot table referencing the parent model
  final String foreignPivotKey;

  /// The foreign key in the pivot table referencing the related model
  final String relatedPivotKey;

  /// Optional ORDER BY clause for the query
  final String? orderBy;

  @override
  Future<T?> getRelated(Model parent) async {
    final related = await getRelatedList(parent);
    return related.firstOrNull;
  }

  @override
  Future<List<T>> getRelatedList(Model parent) async {
    final localKeyValue = parent.getAttribute(localKey);
    if (localKeyValue == null) return [];

    final conn = _getConnection(parent);
    final instance = ModelRegistry.create<T>();

    String sql = '''
      SELECT ${instance.tableName}.* 
      FROM ${instance.tableName}
      INNER JOIN $pivotTable ON ${instance.tableName}.$foreignKey = $pivotTable.$relatedPivotKey
      WHERE $pivotTable.$foreignPivotKey = ?
    ''';

    if (orderBy != null) {
      sql += ' ORDER BY $orderBy';
    }

    final result = await conn.execute(sql, [localKeyValue]);

    return result.rows.map((row) {
      final model = ModelRegistry.fromJson<T>(row);
      if (model is ActiveRecord) {
        model.connection = conn;
      }
      return model;
    }).toList();
  }

  /// Attach a model to the relationship (add to pivot table)
  ///
  /// Example:
  /// ```dart
  /// final user = await User.find(1);
  /// final role = await Role.find(2);
  /// await user.roles.attach(role);
  /// ```
  Future<void> attach(
    Model parent,
    T related, {
    Map<String, Object?>? pivotData,
  }) async {
    final localKeyValue = parent.getAttribute(localKey);
    final relatedKeyValue = related.getAttribute(foreignKey);

    if (localKeyValue == null || relatedKeyValue == null) {
      throw StateError('Cannot attach models with null keys');
    }

    final conn = _getConnection(parent);

    final columns = [foreignPivotKey, relatedPivotKey];
    final values = [localKeyValue, relatedKeyValue];

    // Add any additional pivot data
    if (pivotData != null) {
      columns.addAll(pivotData.keys);
      values.addAll(pivotData.values.cast<Object>());
    }

    final placeholders = List.filled(values.length, '?').join(', ');
    final sql = '''
      INSERT INTO $pivotTable (${columns.join(', ')})
      VALUES ($placeholders)
    ''';

    await conn.execute(sql, values);
  }

  /// Detach a model from the relationship (remove from pivot table)
  ///
  /// Example:
  /// ```dart
  /// final user = await User.find(1);
  /// final role = await Role.find(2);
  /// await user.roles.detach(role);
  /// ```
  Future<void> detach(Model parent, T related) async {
    final localKeyValue = parent.getAttribute(localKey);
    final relatedKeyValue = related.getAttribute(foreignKey);

    if (localKeyValue == null || relatedKeyValue == null) {
      throw StateError('Cannot detach models with null keys');
    }

    final conn = _getConnection(parent);

    final sql = '''
      DELETE FROM $pivotTable 
      WHERE $foreignPivotKey = ? AND $relatedPivotKey = ?
    ''';

    await conn.execute(sql, [localKeyValue, relatedKeyValue]);
  }

  /// Sync the relationship (replace all existing with new ones)
  ///
  /// Example:
  /// ```dart
  /// final user = await User.find(1);
  /// final roles = [role1, role2, role3];
  /// await user.roles.sync(roles);
  /// ```
  Future<void> sync(Model parent, List<T> related) async {
    final localKeyValue = parent.getAttribute(localKey);
    if (localKeyValue == null) {
      throw StateError('Cannot sync models with null local key');
    }

    final conn = _getConnection(parent);

    // Start transaction
    final transaction = await conn.beginTransaction();
    if (transaction == null) {
      throw StateError('Database does not support transactions');
    }

    try {
      // Remove all existing relationships
      await transaction.execute(
        'DELETE FROM $pivotTable WHERE $foreignPivotKey = ?',
        [localKeyValue],
      );

      // Add new relationships
      for (final model in related) {
        final relatedKeyValue = model.getAttribute(foreignKey);
        if (relatedKeyValue != null) {
          await transaction.execute(
            'INSERT INTO $pivotTable ($foreignPivotKey, $relatedPivotKey) VALUES (?, ?)',
            [localKeyValue, relatedKeyValue],
          );
        }
      }

      await transaction.commit();
    } catch (e) {
      await transaction.rollback();
      rethrow;
    }
  }
}
