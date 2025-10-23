// ignore_for_file: avoid_print, undefined_method, wrong_number_of_type_arguments, deprecated_member_use, undefined_class, undefined_setter

import 'package:harpy/harpy.dart';

// Example User model
class User extends Model {
  @override
  String get tableName => 'users';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get email => get<String>('email');
  set email(String? value) => setAttribute('email', value);

  int? get age => get<int>('age');
  set age(int? value) => setAttribute('age', value);

  @override
  List<String> validate() {
    final errors = <String>[];

    if (name == null || name!.isEmpty) {
      errors.add('Name is required');
    }

    if (email == null || !email!.contains('@')) {
      errors.add('Valid email is required');
    }

    if (age != null && age! < 0) {
      errors.add('Age must be positive');
    }

    return errors;
  }
}

void main() async {
  // Create Harpy application
  final app = Harpy();

  // Connect to database (SQLite for example)
  await app.connectToDatabase({'type': 'sqlite', 'path': 'example.db'});

  // Register models
  app.database?.registerModel<User>('users', User.new);

  // Run migrations
  final migrationManager = MigrationManager(app.database!.connection)

    // Add user table migration
    ..addMigration(Migration(
      version: '001',
      description: 'Create users table',
      up: (schema) async {
        await schema.createTable('users', (table) {
          table
            ..id()
            ..string('name', nullable: false)
            ..string('email', nullable: false)
            ..integer('age')
            ..timestamps()
            ..unique(['email']);
        });
      },
      down: (schema) async {
        await schema.dropTable('users');
      },
    ));

  await migrationManager.migrate();

  // Add middleware
  app
    ..enableCors()
    ..enableLogging(logBody: true)

    // API Routes
    ..get(
      '/',
      (Request req, Response res) => res.json({
        'message': 'Welcome to Harpy Framework with ORM!',
        'version': '0.1.0',
        'features': [
          'RESTful routing',
          'Type-safe ORM',
          'Database migrations',
          'Middleware support',
          'CORS handling',
          'Request logging',
        ],
        'timestamp': DateTime.now().toIso8601String(),
      }),
    )
    ..get('/health', (Request req, Response res) async {
      final dbInfo = await app.database?.getInfo();
      return res.json({'status': 'healthy', 'database': dbInfo});
    })

    // User CRUD endpoints
    ..get('/users', (Request req, Response res) async {
      try {
        final userRegistry = app.database!.getModelRegistry<User>();
        final users = await userRegistry.all();

        return res.json({
          'users': users.map((user) => user.toJson()).toList(),
          'count': users.length,
        });
      } on Exception catch (e) {
        return res.internalServerError({'error': e.toString()});
      }
    })
    ..get('/users/:id', (Request req, Response res) async {
      try {
        final id = req.params['id'];
        if (id == null) {
          return res.badRequest({'error': 'User ID is required'});
        }

        final userRegistry = app.database!.getModelRegistry<User>();
        final user = await userRegistry.find(int.parse(id));

        if (user == null) {
          return res.notFound({'error': 'User not found'});
        }

        return res.json({'user': user.toJson()});
      } on Exception catch (e) {
        return res.internalServerError({'error': e.toString()});
      }
    })
    ..post('/users', (Request req, Response res) async {
      try {
        final data = await req.json();

        final user = User()
          ..name = data['name'] as String?
          ..email = data['email'] as String?
          ..age = data['age'] as int?

          // Set database connection for Active Record
          ..connection = app.database!.connection;

        await user.save();

        return res.created({'user': user.toJson()});
      } on Exception catch (e) {
        if (e is ValidationException) {
          return res.badRequest({'error': e.message});
        }
        return res.internalServerError({'error': e.toString()});
      }
    })
    ..put('/users/:id', (Request req, Response res) async {
      try {
        final id = req.params['id'];
        if (id == null) {
          return res.badRequest({'error': 'User ID is required'});
        }

        final userRegistry = app.database!.getModelRegistry<User>();
        final user = await userRegistry.find(int.parse(id));

        if (user == null) {
          return res.notFound({'error': 'User not found'});
        }

        final data = await req.json();

        if (data['name'] != null) user.name = data['name'] as String;
        if (data['email'] != null) user.email = data['email'] as String;
        if (data['age'] != null) user.age = data['age'] as int;

        user.connection = app.database!.connection;
        await user.save();

        return res.json({'user': user.toJson()});
      } on Exception catch (e) {
        if (e is ValidationException) {
          return res.badRequest({'error': e.message});
        }
        return res.internalServerError({'error': e.toString()});
      }
    })
    ..delete('/users/:id', (Request req, Response res) async {
      try {
        final id = req.params['id'];
        if (id == null) {
          return res.badRequest({'error': 'User ID is required'});
        }

        final userRegistry = app.database!.getModelRegistry<User>();
        final user = await userRegistry.find(int.parse(id));

        if (user == null) {
          return res.notFound({'error': 'User not found'});
        }

        user.connection = app.database!.connection;
        await user.delete();

        return res.json({'message': 'User deleted successfully'});
      } on Exception catch (e) {
        return res.internalServerError({'error': e.toString()});
      }
    })

    // Query examples
    ..get('/users/search', (Request req, Response res) async {
      try {
        final name = req.query['name'];
        final minAge = req.query['min_age'];

        final queryBuilder = app.database!.table<User>();

        if (name != null) {
          queryBuilder.whereLike('name', '%$name%');
        }

        if (minAge != null) {
          queryBuilder.where('age', int.parse(minAge), '>=');
        }

        final users = await queryBuilder.orderBy('name').limit(10).get();

        return res.json({
          'users': users.map((user) => user.toJson()).toList(),
          'filters': {'name': name, 'min_age': minAge},
        });
      } on Exception catch (e) {
        return res.internalServerError({'error': e.toString()});
      }
    });

  // Start server
  try {
    await app.serve(port: 3000);
    print('🚀 Harpy server with ORM running on http://localhost:3000');
    print('📖 Available endpoints:');
    print('  GET    / - Welcome message');
    print('  GET    /health - Health check');
    print('  GET    /users - List all users');
    print('  GET    /users/:id - Get user by ID');
    print('  POST   /users - Create new user');
    print('  PUT    /users/:id - Update user');
    print('  DELETE /users/:id - Delete user');
    print('  GET    /users/search?name=...&min_age=... - Search users');
  } on Exception catch (e) {
    print('❌ Failed to start server: $e');
    await app.close();
  }
}
