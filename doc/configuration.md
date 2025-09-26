# Configuration System

Harpy provides a flexible and powerful configuration management system that supports multiple sources and automatic type conversion. The configuration system is designed to work seamlessly across development, testing, and production environments.

## 🎯 Overview

The configuration system supports:
- **Environment variables** - Perfect for production deployments
- **JSON configuration files** - Great for development and staging
- **Programmatic configuration** - Ideal for testing and dynamic setups
- **Hierarchical fallback** - Environment variables override file settings
- **Type conversion** - Automatic conversion between string, int, double, and bool
- **Nested keys** - Support for dot notation (e.g., `database.host`)

## 🚀 Quick Start

### Environment-based Configuration

```dart
import 'package:harpy/harpy.dart';

void main() async {
  // Load configuration from environment variables
  final app = Harpy(); // Uses Configuration.fromEnvironment() by default
  
  // Access configuration values
  final port = app.config.get<int>('port', 3000);
  final dbUrl = app.config.get<String>('database.url');
  
  await app.listen(port: port);
}
```

### JSON File Configuration

```dart
// config.json
{
  "port": 8080,
  "host": "localhost",
  "database": {
    "type": "postgresql",
    "host": "localhost",
    "port": 5432,
    "database": "myapp",
    "username": "user",
    "password": "password"
  },
  "jwt": {
    "secret": "your-secret-key",
    "expiresIn": "24h"
  },
  "cors": {
    "origin": "*",
    "credentials": true
  }
}
```

```dart
// Load from JSON file
final config = Configuration.fromJsonFile('config.json');
final app = Harpy(config: config);

// Access nested values
final dbHost = app.config.get<String>('database.host');
final jwtSecret = app.config.getRequired<String>('jwt.secret');
```

### Programmatic Configuration

```dart
final config = Configuration.fromMap({
  'port': 8080,
  'database': {
    'type': 'sqlite',
    'path': './app.db',
  },
  'features': {
    'enableCaching': true,
    'maxRequestSize': '10MB',
  }
});

final app = Harpy(config: config);
```

## 🔧 Configuration Sources

### Environment Variables

Environment variables are automatically loaded and normalized:

```bash
# Set environment variables
export PORT=8080
export DATABASE_TYPE=postgresql
export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export JWT_SECRET=your-secret-key
export CORS_ORIGIN=https://myapp.com
```

```dart
final app = Harpy(); // Automatically loads environment variables

// Access values (underscores become dots)
final port = app.config.get<int>('port');
final dbType = app.config.get<String>('database.type');
final dbHost = app.config.get<String>('database.host');
```

### JSON Configuration Files

```dart
// Load from specific file
final config = Configuration.fromJsonFile('config/production.json');

// Environment variables still override file values
final app = Harpy(config: config);
```

### Hierarchical Configuration

Configuration sources have the following priority (highest to lowest):
1. **Environment variables** (highest priority)
2. **JSON file values**
3. **Programmatic values**
4. **Default values** (lowest priority)

```dart
// config.json has port: 3000
// Environment has PORT=8080
final config = Configuration.fromJsonFile('config.json');
final app = Harpy(config: config);

final port = app.config.get<int>('port'); // Returns 8080 (from environment)
```

## 📖 API Reference

### Configuration Class

#### Factory Constructors

```dart
// From environment variables only
final config = Configuration.fromEnvironment();

// From JSON file (with environment override)
final config = Configuration.fromJsonFile('config.json');

// From map (with environment override)
final config = Configuration.fromMap({
  'key': 'value',
  'nested': {'key': 'value'}
});
```

#### Getting Values

```dart
// Get with type conversion and default
T? get<T>(String key, [T? defaultValue])

// Get required value (throws if missing)
T getRequired<T>(String key)

// Check if key exists
bool has(String key)
```

#### Setting Values

```dart
// Set a configuration value
void set(String key, Object? value)

// Get all configuration as map
Map<String, Object?> toMap()
```

### Type Conversion

The configuration system automatically converts between types:

```dart
// Environment: PORT=8080 (string)
final port = config.get<int>('port'); // Returns 8080 (int)

// Environment: ENABLE_CACHE=true
final cacheEnabled = config.get<bool>('enable.cache'); // Returns true (bool)

// Environment: TIMEOUT=30.5
final timeout = config.get<double>('timeout'); // Returns 30.5 (double)
```

Supported conversions:
- **String → int**: Uses `int.tryParse()`
- **String → double**: Uses `double.tryParse()`
- **String → bool**: Recognizes `true/1/yes` and `false/0/no` (case-insensitive)
- **Any → String**: Uses `toString()`

### Nested Keys

Use dot notation to access nested configuration:

```dart
{
  "database": {
    "connection": {
      "host": "localhost",
      "port": 5432
    }
  }
}
```

```dart
final host = config.get<String>('database.connection.host');
final port = config.get<int>('database.connection.port');
```

## 🔑 Common Configuration Keys

Harpy provides predefined constants for common configuration keys:

```dart
import 'package:harpy/harpy.dart';

// Use predefined constants
final port = config.get<int>(ConfigKeys.port, 3000);
final host = config.get<String>(ConfigKeys.host, 'localhost');
final dbUrl = config.get<String>(ConfigKeys.dbUrl);
final jwtSecret = config.getRequired<String>(ConfigKeys.jwtSecret);
```

Available constants:
- `ConfigKeys.port` - Server port
- `ConfigKeys.host` - Server host
- `ConfigKeys.environment` - Environment name
- `ConfigKeys.logLevel` - Logging level
- `ConfigKeys.dbUrl` - Database URL
- `ConfigKeys.jwtSecret` - JWT secret key
- `ConfigKeys.corsOrigin` - CORS origin
- `ConfigKeys.tlsCert` - TLS certificate path
- `ConfigKeys.tlsKey` - TLS key path

## 🌍 Environment-specific Configuration

### Development

```dart
// config/development.json
{
  "port": 3000,
  "database": {
    "type": "sqlite",
    "path": "./dev.db"
  },
  "jwt": {
    "secret": "dev-secret"
  },
  "logging": {
    "level": "debug",
    "logBody": true
  }
}
```

### Production

```bash
# Production environment variables
export NODE_ENV=production
export PORT=80
export DATABASE_TYPE=postgresql
export DATABASE_URL=postgres://user:pass@prod-db:5432/myapp
export JWT_SECRET=super-secure-secret
export LOG_LEVEL=warn
```

### Environment Detection

```dart
final env = config.get<String>('environment', 'development');
final isProduction = env == 'production';
final isDevelopment = env == 'development';

if (isProduction) {
  // Production-specific setup
  app.enableAuth(jwtSecret: config.getRequired('jwt.secret'));
} else {
  // Development-specific setup
  app.enableLogging(logBody: true);
}
```

## 🔒 Security Considerations

### Sensitive Values

The configuration system automatically hides sensitive values when printing:

```dart
config.printConfig(); // Hides passwords, secrets, keys, tokens
```

Hidden keys (case-insensitive):
- `password`
- `secret` 
- `key`
- `token`
- `auth`

### Best Practices

1. **Never commit secrets** to version control
2. **Use environment variables** for production secrets
3. **Validate required configuration** at startup
4. **Use different configurations** for each environment

```dart
// Validate required configuration at startup
void validateConfig(Configuration config) {
  try {
    config.getRequired<String>('jwt.secret');
    config.getRequired<String>('database.url');
  } on ConfigurationException catch (e) {
    print('Configuration error: $e');
    exit(1);
  }
}
```

## 📝 Configuration Examples

### Web API Configuration

```json
{
  "server": {
    "port": 8080,
    "host": "0.0.0.0",
    "timeout": 30
  },
  "database": {
    "type": "postgresql",
    "host": "localhost",
    "port": 5432,
    "database": "api_db",
    "username": "api_user",
    "password": "secure_password",
    "poolSize": 10
  },
  "auth": {
    "jwtSecret": "your-jwt-secret",
    "tokenExpiry": "24h",
    "refreshTokenExpiry": "30d"
  },
  "cors": {
    "origin": ["https://myapp.com", "https://admin.myapp.com"],
    "methods": ["GET", "POST", "PUT", "DELETE"],
    "credentials": true
  },
  "logging": {
    "level": "info",
    "logRequests": true,
    "logResponses": false
  }
}
```

### Microservice Configuration

```json
{
  "service": {
    "name": "user-service",
    "version": "1.0.0",
    "port": 3001
  },
  "database": {
    "type": "mongodb",
    "host": "mongo-cluster",
    "port": 27017,
    "database": "users"
  },
  "redis": {
    "host": "redis-cache",
    "port": 6379,
    "ttl": 3600
  },
  "monitoring": {
    "enabled": true,
    "metricsPort": 9090,
    "healthCheckInterval": 30
  }
}
```

## 🐛 Error Handling

### Configuration Exceptions

```dart
try {
  final requiredValue = config.getRequired<String>('missing.key');
} on ConfigurationException catch (e) {
  print('Configuration error: ${e.message}');
  // Handle missing configuration
}
```

### Validation

```dart
// Validate configuration on startup
void main() async {
  final config = Configuration.fromEnvironment();
  
  // Validate required keys
  final requiredKeys = [
    'database.url',
    'jwt.secret',
    'server.port'
  ];
  
  for (final key in requiredKeys) {
    if (!config.has(key)) {
      throw ConfigurationException('Missing required configuration: $key');
    }
  }
  
  final app = Harpy(config: config);
  await app.listen();
}
```

## 🔗 Related Documentation

- **[Framework Overview](harpy_framework.md)** - Using configuration with Harpy
- **[Database System](database.md)** - Database configuration
- **[Authentication](authentication.md)** - JWT configuration
- **[Deployment](deployment.md)** - Production configuration
- **[Server Implementation](server.md)** - Server configuration

---

The configuration system provides a solid foundation for managing application settings across all environments. Next, explore the [Database System](database.md) to learn about data persistence.