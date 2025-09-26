# Middleware System

Harpy's middleware system provides a powerful way to add cross-cutting functionality to your application. Based on the Shelf middleware architecture, it allows you to process requests and responses at various stages of the HTTP pipeline.

## 🎯 Overview

Middleware in Harpy allows you to:
- **Authenticate requests** - JWT, Basic Auth, API keys
- **Log requests and responses** - Comprehensive logging
- **Handle CORS** - Cross-origin resource sharing
- **Validate input** - Request validation and sanitization  
- **Rate limiting** - Prevent abuse and DoS attacks
- **Error handling** - Centralized error processing
- **Database connections** - Automatic connection management

## 🚀 Built-in Middleware

### CORS Middleware

```dart
// Basic CORS
app.enableCors();

// Custom CORS configuration
app.enableCors(
  origin: 'https://myapp.com',
  allowedMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
  maxAge: 86400, // Preflight cache duration
);

// Multiple origins
app.enableCors(
  origin: ['https://app.com', 'https://admin.app.com'],
  credentials: true,
);

// Dynamic origin
app.enableCors(
  origin: (origin) => origin?.endsWith('.myapp.com') ?? false,
);
```

### Authentication Middleware

```dart
// JWT Authentication
app.enableAuth(
  jwtSecret: 'your-secret-key',
  excludePaths: ['/login', '/register', '/health'],
  algorithm: 'HS256',
);

// Custom JWT configuration
app.enableAuth(
  jwtSecret: 'your-secret',
  issuer: 'myapp.com',
  audience: 'api.myapp.com',
  expiresIn: Duration(hours: 24),
  refreshExpiresIn: Duration(days: 30),
);

// Basic Authentication
app.enableBasicAuth(
  realm: 'Admin Panel',
  validator: (username, password) async {
    return await validateCredentials(username, password);
  },
);

// API Key Authentication
app.enableApiKeyAuth(
  header: 'X-API-Key',
  validator: (apiKey) async {
    return await validateApiKey(apiKey);
  },
);
```

### Logging Middleware

```dart
// Basic logging
app.enableLogging();

// Detailed logging
app.enableLogging(
  logBody: true,        // Log request/response bodies
  logHeaders: true,     // Log headers
  logTiming: true,      // Log response times
  logLevel: 'debug',    // Log level
);

// Custom logger
app.enableLogging(
  logger: (message, isError) {
    if (isError) {
      stderr.writeln('ERROR: $message');
    } else {
      print('INFO: $message');
    }
  },
);
```

### Database Middleware

```dart
// Automatic database connection
app.enableDatabase(
  type: 'postgresql',
  host: 'localhost',
  database: 'myapp',
  username: 'user',
  password: 'password',
);

// Connection available in handlers
app.get('/users', (req, res) async {
  final users = await req.database.execute('SELECT * FROM users');
  return res.json({'users': users.rows});
});
```

## 🔧 Custom Middleware

### Basic Custom Middleware

```dart
shelf.Middleware customMiddleware() {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      // Pre-processing
      print('Before: ${request.method} ${request.url}');
      
      // Call next middleware/handler
      final response = await innerHandler(request);
      
      // Post-processing
      print('After: ${response.statusCode}');
      
      return response;
    };
  };
}

// Apply middleware
app.use(customMiddleware());
```

### Request Timing Middleware

```dart
shelf.Middleware timingMiddleware() {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      final stopwatch = Stopwatch()..start();
      
      try {
        final response = await innerHandler(request);
        stopwatch.stop();
        
        return response.change(headers: {
          'X-Response-Time': '${stopwatch.elapsedMilliseconds}ms',
        });
      } catch (e) {
        stopwatch.stop();
        print('Request failed after ${stopwatch.elapsedMilliseconds}ms: $e');
        rethrow;
      }
    };
  };
}
```

### Rate Limiting Middleware

```dart
class RateLimiter {
  final Map<String, List<DateTime>> _requests = {};
  final int maxRequests;
  final Duration window;
  
  RateLimiter({this.maxRequests = 100, this.window = const Duration(hours: 1)});
  
  shelf.Middleware middleware() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        final clientIp = request.headers['x-forwarded-for'] ?? 
                        request.headers['remote-addr'] ?? 'unknown';
        
        final now = DateTime.now();
        final requests = _requests[clientIp] ?? [];
        
        // Remove old requests
        requests.removeWhere((time) => now.difference(time) > window);
        
        if (requests.length >= maxRequests) {
          return shelf.Response(429, body: jsonEncode({
            'error': 'Rate limit exceeded',
            'retryAfter': window.inSeconds,
          }), headers: {'content-type': 'application/json'});
        }
        
        requests.add(now);
        _requests[clientIp] = requests;
        
        final response = await innerHandler(request);
        return response.change(headers: {
          'X-RateLimit-Limit': '$maxRequests',
          'X-RateLimit-Remaining': '${maxRequests - requests.length}',
          'X-RateLimit-Reset': '${now.add(window).millisecondsSinceEpoch}',
        });
      };
    };
  }
}

// Usage
final rateLimiter = RateLimiter(maxRequests: 1000, window: Duration(hours: 1));
app.use(rateLimiter.middleware());
```

### Request Validation Middleware

```dart
shelf.Middleware validateJsonSchema(Map<String, dynamic> schema) {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      if (request.method == 'POST' || request.method == 'PUT') {
        try {
          final body = await request.readAsString();
          final json = jsonDecode(body);
          
          // Simple validation
          for (final entry in schema.entries) {
            final field = entry.key;
            final type = entry.value;
            
            if (!json.containsKey(field)) {
              return shelf.Response.badRequest(
                body: jsonEncode({'error': 'Missing field: $field'}),
                headers: {'content-type': 'application/json'},
              );
            }
            
            if (type == String && json[field] is! String) {
              return shelf.Response.badRequest(
                body: jsonEncode({'error': '$field must be a string'}),
                headers: {'content-type': 'application/json'},
              );
            }
          }
          
          // Create new request with parsed body
          final newRequest = request.change(body: body);
          return await innerHandler(newRequest);
          
        } catch (e) {
          return shelf.Response.badRequest(
            body: jsonEncode({'error': 'Invalid JSON'}),
            headers: {'content-type': 'application/json'},
          );
        }
      }
      
      return await innerHandler(request);
    };
  };
}

// Usage
app.use(validateJsonSchema({'name': String, 'email': String}));
```

## 🛡️ Security Middleware

### Security Headers Middleware

```dart
shelf.Middleware securityHeaders() {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      final response = await innerHandler(request);
      
      return response.change(headers: {
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'X-XSS-Protection': '1; mode=block',
        'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
        'Referrer-Policy': 'strict-origin-when-cross-origin',
        'Content-Security-Policy': "default-src 'self'",
      });
    };
  };
}

app.use(securityHeaders());
```

### Input Sanitization Middleware

```dart
shelf.Middleware sanitizeInput() {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      if (request.method == 'POST' || request.method == 'PUT') {
        final body = await request.readAsString();
        
        try {
          final json = jsonDecode(body);
          final sanitized = sanitizeObject(json);
          
          final newRequest = request.change(body: jsonEncode(sanitized));
          return await innerHandler(newRequest);
        } catch (e) {
          // Not JSON, pass through
        }
      }
      
      return await innerHandler(request);
    };
  };
}

dynamic sanitizeObject(dynamic obj) {
  if (obj is String) {
    return obj
      .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
      .replaceAll(RegExp(r'[<>"\']'), ''); // Remove dangerous characters
  } else if (obj is Map) {
    return obj.map((key, value) => MapEntry(key, sanitizeObject(value)));
  } else if (obj is List) {
    return obj.map(sanitizeObject).toList();
  }
  return obj;
}
```

## 📊 Monitoring Middleware

### Request Metrics Middleware

```dart
class RequestMetrics {
  int _totalRequests = 0;
  int _errorCount = 0;
  final Map<String, int> _statusCounts = {};
  final Map<String, List<int>> _responseTimes = {};
  
  shelf.Middleware middleware() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        final stopwatch = Stopwatch()..start();
        _totalRequests++;
        
        try {
          final response = await innerHandler(request);
          stopwatch.stop();
          
          final statusCode = response.statusCode.toString();
          _statusCounts[statusCode] = (_statusCounts[statusCode] ?? 0) + 1;
          
          final path = request.url.path;
          _responseTimes[path] = (_responseTimes[path] ?? [])
            ..add(stopwatch.elapsedMilliseconds);
          
          if (response.statusCode >= 400) {
            _errorCount++;
          }
          
          return response;
        } catch (e) {
          stopwatch.stop();
          _errorCount++;
          rethrow;
        }
      };
    };
  }
  
  Map<String, dynamic> getMetrics() {
    return {
      'totalRequests': _totalRequests,
      'errorCount': _errorCount,
      'errorRate': _totalRequests > 0 ? _errorCount / _totalRequests : 0,
      'statusCounts': _statusCounts,
      'averageResponseTimes': _responseTimes.map((path, times) {
        final avg = times.reduce((a, b) => a + b) / times.length;
        return MapEntry(path, avg);
      }),
    };
  }
}

final metrics = RequestMetrics();
app.use(metrics.middleware());

app.get('/metrics', (req, res) {
  return res.json(metrics.getMetrics());
});
```

## 🔄 Middleware Composition

### Middleware Pipeline

```dart
void setupMiddleware(Harpy app) {
  // Order matters! Middleware is applied in the order they're added
  
  // 1. Security first
  app.use(securityHeaders());
  
  // 2. Request timing
  app.use(timingMiddleware());
  
  // 3. Rate limiting
  app.use(rateLimiter.middleware());
  
  // 4. CORS
  app.enableCors();
  
  // 5. Authentication (after CORS for preflight)
  app.enableAuth(jwtSecret: 'secret');
  
  // 6. Logging (after auth for user context)
  app.enableLogging();
  
  // 7. Request validation
  app.use(validateInput());
  
  // 8. Database connection
  app.enableDatabase();
}
```

### Conditional Middleware

```dart
shelf.Middleware conditionalMiddleware(bool condition, shelf.Middleware middleware) {
  if (condition) {
    return middleware;
  } else {
    return (shelf.Handler innerHandler) => innerHandler;
  }
}

// Apply middleware based on environment
final isDevelopment = app.config.get<String>('environment') == 'development';
app.use(conditionalMiddleware(isDevelopment, debugMiddleware()));
```

### Route-specific Middleware

```dart
// Apply to specific routes
app.get('/admin/dashboard', 
  [authMiddleware(), adminMiddleware()], 
  dashboardHandler
);

// Apply to router
final adminRouter = Router();
adminRouter.use(authMiddleware());
adminRouter.use(adminMiddleware());
adminRouter.get('/users', getUsersHandler);
app.mount('/admin', adminRouter);
```

## 🧪 Testing Middleware

### Middleware Testing

```dart
import 'package:test/test.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_test_handler/shelf_test_handler.dart';

void main() {
  group('Middleware Tests', () {
    test('should add timing header', () async {
      final handler = const shelf.Pipeline()
        .addMiddleware(timingMiddleware())
        .addHandler((request) => shelf.Response.ok('OK'));
      
      final response = await makeRequest(handler, 'GET', '/test');
      
      expect(response.headers['x-response-time'], isNotNull);
      expect(response.headers['x-response-time'], matches(RegExp(r'\d+ms')));
    });
    
    test('should handle rate limiting', () async {
      final rateLimiter = RateLimiter(maxRequests: 2, window: Duration(minutes: 1));
      final handler = const shelf.Pipeline()
        .addMiddleware(rateLimiter.middleware())
        .addHandler((request) => shelf.Response.ok('OK'));
      
      // First two requests should succeed
      expect((await makeRequest(handler, 'GET', '/test')).statusCode, equals(200));
      expect((await makeRequest(handler, 'GET', '/test')).statusCode, equals(200));
      
      // Third request should be rate limited
      expect((await makeRequest(handler, 'GET', '/test')).statusCode, equals(429));
    });
  });
}
```

## 🔗 Related Documentation

- **[HTTP Components](http.md)** - Request and Response objects
- **[Routing System](routing.md)** - Route-specific middleware
- **[Authentication](authentication.md)** - Authentication middleware details
- **[Configuration](configuration.md)** - Middleware configuration
- **[Security](security.md)** - Security middleware patterns

---

The middleware system provides a powerful way to add functionality across your entire application or specific routes. Next, explore the [Server Implementation](server.md) to understand how all components work together.