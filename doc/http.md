# HTTP Components

Harpy provides powerful and intuitive HTTP request and response handling through its Request and Response classes. These components form the foundation of all HTTP interactions in your API.

## 🎯 Overview

- **Request Object** - Represents incoming HTTP requests with easy access to headers, parameters, and body
- **Response Object** - Provides fluent API for building HTTP responses
- **Type Safety** - Built-in type conversion and validation
- **Convenience Methods** - Common status codes and content types
- **Streaming Support** - Handle large requests and responses
- **JSON First** - Built-in JSON parsing and serialization

## 📥 Request Object

### Basic Usage

```dart
app.post('/api/users', (req, res) async {
  // HTTP method and path
  print(req.method); // POST
  print(req.path);   // /api/users
  print(req.url);    // Full URL object
  
  // Headers
  final contentType = req.headers['content-type'];
  final userAgent = req.userAgent;
  final authorization = req.headers['authorization'];
  
  // Query parameters
  final page = req.query['page'];
  final limit = int.tryParse(req.query['limit'] ?? '10') ?? 10;
  
  // Route parameters
  final id = req.params['id']; // From routes like '/users/:id'
  
  return res.json({'received': 'ok'});
});
```

### Request Body Handling

```dart
// JSON body
app.post('/api/data', (req, res) async {
  if (req.isJson) {
    final jsonData = await req.json();
    print('Received: $jsonData');
    
    // Access nested data
    final userName = jsonData['user']['name'];
    final email = jsonData['user']['email'];
    
    return res.json({'message': 'Data received'});
  }
  
  return res.badRequest({'error': 'JSON required'});
});

// Text body
app.post('/api/text', (req, res) async {
  final textData = await req.text();
  return res.text('Echo: $textData');
});

// Raw bytes
app.post('/api/upload', (req, res) async {
  final bytes = await req.bytes();
  print('Received ${bytes.length} bytes');
  return res.ok({'size': bytes.length});
});
```

### Content Type Detection

```dart
app.post('/api/flexible', (req, res) async {
  if (req.isJson) {
    final data = await req.json();
    return res.json({'type': 'json', 'data': data});
  }
  
  if (req.isForm) {
    final data = await req.form();
    return res.json({'type': 'form', 'data': data});
  }
  
  if (req.isText) {
    final data = await req.text();
    return res.json({'type': 'text', 'data': data});
  }
  
  return res.badRequest({'error': 'Unsupported content type'});
});
```

## 📤 Response Object

### Basic Responses

```dart
app.get('/api/examples', (req, res) {
  // JSON response (most common)
  return res.json({'message': 'Hello World'});
  
  // Text response
  return res.text('Plain text response');
  
  // HTML response
  return res.html('<h1>HTML Response</h1>');
  
  // Binary response
  return res.bytes(fileBytes, contentType: 'application/pdf');
});
```

### Status Codes

```dart
app.get('/api/status', (req, res) {
  // Explicit status codes
  return res.status(201).json({'created': true});
  
  // Convenience methods
  return res.ok({'success': true});                    // 200
  return res.created({'id': 123});                     // 201
  return res.accepted({'queued': true});               // 202
  return res.noContent();                              // 204
  
  // Error responses
  return res.badRequest({'error': 'Invalid input'});   // 400
  return res.unauthorized({'error': 'Login required'}); // 401
  return res.forbidden({'error': 'Access denied'});    // 403
  return res.notFound({'error': 'Resource not found'}); // 404
  return res.methodNotAllowed({'error': 'Method not allowed'}); // 405
  return res.conflict({'error': 'Resource exists'});   // 409
  return res.unprocessableEntity({'errors': ['validation error']}); // 422
  return res.internalServerError({'error': 'Server error'}); // 500
});
```

### Headers

```dart
app.get('/api/headers', (req, res) {
  // Set single header
  return res
    .header('X-Custom-Header', 'custom-value')
    .json({'message': 'With custom header'});
  
  // Set multiple headers
  return res
    .headers({
      'X-API-Version': '1.0',
      'X-Rate-Limit': '1000',
      'Cache-Control': 'no-cache',
    })
    .json({'data': 'response'});
  
  // CORS headers
  return res
    .header('Access-Control-Allow-Origin', '*')
    .header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE')
    .json({'cors': 'enabled'});
});
```

### Cookies

```dart
app.get('/api/cookies', (req, res) {
  // Set cookie
  return res
    .cookie('session_id', 'abc123', {
      'httpOnly': true,
      'secure': true,
      'maxAge': 3600,
      'path': '/',
    })
    .json({'message': 'Cookie set'});
  
  // Clear cookie
  return res
    .clearCookie('session_id')
    .json({'message': 'Cookie cleared'});
});

// Read cookies from request
app.get('/api/read-cookies', (req, res) {
  final sessionId = req.cookies['session_id'];
  if (sessionId != null) {
    return res.json({'sessionId': sessionId});
  }
  return res.unauthorized({'error': 'No session'});
});
```

## 🔗 Advanced Features

### File Responses

```dart
app.get('/api/download/:filename', (req, res) async {
  final filename = req.params['filename'];
  final file = File('uploads/$filename');
  
  if (await file.exists()) {
    return res.file(file, filename: filename);
  }
  
  return res.notFound({'error': 'File not found'});
});

// Streaming large files
app.get('/api/stream/:filename', (req, res) async {
  final filename = req.params['filename'];
  final file = File('large_files/$filename');
  
  if (await file.exists()) {
    return res.stream(file.openRead(), 
      contentType: 'application/octet-stream',
      contentLength: await file.length()
    );
  }
  
  return res.notFound({'error': 'File not found'});
});
```

### Redirects

```dart
app.get('/api/redirect', (req, res) {
  // Permanent redirect (301)
  return res.redirect('/api/new-location', permanent: true);
  
  // Temporary redirect (302) - default
  return res.redirect('/api/temporary-location');
  
  // See other (303)
  return res.redirect('/api/see-other', statusCode: 303);
});
```

### Content Negotiation

```dart
app.get('/api/content-negotiation', (req, res) {
  final accept = req.headers['accept'];
  
  if (accept?.contains('application/json') == true) {
    return res.json({'format': 'json'});
  }
  
  if (accept?.contains('application/xml') == true) {
    return res
      .header('Content-Type', 'application/xml')
      .text('<response><format>xml</format></response>');
  }
  
  if (accept?.contains('text/html') == true) {
    return res.html('<h1>HTML Response</h1>');
  }
  
  // Default to JSON
  return res.json({'format': 'default'});
});
```

## 🔧 Request Validation

### Custom Validation

```dart
// Validation middleware
shelf.Middleware validateJson(Map<String, dynamic> schema) {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      if (request.method == 'POST' || request.method == 'PUT') {
        try {
          final body = await request.readAsString();
          final json = jsonDecode(body);
          
          // Simple validation example
          for (final field in schema.keys) {
            if (!json.containsKey(field)) {
              return shelf.Response.badRequest(
                body: jsonEncode({'error': 'Missing field: $field'}),
                headers: {'content-type': 'application/json'},
              );
            }
          }
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
app.use(validateJson({'name': String, 'email': String}));
app.post('/api/users', (req, res) async {
  final userData = await req.json();
  // userData is guaranteed to have name and email
  return res.created({'user': userData});
});
```

### Type-Safe Request Handling

```dart
class CreateUserRequest {
  final String name;
  final String email;
  final int? age;
  
  CreateUserRequest({required this.name, required this.email, this.age});
  
  factory CreateUserRequest.fromJson(Map<String, dynamic> json) {
    return CreateUserRequest(
      name: json['name'] as String,
      email: json['email'] as String,
      age: json['age'] as int?,
    );
  }
  
  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) errors.add('Name is required');
    if (!email.contains('@')) errors.add('Invalid email');
    if (age != null && age! < 0) errors.add('Invalid age');
    return errors;
  }
}

app.post('/api/users', (req, res) async {
  try {
    final createRequest = CreateUserRequest.fromJson(await req.json());
    final errors = createRequest.validate();
    
    if (errors.isNotEmpty) {
      return res.badRequest({'errors': errors});
    }
    
    // Process valid request
    final user = await createUser(createRequest);
    return res.created({'user': user});
    
  } catch (e) {
    return res.badRequest({'error': 'Invalid request format'});
  }
});
```

## 📊 Request Logging and Monitoring

### Basic Request Logging

```dart
shelf.Middleware requestLogger() {
  return shelf.logRequests(
    logger: (message, isError) {
      if (isError) {
        print('ERROR: $message');
      } else {
        print('INFO: $message');
      }
    }
  );
}

app.use(requestLogger());
```

### Custom Request Metrics

```dart
shelf.Middleware requestMetrics() {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      final stopwatch = Stopwatch()..start();
      
      try {
        final response = await innerHandler(request);
        
        stopwatch.stop();
        print('${request.method} ${request.url.path} - '
              '${response.statusCode} - ${stopwatch.elapsedMilliseconds}ms');
        
        return response;
      } catch (e) {
        stopwatch.stop();
        print('${request.method} ${request.url.path} - '
              'ERROR - ${stopwatch.elapsedMilliseconds}ms - $e');
        rethrow;
      }
    };
  };
}
```

## 🧪 Testing HTTP Components

### Testing Request Handling

```dart
import 'package:test/test.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_test_handler/shelf_test_handler.dart';

void main() {
  group('HTTP Request Tests', () {
    test('should parse JSON request', () async {
      final handler = (shelf.Request request) async {
        final req = Request(request);
        final body = await req.json();
        return shelf.Response.ok(jsonEncode({'received': body}));
      };
      
      final response = await makeRequest(
        handler,
        'POST',
        '/test',
        body: jsonEncode({'name': 'Test User'}),
        headers: {'content-type': 'application/json'},
      );
      
      expect(response.statusCode, equals(200));
      final responseBody = jsonDecode(await response.readAsString());
      expect(responseBody['received']['name'], equals('Test User'));
    });
  });
}
```

### Testing Response Building

```dart
test('should build correct response', () {
  final res = Response();
  final response = res
    .status(201)
    .header('X-Custom', 'value')
    .json({'created': true});
  
  expect(response.statusCode, equals(201));
  expect(response.headers['x-custom'], equals('value'));
  expect(response.headers['content-type'], contains('application/json'));
});
```

## 🔗 Related Documentation

- **[Routing System](routing.md)** - URL routing and parameters
- **[Middleware System](middleware.md)** - Request/response processing
- **[Authentication](authentication.md)** - Request authentication
- **[Configuration](configuration.md)** - HTTP server configuration

---

HTTP components provide the foundation for all API interactions in Harpy. Next, explore the [Middleware System](middleware.md) to add cross-cutting functionality.