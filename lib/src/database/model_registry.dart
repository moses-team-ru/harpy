/// Model registry system for automatic model construction
///
/// This system allows models to register their constructors for use
/// in various ORM operations like copyWith, relationships, and code generation.
library;

import 'package:harpy/src/database/model.dart';

/// Type definition for model constructor function
typedef ModelConstructor<T extends Model> = T Function();

/// Registry for model constructors to enable automatic instantiation
///
/// Models can register their constructors to enable features like:
/// - copyWith() method with proper type preservation
/// - Relationship loading with automatic model creation
/// - Dynamic model creation from JSON
/// - Code generation support
class ModelRegistry {
  /// Private constructor to prevent instantiation
  const ModelRegistry._();

  /// Storage for registered model constructors
  static final Map<Type, ModelConstructor> _constructors = {};

  /// Register a model constructor for a specific model type
  ///
  /// This should be called during model class initialization:
  /// ```dart
  /// class User extends Model {
  ///   static final _registry = ModelRegistry.register<User>(() => User());
  ///   // ... rest of model
  /// }
  /// ```
  static void register<T extends Model>(ModelConstructor<T> constructor) {
    _constructors[T] = constructor;
  }

  /// Create a new instance of a registered model type
  ///
  /// Throws [ModelNotRegisteredException] if the model type is not registered.
  ///
  /// Usage:
  /// ```dart
  /// final user = ModelRegistry.create<User>();
  /// ```
  static T create<T extends Model>() {
    final constructor = _constructors[T] as ModelConstructor<T>?;
    if (constructor == null) {
      throw ModelNotRegisteredException(
        'Model type $T is not registered. '
        'Call ModelRegistry.register<$T>(() => $T()) in the model class.',
      );
    }
    return constructor();
  }

  /// Check if a model type is registered
  ///
  /// Useful for conditional logic or debugging:
  /// ```dart
  /// if (ModelRegistry.isRegistered<User>()) {
  ///   final user = ModelRegistry.create<User>();
  /// }
  /// ```
  static bool isRegistered<T extends Model>() => _constructors.containsKey(T);

  /// Get all registered model types
  ///
  /// Useful for debugging or introspection:
  /// ```dart
  /// final types = ModelRegistry.getRegisteredTypes();
  /// print('Registered models: $types');
  /// ```
  static Set<Type> getRegisteredTypes() => Set.unmodifiable(_constructors.keys);

  /// Clear all registered models
  ///
  /// Primarily for testing purposes:
  /// ```dart
  /// void tearDown() {
  ///   ModelRegistry.clear();
  /// }
  /// ```
  static void clear() {
    _constructors.clear();
  }

  /// Get the constructor function for a specific type
  ///
  /// Returns null if the type is not registered.
  /// Used internally by the ORM system.
  static ModelConstructor<T>? getConstructor<T extends Model>() =>
      _constructors[T] as ModelConstructor<T>?;

  /// Create a model instance from JSON with automatic type detection
  ///
  /// This method creates a model instance and populates it with JSON data:
  /// ```dart
  /// final user = ModelRegistry.fromJson<User>({
  ///   'id': 1,
  ///   'name': 'John Doe',
  ///   'email': 'john@example.com'
  /// });
  /// ```
  static T fromJson<T extends Model>(Map<String, Object?> json) {
    final model = create<T>()..fillAttributes(json);
    if (json.containsKey(model.primaryKey) && json[model.primaryKey] != null) {
      model.markAsExisting(); // ignore: cascade_invocations
    }
    return model;
  }

  /// Create multiple model instances from a list of JSON objects
  ///
  /// Convenient for bulk operations:
  /// ```dart
  /// final users = ModelRegistry.fromJsonList<User>([
  ///   {'id': 1, 'name': 'John'},
  ///   {'id': 2, 'name': 'Jane'},
  /// ]);
  /// ```
  static List<T> fromJsonList<T extends Model>(
    List<Map<String, Object?>> jsonList,
  ) =>
      jsonList.map((json) => fromJson<T>(json)).toList();
}

/// Exception thrown when trying to create an unregistered model
class ModelNotRegisteredException implements Exception {
  /// Create a new exception with the given message
  const ModelNotRegisteredException(this.message);

  /// The error message
  final String message;

  @override
  String toString() => 'ModelNotRegisteredException: $message';
}
