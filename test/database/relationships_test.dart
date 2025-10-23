// ignore_for_file: file_names
import 'package:collection/collection.dart';
import 'package:harpy/harpy.dart';
import 'package:test/test.dart';

void main() {
  group('Model Relationships', () {
    late Database database;

    setUp(() async {
      // Clear registry and register models
      ModelRegistry.clear();
      ModelRegistry.register<RelationshipsTest>(RelationshipsTest.new);
      ModelRegistry.register<TestPost>(TestPost.new);
      ModelRegistry.register<TestProfile>(TestProfile.new);
      ModelRegistry.register<TestRole>(TestRole.new);

      // Set up in-memory SQLite database
      database = await Database.connect({
        'type': 'sqlite',
        'path': ':memory:',
      });

      // Set global connection
      ActiveRecord.setGlobalConnection(database.connection);

      // Create test tables
      await _createTables(database);

      // Insert test data
      await _insertTestData(database);
    });

    tearDown(() async {
      await database.close();
    });

    group('BelongsTo Relationship', () {
      test('should load related model', () async {
        final post = await ActiveRecord.find<TestPost>(1);
        expect(post, isNotNull);

        final author = await post!.belongsTo<RelationshipsTest>('user_id');
        expect(author, isNotNull);
        expect(author!.name, equals('John Doe'));
        expect(author.id, equals(1));
      });

      test('should return null for missing relationship', () async {
        final post =
            await ActiveRecord.find<TestPost>(4); // Post 4 has NULL user_id
        expect(post, isNotNull);

        final author = await post!.belongsTo<RelationshipsTest>('user_id');
        expect(author, isNull); // user_id is null for post 4
      });
    });

    group('HasOne Relationship', () {
      test('should load related model', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(1);
        expect(user, isNotNull);

        final profile = await user!.hasOne<TestProfile>('user_id');
        expect(profile, isNotNull);
        expect(profile!.bio, equals('Software Developer'));
        expect(profile.userId, equals(1));
      });

      test('should return null for missing relationship', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(3);
        expect(user, isNotNull);

        final profile = await user!.hasOne<TestProfile>('user_id');
        expect(profile, isNull); // No profile for user 3
      });
    });

    group('HasMany Relationship', () {
      test('should load multiple related models', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(1);
        expect(user, isNotNull);

        final posts = await user!.hasMany<TestPost>('user_id');
        expect(posts.length, equals(2)); // John has 2 posts
        expect(posts.every((post) => post.userId == 1), isTrue);
      });

      test('should load with ordering', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(1);
        expect(user, isNotNull);

        final posts =
            await user!.hasMany<TestPost>('user_id', orderBy: 'title DESC');
        expect(posts.length, equals(2));
        expect(
          posts.firstOrNull?.title,
          equals('Second Post'),
        ); // Should be first due to DESC order
      });

      test('should return empty list for no relationships', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(3);
        expect(user, isNotNull);

        final posts = await user!.hasMany<TestPost>('user_id');
        expect(posts, isEmpty); // User 3 has no posts
      });
    });

    group('BelongsToMany Relationship', () {
      test('should load many-to-many related models', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(1);
        expect(user, isNotNull);

        final roles = await user!.belongsToMany<TestRole>(
          'user_roles',
          'user_id',
          'role_id',
        );

        expect(roles.length, equals(2)); // John has Admin and Editor roles
        final roleNames = roles.map((role) => role.name).toSet();
        expect(roleNames.contains('Admin'), isTrue);
        expect(roleNames.contains('Editor'), isTrue);
      });

      test('should load with ordering', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(1);
        expect(user, isNotNull);

        final roles = await user!.belongsToMany<TestRole>(
          'user_roles',
          'user_id',
          'role_id',
          orderBy: 'roles.name ASC',
        );

        expect(roles.length, equals(2));
        expect(
          roles.firstOrNull?.name,
          equals('Admin'),
        ); // Admin comes before Editor alphabetically
      });

      test('should return empty list for no relationships', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(3);
        expect(user, isNotNull);

        final roles = await user!.belongsToMany<TestRole>(
          'user_roles',
          'user_id',
          'role_id',
        );

        expect(roles, isEmpty); // User 3 has no roles
      });
    });

    group('Many-to-Many Operations', () {
      test('should attach relationship', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(3);
        final role = await ActiveRecord.find<TestRole>(3);
        expect(user, isNotNull);
        expect(role, isNotNull);

        // User 3 initially has no roles
        var roles = await user!
            .belongsToMany<TestRole>('user_roles', 'user_id', 'role_id');
        expect(roles, isEmpty);

        // Attach the Viewer role
        await user.attach<TestRole>('user_roles', 'user_id', 'role_id', role!);

        // Verify the relationship was created
        roles = await user.belongsToMany<TestRole>(
          'user_roles',
          'user_id',
          'role_id',
        );
        expect(roles.length, equals(1));
        expect(roles.firstOrNull?.name, equals('Viewer'));
      });

      test('should attach with pivot data', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(2);
        final role = await ActiveRecord.find<TestRole>(1);
        expect(user, isNotNull);
        expect(role, isNotNull);

        // Attach with additional pivot data
        await user!.attach<TestRole>(
          'user_roles',
          'user_id',
          'role_id',
          role!,
          pivotData: {
            'granted_at': DateTime.now().toIso8601String(),
            'granted_by': 1,
          },
        );

        // Verify the relationship exists
        final userRoles = await user.belongsToMany<TestRole>(
          'user_roles',
          'user_id',
          'role_id',
        );
        expect(userRoles.any((r) => r.name == 'Admin'), isTrue);
      });

      test('should detach relationship', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(1);
        final role = await ActiveRecord.find<TestRole>(1); // Admin role
        expect(user, isNotNull);
        expect(role, isNotNull);

        // User 1 initially has Admin role
        var roles = await user!
            .belongsToMany<TestRole>('user_roles', 'user_id', 'role_id');
        expect(roles.any((r) => r.name == 'Admin'), isTrue);

        // Detach Admin role
        await user.detach<TestRole>('user_roles', 'user_id', 'role_id', role!);

        // Verify the relationship was removed
        roles = await user.belongsToMany<TestRole>(
          'user_roles',
          'user_id',
          'role_id',
        );
        expect(roles.any((r) => r.name == 'Admin'), isFalse);
        expect(
          roles.any((r) => r.name == 'Editor'),
          isTrue,
        ); // Should still have Editor
      });

      test('should sync relationships', () async {
        final user = await ActiveRecord.find<RelationshipsTest>(2);
        final adminRole = await ActiveRecord.find<TestRole>(1);
        final viewerRole = await ActiveRecord.find<TestRole>(3);
        expect(user, isNotNull);
        expect(adminRole, isNotNull);
        expect(viewerRole, isNotNull);

        // User 2 initially has Editor role
        var roles = await user!
            .belongsToMany<TestRole>('user_roles', 'user_id', 'role_id');
        expect(roles.length, equals(1));
        expect(roles.firstOrNull?.name, equals('Editor'));

        // Sync to Admin and Viewer roles (replacing Editor)
        await user.sync<TestRole>(
          'user_roles',
          'user_id',
          'role_id',
          [adminRole!, viewerRole!],
        );

        // Verify the relationships were synced
        roles = await user.belongsToMany<TestRole>(
          'user_roles',
          'user_id',
          'role_id',
        );
        expect(roles.length, equals(2));
        final roleNames = roles.map((role) => role.name).toSet();
        expect(roleNames.contains('Admin'), isTrue);
        expect(roleNames.contains('Viewer'), isTrue);
        expect(roleNames.contains('Editor'), isFalse); // Should be removed
      });
    });
  });
}

Future<void> _createTables(Database database) async {
  // Users table
  await database.connection.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL
    )
  ''');

  // Posts table
  await database.connection.execute('''
    CREATE TABLE posts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      content TEXT,
      user_id INTEGER,
      FOREIGN KEY (user_id) REFERENCES users (id)
    )
  ''');

  // Profiles table
  await database.connection.execute('''
    CREATE TABLE profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER UNIQUE NOT NULL,
      bio TEXT,
      FOREIGN KEY (user_id) REFERENCES users (id)
    )
  ''');

  // Roles table
  await database.connection.execute('''
    CREATE TABLE roles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      description TEXT
    )
  ''');

  // User-Role pivot table
  await database.connection.execute('''
    CREATE TABLE user_roles (
      user_id INTEGER,
      role_id INTEGER,
      granted_at TEXT,
      granted_by INTEGER,
      PRIMARY KEY (user_id, role_id),
      FOREIGN KEY (user_id) REFERENCES users (id),
      FOREIGN KEY (role_id) REFERENCES roles (id)
    )
  ''');
}

Future<void> _insertTestData(Database database) async {
  // Insert users
  await database.connection.execute('''
    INSERT INTO users (name, email) VALUES 
    ('John Doe', 'john@example.com'),
    ('Jane Smith', 'jane@example.com'),
    ('Bob Wilson', 'bob@example.com')
  ''');

  // Insert posts
  await database.connection.execute('''
    INSERT INTO posts (title, content, user_id) VALUES 
    ('First Post', 'This is the first post content', 1),
    ('Second Post', 'This is the second post content', 1),
    ('Jane''s Post', 'This is Jane''s post content', 2),
    ('Orphaned Post', 'This post has no author', NULL)
  ''');

  // Insert profiles
  await database.connection.execute('''
    INSERT INTO profiles (user_id, bio) VALUES 
    (1, 'Software Developer'),
    (2, 'Designer')
  ''');

  // Insert roles
  await database.connection.execute('''
    INSERT INTO roles (name, description) VALUES 
    ('Admin', 'System administrator'),
    ('Editor', 'Content editor'),
    ('Viewer', 'Read-only access')
  ''');

  // Insert user-role relationships
  await database.connection.execute('''
    INSERT INTO user_roles (user_id, role_id) VALUES 
    (1, 1),  -- John is Admin
    (1, 2),  -- John is also Editor
    (2, 2)   -- Jane is Editor
  ''');
}

// Test models
class RelationshipsTest extends Model with ActiveRecord {
  @override
  String get tableName => 'users';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get email => get<String>('email');
  set email(String? value) => setAttribute('email', value);
}

class TestPost extends Model with ActiveRecord {
  @override
  String get tableName => 'posts';

  String? get title => get<String>('title');
  set title(String? value) => setAttribute('title', value);

  String? get content => get<String>('content');
  set content(String? value) => setAttribute('content', value);

  int? get userId => get<int>('user_id');
  set userId(int? value) => setAttribute('user_id', value);
}

class TestProfile extends Model with ActiveRecord {
  @override
  String get tableName => 'profiles';

  int? get userId => get<int>('user_id');
  set userId(int? value) => setAttribute('user_id', value);

  String? get bio => get<String>('bio');
  set bio(String? value) => setAttribute('bio', value);
}

class TestRole extends Model with ActiveRecord {
  @override
  String get tableName => 'roles';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get description => get<String>('description');
  set description(String? value) => setAttribute('description', value);
}
