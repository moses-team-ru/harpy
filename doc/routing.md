# Routing System

Harpy's routing system provides Express.js-style URL routing with powerful parameter extraction, sub-router support, and flexible route matching. The system is designed for both simplicity in basic use cases and power in complex applications.

## 🎯 Overview

- **Express.js-style Routing** - Familiar syntax for web developers
- **Parameter Extraction** - Automatic parsing of URL parameters
- **Sub-routers** - Organize routes hierarchically
- **Method Matching** - Support for all HTTP methods
- **Wildcard Routes** - Handle multiple methods or catch-all routes
- **Route Middleware** - Apply middleware to specific routes
- **Route Groups** - Shared prefixes and middleware

## 🚀 Basic Routing

### HTTP Methods

```dart
import 'package:harpy/harpy.dart';

void main() async {
  final app = Harpy();
  
  // HTTP method routes
  app.get('/users', getUsersHandler);
  app.post('/users', createUserHandler);
  app.put('/users/:id', updateUserHandler);
  app.patch('/users/:id', patchUserHandler);
  app.delete('/users/:id', deleteUserHandler);
  app.head('/users/:id', headUserHandler);
  app.options('/users', optionsHandler);
  
  await app.listen(port: 3000);
}

// Handler functions
Future<shelf.Response> getUsersHandler(Request req, Response res) async {
  return res.json({'users': []});
}

Future<shelf.Response> createUserHandler(Request req, Response res) async {
  final userData = await req.json();
  return res.created({'user': userData});
}
```

### Route Parameters

```dart
// Single parameter
app.get('/users/:id', (req, res) {
  final userId = req.params['id'];
  return res.json({'userId': userId});
});

// Multiple parameters
app.get('/users/:userId/posts/:postId', (req, res) {
  final userId = req.params['userId'];
  final postId = req.params['postId'];
  
  return res.json({
    'userId': userId,
    'postId': postId,
    'url': req.path,
  });
});

// Optional parameters with default values
app.get('/posts/:id/:slug?', (req, res) {
  final id = req.params['id'];
  final slug = req.params['slug'] ?? 'default-slug';
  
  return res.json({'id': id, 'slug': slug});
});
```

### Query Parameters

```dart
app.get('/search', (req, res) {
  final query = req.query['q'];
  final page = int.tryParse(req.query['page'] ?? '1') ?? 1;
  final limit = int.tryParse(req.query['limit'] ?? '10') ?? 10;
  final sort = req.query['sort'] ?? 'created_at';
  final order = req.query['order'] ?? 'desc';
  
  // Array parameters (e.g., ?tags=tag1&tags=tag2)
  final tags = req.queryAll['tags'] ?? [];
  
  return res.json({
    'query': query,
    'pagination': {'page': page, 'limit': limit},
    'sorting': {'field': sort, 'order': order},
    'filters': {'tags': tags},
  });
});
```

## 🏗️ Advanced Routing

### Wildcard Routes

```dart
// Handle all HTTP methods
app.any('/api/webhook', (req, res) {
  return res.json({
    'method': req.method,
    'received': 'webhook data',
  });
});

// Handle specific methods
app.match(['GET', 'POST'], '/api/flexible', (req, res) {
  if (req.method == 'GET') {
    return res.json({'action': 'fetch'});
  } else {
    return res.json({'action': 'create'});
  }
});

// Catch-all route
app.get('/docs/*', (req, res) {
  final path = req.params['*']; // Everything after /docs/
  return res.json({'docPath': path});
});
```

### Route Patterns

```dart
// Regex patterns
app.get(RegExp(r'/files/\d+'), (req, res) {
  return res.json({'matched': 'numeric file ID'});
});

// Custom route matching
app.addRoute(Route(
  method: 'GET',
  pattern: '/custom/:id',
  handler: (req, res) => res.json({'custom': req.params['id']}),
  conditions: {
    'id': RegExp(r'^\d+$'), // Only numeric IDs
  },
));
```

## 🔀 Sub-routers

### Basic Sub-routing

```dart
void main() async {
  final app = Harpy();
  
  // Create API v1 router
  final apiV1 = Router()
    ..get('/users', getUsersV1)
    ..post('/users', createUserV1)
    ..get('/posts', getPostsV1);
  
  // Create API v2 router
  final apiV2 = Router()
    ..get('/users', getUsersV2)
    ..post('/users', createUserV2)
    ..get('/posts', getPostsV2);
  
  // Mount routers
  app.mount('/api/v1', apiV1);
  app.mount('/api/v2', apiV2);
  
  // Routes are now available at:
  // GET /api/v1/users
  // POST /api/v1/users
  // GET /api/v2/users
  // etc.
  
  await app.listen(port: 3000);
}
```

### Nested Sub-routers

```dart
// Admin router
final adminRouter = Router();

// Admin user management
final adminUsersRouter = Router()
  ..get('/', getAllUsers)
  ..get('/:id', getUser)
  ..put('/:id', updateUser)
  ..delete('/:id', deleteUser);

// Admin system management
final adminSystemRouter = Router()
  ..get('/health', getSystemHealth)
  ..get('/metrics', getSystemMetrics)
  ..post('/maintenance', setMaintenanceMode);

// Mount nested routers
adminRouter.mount('/users', adminUsersRouter);
adminRouter.mount('/system', adminSystemRouter);

// Mount admin router
app.mount('/admin', adminRouter);

// Results in routes like:
// GET /admin/users/
// GET /admin/users/123
// GET /admin/system/health
```

### Router Middleware

```dart
// Create router with middleware
final protectedRouter = Router();

// Add authentication middleware to all routes in this router
protectedRouter.use(authenticationMiddleware());

// Add routes
protectedRouter.get('/profile', getProfile);
protectedRouter.put('/profile', updateProfile);
protectedRouter.delete('/account', deleteAccount);

// Mount protected router
app.mount('/protected', protectedRouter);
```

## 🔧 Route Middleware

### Route-specific Middleware

```dart
// Middleware for a single route
app.get('/admin/dashboard',
  [authMiddleware(), adminMiddleware()],
  dashboardHandler
);

// Multiple middleware functions
app.post('/api/upload',
  [
    authMiddleware(),
    rateLimitMiddleware(limit: 10),
    fileSizeMiddleware(maxSize: '10MB'),
  ],
  uploadHandler
);
```

### Conditional Middleware

```dart
// Apply middleware based on conditions
app.get('/api/data', (req, res) {
  // Check if user is authenticated
  if (req.headers['authorization'] == null) {
    return res.unauthorized({'error': 'Authentication required'});
  }
  
  // Check user permissions
  final role = getUserRole(req);
  if (role != 'admin') {
    return res.forbidden({'error': 'Admin access required'});
  }
  
  return res.json({'data': 'sensitive information'});
});
```

## 🎯 Route Groups

### Shared Prefixes

```dart
void setupAPIRoutes(Harpy app) {
  // Group API routes
  app.group('/api', (group) {
    // Authentication routes
    group.post('/login', loginHandler);
    group.post('/logout', logoutHandler);
    group.post('/refresh', refreshTokenHandler);
    
    // Protected routes
    group.group('/protected', (protected) {
      protected.use(authMiddleware());
      
      protected.get('/profile', getProfileHandler);
      protected.put('/profile', updateProfileHandler);
      protected.delete('/account', deleteAccountHandler);
    });
  });
}
```

### Shared Middleware

```dart
void setupAdminRoutes(Harpy app) {
  app.group('/admin', (admin) {
    // Apply admin middleware to all routes in this group
    admin.use([
      authMiddleware(),
      adminMiddleware(),
      auditLogMiddleware(),
    ]);
    
    // User management
    admin.get('/users', listUsersHandler);
    admin.post('/users', createUserHandler);
    admin.delete('/users/:id', deleteUserHandler);
    
    // System management
    admin.get('/system/status', systemStatusHandler);
    admin.post('/system/backup', backupSystemHandler);
  });
}
```

## 🔍 Route Information

### Route Inspection

```dart
void main() async {
  final app = Harpy();
  
  // Add routes
  app.get('/users', getUsersHandler);
  app.post('/users', createUserHandler);
  app.get('/users/:id', getUserHandler);
  
  // Inspect registered routes
  final routes = app.router.routes;
  for (final route in routes) {
    print('${route.method} ${route.pattern}');
    print('  Parameters: ${route.paramNames}');
    print('  Middleware: ${route.middleware.length}');
  }
  
  await app.listen(port: 3000);
}
```

### Route Matching

```dart
// Check if a route matches
final route = app.router.findRoute('GET', '/users/123');
if (route != null) {
  final params = route.extractParams('/users/123');
  print('Matched route with params: $params');
}

// Get all matching routes
final matchingRoutes = app.router.findAllRoutes('GET', '/users/123');
print('Found ${matchingRoutes.length} matching routes');
```

## 🛡️ Route Security

### Parameter Validation

```dart
// Validate route parameters
app.get('/users/:id', (req, res) {
  final idStr = req.params['id'];
  final id = int.tryParse(idStr ?? '');
  
  if (id == null || id <= 0) {
    return res.badRequest({'error': 'Invalid user ID'});
  }
  
  return res.json({'userId': id});
});

// Custom parameter validation
app.addRoute(Route(
  method: 'GET',
  pattern: '/products/:id',
  handler: getProductHandler,
  validators: {
    'id': (value) => int.tryParse(value) != null,
  },
));
```

### Input Sanitization

```dart
String sanitizeInput(String input) {
  return input
    .replaceAll(RegExp(r'[<>"\']'), '') // Remove HTML characters
    .replaceAll(RegExp(r'[^\w\s-.]'), '') // Keep only safe characters
    .trim();
}

app.get('/search/:query', (req, res) {
  final rawQuery = req.params['query'] ?? '';
  final sanitizedQuery = sanitizeInput(rawQuery);
  
  if (sanitizedQuery.isEmpty) {
    return res.badRequest({'error': 'Invalid search query'});
  }
  
  return res.json({'query': sanitizedQuery, 'results': []});
});
```

## 📊 Route Performance

### Route Caching

```dart
class CachedRouter extends Router {
  final Map<String, Route?> _routeCache = {};
  
  @override
  Route? findRoute(String method, String path) {
    final key = '$method:$path';
    
    if (_routeCache.containsKey(key)) {
      return _routeCache[key];
    }
    
    final route = super.findRoute(method, path);
    _routeCache[key] = route;
    
    return route;
  }
}

final app = Harpy(router: CachedRouter());
```

### Route Optimization

```dart
// Order routes from most specific to least specific
app.get('/users/active', getActiveUsersHandler);     // More specific
app.get('/users/inactive', getInactiveUsersHandler); // More specific
app.get('/users/:id', getUserHandler);               // Less specific
app.get('/users/*', catchAllUsersHandler);          // Least specific

// Use route conditions for better performance
app.addRoute(Route(
  method: 'GET',
  pattern: '/api/:version/users',
  handler: versionedUsersHandler,
  conditions: {
    'version': RegExp(r'^v[12]$'), // Only v1 or v2
  },
));
```

## 🧪 Testing Routes

### Route Testing

```dart
import 'package:test/test.dart';

void main() {
  group('Route Tests', () {
    late Harpy app;
    
    setUp(() {
      app = Harpy();
      app.get('/users/:id', (req, res) {
        return res.json({'userId': req.params['id']});
      });
    });
    
    test('should extract route parameters', () {
      final routes = app.router.routes;
      final route = routes.first;
      
      expect(route.matches('GET', '/users/123'), isTrue);
      expect(route.matches('POST', '/users/123'), isFalse);
      
      final params = route.extractParams('/users/123');
      expect(params['id'], equals('123'));
    });
    
    test('should handle invalid routes', () {
      final route = app.router.findRoute('GET', '/invalid');
      expect(route, isNull);
    });
  });
}
```

## 🔗 Related Documentation

- **[HTTP Components](http.md)** - Request and Response objects
- **[Middleware System](middleware.md)** - Route middleware
- **[Framework Overview](harpy_framework.md)** - Basic routing examples
- **[Server Implementation](server.md)** - Server and routing integration

---

The routing system provides flexible URL handling for your Harpy applications. Next, explore the [Middleware System](middleware.md) to add cross-cutting functionality to your routes.