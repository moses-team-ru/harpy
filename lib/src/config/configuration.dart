import 'dart:convert';
import 'dart:io';

/// Configuration management for Harpy applications
///
/// Supports loading configuration from environment variables, JSON files,
/// and YAML files with a flexible fallback system.
class Configuration {
  /// Create configuration from a JSON file
  factory Configuration.fromJsonFile(String filePath) {
    final Configuration config = Configuration._()
      .._loadFromJsonFile(filePath)
      .._loadFromEnvironment(); // Environment variables override file values
    return config;
  }

  /// Create configuration from environment variables only
  factory Configuration.fromEnvironment() {
    final Configuration config = Configuration._().._loadFromEnvironment();
    return config;
  }

  /// Create configuration from a map
  factory Configuration.fromMap(Map<String, Object?> data) {
    final Configuration config = Configuration._();
    config._config.addAll(data);
    config
        ._loadFromEnvironment(); // Environment variables override provided values
    return config;
  }

  Configuration._();
  final Map<String, Object?> _config = <String, Object?>{};

  /// Get a configuration value by key
  Object? get<T>(String key, [T? defaultValue]) {
    final Object? value = _getValue(key);

    if (value == null) {
      return defaultValue;
    }

    // Type conversion
    if (T == String) {
      return value.toString() as T;
    } else if (T == int) {
      if (value is int) return value as T;
      if (value is String) {
        final int? parsed = int.tryParse(value);
        return parsed as T?;
      }
    } else if (T == double) {
      if (value is double) return value as T;
      if (value is num) return value.toDouble() as T;
      if (value is String) {
        final double? parsed = double.tryParse(value);
        return parsed as T?;
      }
    } else if (T == bool) {
      if (value is bool) return value as T;
      if (value is String) {
        final String lower = value.toLowerCase();
        if (lower == 'true' || lower == '1' || lower == 'yes') {
          return true as T;
        }
        if (lower == 'false' || lower == '0' || lower == 'no') {
          return false as T;
        }
      }
    }

    // Return as-is if no conversion needed
    if (value is T) return value;

    return defaultValue;
  }

  /// Get a required configuration value (throws if not found)
  Object getRequired<T>(String key) {
    final Object? value = get<T>(key);
    if (value == null) {
      throw ConfigurationException(
        'Required configuration key "$key" not found',
      );
    }
    return value;
  }

  /// Check if a configuration key exists
  bool has(String key) => _getValue(key) != null;

  /// Set a configuration value
  void set(String key, Object? value) {
    if (key.isEmpty) {
      throw ArgumentError('Configuration key cannot be empty');
    }
    if (key.contains('..')) {
      throw ArgumentError(
        'Configuration key cannot contain consecutive dots: $key',
      );
    }
    _setNestedValue(_config, key, value);
  }

  /// Get all configuration as a map
  Map<String, Object?> toMap() => Map<String, Object?>.of(_config);

  /// Load configuration from environment variables
  void _loadFromEnvironment() {
    final Map<String, String> env = Platform.environment;

    for (final MapEntry<String, String> entry in env.entries) {
      final String key = entry.key.toLowerCase();
      final String value = entry.value;

      // Convert common naming conventions
      // Replace underscores with dots but avoid consecutive dots
      final String normalizedKey = key.replaceAll(RegExp('_+'), '.');

      // Try to parse as JSON if it looks like structured data
      if (value.startsWith('{') || value.startsWith('[')) {
        try {
          final String cleanKey = normalizedKey.replaceAll(RegExp(r'\.+'), '.');
          if (!cleanKey.contains('..')) {
            final parsed = jsonDecode(value);
            set(cleanKey, parsed);
          }
          continue;
        } on Exception catch (e) {
          print(
            'Warning: Failed to parse environment variable "$key" as JSON: $e',
          );
        }
      }

      // Clean up key to avoid consecutive dots and store as string
      final String cleanKey = normalizedKey.replaceAll(RegExp(r'\.+'), '.');
      if (!cleanKey.contains('..')) {
        set(cleanKey, value);
      }
    }
  }

  /// Load configuration from JSON file
  void _loadFromJsonFile(String filePath) {
    try {
      final File file = File(filePath);
      if (!file.existsSync()) {
        throw ConfigurationException('Configuration file not found: $filePath');
      }

      final String content = file.readAsStringSync();
      final Map<String, Object?> data =
          (jsonDecode(content) as Map<String, dynamic>).cast<String, Object?>();
      _config.addAll(data);
    } catch (e, st) {
      Error.throwWithStackTrace(
        ConfigurationException(
          'Failed to load configuration from $filePath: $e',
        ),
        st,
      );
    }
  }

  /// Get a value by key, supporting nested keys with dot notation
  Object? _getValue(String key) {
    if (key.contains('.')) {
      final List<String> parts = key.split('.');
      Object? current = _config;

      for (final String part in parts) {
        if (current is Map<String, Object?> && current.containsKey(part)) {
          current = current[part];
        } else {
          return null;
        }
      }

      return current;
    }

    return _config[key];
  }

  /// Set a nested value using dot notation
  void _setNestedValue(Map<String, Object?> map, String key, Object? value) {
    if (key.contains('.')) {
      final List<String> parts = key.split('.');
      final String lastKey = parts.removeLast();

      Map<String, Object?> current = map;
      for (final String part in parts) {
        if (!current.containsKey(part) ||
            current[part] is! Map<String, Object?>) {
          current[part] = <String, Object?>{};
        }
        // ignore: cast_nullable_to_non_nullable
        current = current[part] as Map<String, Object?>;
      }

      current[lastKey] = value;
    } else {
      map[key] = value;
    }
  }

  /// Print all configuration (for debugging)
  void printConfig() {
    print('Configuration:');
    _printMap(_config, '  ');
  }

  void _printMap(Map<String, Object?> map, String indent) {
    for (final MapEntry<String, Object?> entry in map.entries) {
      final String key = entry.key;
      final Object? value = entry.value;

      if (value is Map<String, Object?>) {
        print('$indent$key:');
        _printMap(value, '$indent  ');
      } else {
        // Hide sensitive values
        final String displayValue =
            _isSensitiveKey(key) ? '[HIDDEN]' : value.toString();
        print('$indent$key: $displayValue');
      }
    }
  }

  bool _isSensitiveKey(String key) {
    final String lower = key.toLowerCase();
    return lower.contains('password') ||
        lower.contains('secret') ||
        lower.contains('key') ||
        lower.contains('token') ||
        lower.contains('auth');
  }
}

/// Common configuration keys as constants
class ConfigKeys {
  /// Common configuration keys
  static const String port = 'port';

  /// Common configuration keys
  static const String host = 'host';

  /// Common configuration keys
  static const String environment = 'environment';

  /// Common configuration keys
  static const String logLevel = 'log.level';

  /// Common configuration keys
  static const String dbUrl = 'database.url';

  /// Common configuration keys
  static const String jwtSecret = 'jwt.secret';

  /// Common configuration keys
  static const String corsOrigin = 'cors.origin';

  /// Common configuration keys
  static const String tlsCert = 'tls.cert';

  /// Common configuration keys
  static const String tlsKey = 'tls.key';
}

/// Exception thrown when configuration operations fail
class ConfigurationException implements Exception {
  /// Creates a new [ConfigurationException] with the given [message].
  /// [ConfigurationException] is thrown when configuration operations fail.
  /// [message] - The error message describing the exception.
  const ConfigurationException(this.message);

  /// The error message describing the exception.
  final String message;

  @override
  String toString() => 'ConfigurationException: $message';
}
