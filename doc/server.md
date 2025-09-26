# Server Implementation

Harpy's server implementation provides a robust foundation for building production-ready APIs. Built on top of Dart's `shelf` package and `HttpServer`, it offers excellent performance, flexibility, and enterprise-grade features.

## 🎯 Overview

Key features of Harpy server:
- **High Performance** - Built on Dart's efficient HTTP server
- **HTTPS Support** - Built-in TLS/SSL configuration
- **Graceful Shutdown** - Proper cleanup and connection draining
- **Health Checks** - Application health monitoring
- **Process Management** - Signal handling and lifecycle management
- **Connection Pooling** - Efficient resource management
- **Request/Response Streaming** - Handle large payloads efficiently

## 🚀 Basic Server Setup

### Simple HTTP Server

```dart
import 'package:harpy/harpy.dart';

void main() async {
  final app = Harpy();
  
  app.get('/', (req, res) => res.json({'message': 'Hello World'}));
  
  // Start server on default port 3000
  await app.listen();
  print('🚀 Server running on http://localhost:3000');
}
```

### Custom Host and Port

```dart
void main() async {
  final app = Harpy();
  
  // Configure routes
  setupRoutes(app);
  
  // Start server with custom configuration
  await app.listen(
    host: '0.0.0.0',    // Listen on all interfaces
    port: 8080,         // Custom port
  );
  
  print('🚀 Server running on http://0.0.0.0:8080');
}
```

### Environment-based Configuration

```dart
void main() async {
  final config = Configuration.fromEnvironment();
  final app = Harpy(config: config);
  
  setupRoutes(app);
  
  final host = config.get<String>('host', 'localhost');
  final port = config.get<int>('port', 3000);
  
  await app.listen(host: host, port: port);
  print('🚀 Server running on http://$host:$port');
}
```

## 🔒 HTTPS Configuration

### Basic HTTPS Setup

```dart
import 'dart:io';

void main() async {
  final app = Harpy();
  setupRoutes(app);
  
  // Configure SSL context
  final context = SecurityContext()
    ..useCertificateChain('server.crt')
    ..usePrivateKey('server.key', password: 'key-password');
  
  await app.listen(
    host: 'localhost',
    port: 443,
    securityContext: context,
  );
  
  print('🔒 HTTPS server running on https://localhost:443');
}
```

### Let's Encrypt Integration

```dart
void main() async {
  final config = Configuration.fromEnvironment();
  final app = Harpy(config: config);
  
  setupRoutes(app);
  
  // Production HTTPS configuration
  if (config.get<bool>('https.enabled', false)) {
    final context = SecurityContext()
      ..useCertificateChain(config.getRequired('https.certFile'))
      ..usePrivateKey(config.getRequired('https.keyFile'));
    
    await app.listen(
      host: '0.0.0.0',
      port: 443,
      securityContext: context,
    );
    
    print('🔒 HTTPS server running on port 443');
  } else {
    await app.listen(host: 'localhost', port: 3000);
    print('🚀 HTTP server running on port 3000');
  }
}
```

### Redirect HTTP to HTTPS

```dart
void startHttpsServer() async {
  final app = Harpy();
  setupRoutes(app);
  
  // HTTPS server
  final secureContext = SecurityContext()
    ..useCertificateChain('server.crt')
    ..usePrivateKey('server.key');
  
  await app.listen(
    port: 443,
    securityContext: secureContext,
  );
  
  // HTTP redirect server
  final redirectApp = Harpy();
  redirectApp.get('/*', (req, res) {
    final httpsUrl = 'https://${req.headers['host']}${req.path}';
    return res.redirect(httpsUrl, permanent: true);
  });
  
  await redirectApp.listen(port: 80);
  
  print('🔒 HTTPS server running on port 443');
  print('↗️ HTTP redirect server running on port 80');
}
```

## 🔄 Server Lifecycle Management

### Graceful Shutdown

```dart
import 'dart:io';

void main() async {
  final app = Harpy();
  setupRoutes(app);
  
  late HarpyServer server;
  
  // Start server
  server = await app.listen(port: 3000);
  print('🚀 Server running on port 3000');
  
  // Handle shutdown signals
  ProcessSignal.sigint.watch().listen((_) async {
    print('📥 Received SIGINT, shutting down gracefully...');
    
    // Stop accepting new connections
    await server.close();
    
    // Close database connections
    await closeDatabaseConnections();
    
    // Other cleanup tasks
    await cleanup();
    
    print('✅ Server shut down gracefully');
    exit(0);
  });
  
  ProcessSignal.sigterm.watch().listen((_) async {
    print('📥 Received SIGTERM, shutting down...');
    await server.close();
    exit(0);
  });
}
```

### Server Health Checks

```dart
void setupHealthChecks(Harpy app) {
  // Basic health check
  app.get('/health', (req, res) async {
    try {
      // Check database connectivity
      await req.database?.ping();
      
      // Check external services
      final apiStatus = await checkExternalAPI();
      
      return res.json({
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
        'uptime': getUptime().inSeconds,
        'version': getAppVersion(),
        'checks': {
          'database': 'connected',
          'external_api': apiStatus,
        },
      });
    } catch (e) {
      return res.status(503).json({
        'status': 'unhealthy',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  });
  
  // Readiness check (for Kubernetes)
  app.get('/ready', (req, res) async {
    if (await isApplicationReady()) {
      return res.json({'status': 'ready'});
    } else {
      return res.status(503).json({'status': 'not ready'});
    }
  });
  
  // Liveness check (for Kubernetes)
  app.get('/live', (req, res) {
    return res.json({'status': 'alive'});
  });
}
```

## 📊 Server Monitoring

### Request Metrics

```dart
class ServerMetrics {
  int _totalRequests = 0;
  int _activeConnections = 0;
  final DateTime _startTime = DateTime.now();
  final Map<String, int> _statusCodes = {};
  
  void incrementRequests() => _totalRequests++;
  void incrementActive() => _activeConnections++;
  void decrementActive() => _activeConnections--;
  void recordStatus(int statusCode) {
    _statusCodes[statusCode.toString()] = 
        (_statusCodes[statusCode.toString()] ?? 0) + 1;
  }
  
  Map<String, dynamic> getMetrics() {
    final uptime = DateTime.now().difference(_startTime);
    return {
      'uptime_seconds': uptime.inSeconds,
      'total_requests': _totalRequests,
      'active_connections': _activeConnections,
      'requests_per_second': _totalRequests / uptime.inSeconds,
      'status_codes': _statusCodes,
      'memory_usage': ProcessInfo.currentRss,
    };
  }
}

final serverMetrics = ServerMetrics();

void setupMetrics(Harpy app) {
  // Metrics middleware
  app.use((shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      serverMetrics.incrementRequests();
      serverMetrics.incrementActive();
      
      try {
        final response = await innerHandler(request);
        serverMetrics.recordStatus(response.statusCode);
        return response;
      } finally {
        serverMetrics.decrementActive();
      }
    };
  });
  
  // Metrics endpoint
  app.get('/metrics', (req, res) {
    return res.json(serverMetrics.getMetrics());
  });
  
  // Prometheus metrics endpoint
  app.get('/metrics/prometheus', (req, res) {
    final metrics = serverMetrics.getMetrics();
    final prometheus = convertToPrometheusFormat(metrics);
    return res.text(prometheus, contentType: 'text/plain');
  });
}
```

### Performance Monitoring

```dart
void setupPerformanceMonitoring(Harpy app) {
  // Response time middleware
  app.use((shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      final stopwatch = Stopwatch()..start();
      
      final response = await innerHandler(request);
      
      stopwatch.stop();
      final responseTime = stopwatch.elapsedMilliseconds;
      
      // Log slow requests
      if (responseTime > 1000) {
        print('SLOW REQUEST: ${request.method} ${request.url} - ${responseTime}ms');
      }
      
      return response.change(headers: {
        'X-Response-Time': '${responseTime}ms',
      });
    };
  });
}
```

## 🏗️ Advanced Server Configuration

### Connection Limits

```dart
void main() async {
  final app = Harpy();
  setupRoutes(app);
  
  // Configure server with connection limits
  final server = await app.listen(
    port: 3000,
    backlog: 128,        // Connection backlog
    shared: false,       // Don't share port
  );
  
  // Set connection limits (if using custom HttpServer)
  // server.defaultResponseHeaders.set('Connection', 'keep-alive');
  // server.idleTimeout = Duration(seconds: 30);
  
  print('🚀 Server running with connection limits');
}
```

### Request Size Limits

```dart
shelf.Middleware requestSizeLimit(int maxSizeBytes) {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      final contentLength = request.headers['content-length'];
      if (contentLength != null) {
        final size = int.tryParse(contentLength);
        if (size != null && size > maxSizeBytes) {
          return shelf.Response(413, body: jsonEncode({
            'error': 'Request too large',
            'maxSize': maxSizeBytes,
            'actualSize': size,
          }), headers: {'content-type': 'application/json'});
        }
      }
      
      return await innerHandler(request);
    };
  };
}

// Apply size limits
app.use(requestSizeLimit(10 * 1024 * 1024)); // 10MB limit
```

### Timeout Configuration

```dart
shelf.Middleware timeoutMiddleware(Duration timeout) {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      return await Future.any([
        innerHandler(request),
        Future.delayed(timeout).then((_) {
          return shelf.Response(408, body: jsonEncode({
            'error': 'Request timeout',
            'timeout': '${timeout.inSeconds}s',
          }), headers: {'content-type': 'application/json'});
        }),
      ]);
    };
  };
}

// Apply timeout
app.use(timeoutMiddleware(Duration(seconds: 30)));
```

## 🐳 Docker and Container Deployment

### Dockerfile

```dockerfile
FROM dart:stable AS build

# Install dependencies
WORKDIR /app
COPY pubspec.yaml ./
RUN dart pub get

# Copy source code
COPY . .

# Compile application
RUN dart compile exe bin/main.dart -o bin/server

# Create runtime image
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/app/bin/server", "--health-check"]

# Start server
ENTRYPOINT ["/app/bin/server"]
```

### Docker Compose

```yaml
version: '3.8'

services:
  harpy-api:
    build: .
    ports:
      - "3000:3000"
    environment:
      - PORT=3000
      - DATABASE_URL=postgresql://user:pass@db:5432/myapp
      - JWT_SECRET=your-secret-key
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    depends_on:
      - db
      - redis
    restart: unless-stopped

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  postgres_data:
```

## ☁️ Cloud Deployment

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: harpy-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: harpy-api
  template:
    metadata:
      labels:
        app: harpy-api
    spec:
      containers:
      - name: harpy-api
        image: myregistry/harpy-api:latest
        ports:
        - containerPort: 3000
        env:
        - name: PORT
          value: "3000"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
        livenessProbe:
          httpGet:
            path: /live
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: harpy-api-service
spec:
  selector:
    app: harpy-api
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
```

### Environment-specific Deployment

```dart
void main() async {
  final environment = Platform.environment['ENVIRONMENT'] ?? 'development';
  final config = Configuration.fromEnvironment();
  
  final app = Harpy(config: config);
  
  if (environment == 'production') {
    setupProductionMiddleware(app);
  } else if (environment == 'staging') {
    setupStagingMiddleware(app);
  } else {
    setupDevelopmentMiddleware(app);
  }
  
  setupRoutes(app);
  
  final port = config.get<int>('PORT', 3000);
  await app.listen(host: '0.0.0.0', port: port);
  
  print('🚀 $environment server running on port $port');
}

void setupProductionMiddleware(Harpy app) {
  app.enableLogging(logBody: false); // Don't log bodies in production
  app.enableAuth(jwtSecret: app.config.getRequired('JWT_SECRET'));
  app.use(securityHeaders());
  app.use(rateLimitMiddleware());
}
```

## 🧪 Testing Server Implementation

### Server Testing

```dart
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('Server Tests', () {
    late Harpy app;
    late HarpyServer server;
    late String baseUrl;
    
    setUp(() async {
      app = createTestApp();
      server = await app.listen(port: 0); // Use random port
      final port = server.port;
      baseUrl = 'http://localhost:$port';
    });
    
    tearDown(() async {
      await server.close();
    });
    
    test('should respond to health check', () async {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      
      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], contains('application/json'));
      
      final body = jsonDecode(response.body);
      expect(body['status'], equals('healthy'));
    });
    
    test('should handle graceful shutdown', () async {
      // Test that server closes cleanly
      expect(server.isRunning, isTrue);
      await server.close();
      expect(server.isRunning, isFalse);
    });
  });
}
```

## 🔗 Related Documentation

- **[Framework Overview](harpy_framework.md)** - Basic server setup
- **[Configuration](configuration.md)** - Server configuration
- **[Middleware System](middleware.md)** - Server middleware
- **[HTTP Components](http.md)** - Request/response handling
- **[Deployment Guide](deployment.md)** - Production deployment

---

The server implementation provides a solid foundation for building scalable, production-ready APIs. Configure it according to your needs and deploy with confidence!