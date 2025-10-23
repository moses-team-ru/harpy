/// Example demonstrating the enhanced ORM capabilities
///
/// This example shows how to use the new features:
/// - ModelRegistry for model registration
/// - copyWith() method for model copying
/// - Static ORM methods (find, where, fetchAll, etc.)
/// - Relationships (belongsTo, hasMany, belongsToMany)
/// - Advanced querying and data manipulation

// ignore_for_file: avoid_print, avoid-nullable-interpolation

import 'package:harpy/harpy.dart';

/// User model with relationships
class EnhancedOrmExample extends Model with ActiveRecord {
  @override
  String get tableName => 'users';

  // Properties with getters and setters
  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get email => get<String>('email');
  set email(String? value) => setAttribute('email', value);

  int? get age => get<int>('age');
  set age(int? value) => setAttribute('age', value);

  DateTime? get createdAt => get<DateTime>('created_at');
  set createdAt(DateTime? value) => setAttribute('created_at', value);

  // Relationships
  Future<List<Post>> get posts =>
      hasMany<Post>('user_id', orderBy: 'created_at DESC');
  Future<Profile?> get profile => hasOne<Profile>('user_id');
  Future<List<Role>> get roles => belongsToMany<Role>(
        'user_roles',
        'user_id',
        'role_id',
        orderBy: 'roles.name ASC',
      );

  // Validation
  @override
  List<String> validate() {
    final errors = <String>[];
    if (name == null || name!.trim().isEmpty) {
      errors.add('Name is required');
    }
    if (email == null || !_isValidUserEmail(email!)) {
      errors.add('Valid email is required');
    }
    if (age != null && (age! < 0 || age! > 150)) {
      errors.add('Age must be between 0 and 150');
    }
    return errors;
  }

  bool _isValidUserEmail(String em) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(em);
}

/// Post model
class Post extends Model with ActiveRecord {
  @override
  String get tableName => 'posts';

  String? get title => get<String>('title');
  set title(String? value) => setAttribute('title', value);

  String? get content => get<String>('content');
  set content(String? value) => setAttribute('content', value);

  int? get userId => get<int>('user_id');
  set userId(int? value) => setAttribute('user_id', value);

  DateTime? get createdAt => get<DateTime>('created_at');
  set createdAt(DateTime? value) => setAttribute('created_at', value);

  // Relationships
  Future<EnhancedOrmExample?> get author =>
      belongsTo<EnhancedOrmExample>('user_id');
  Future<List<Tag>> get tags => belongsToMany<Tag>(
        'post_tags',
        'post_id',
        'tag_id',
      );
}

/// Profile model
class Profile extends Model with ActiveRecord {
  @override
  String get tableName => 'profiles';

  int? get userId => get<int>('user_id');
  set userId(int? value) => setAttribute('user_id', value);

  String? get bio => get<String>('bio');
  set bio(String? value) => setAttribute('bio', value);

  String? get website => get<String>('website');
  set website(String? value) => setAttribute('website', value);

  // Relationships
  Future<EnhancedOrmExample?> get user =>
      belongsTo<EnhancedOrmExample>('user_id');
}

/// Role model
class Role extends Model with ActiveRecord {
  @override
  String get tableName => 'roles';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get description => get<String>('description');
  set description(String? value) => setAttribute('description', value);

  // Relationships
  Future<List<EnhancedOrmExample>> get users =>
      belongsToMany<EnhancedOrmExample>('user_roles', 'role_id', 'user_id');
}

/// Tag model
class Tag extends Model with ActiveRecord {
  @override
  String get tableName => 'tags';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get color => get<String>('color');
  set color(String? value) => setAttribute('color', value);

  // Relationships
  Future<List<Post>> get posts => belongsToMany<Post>(
        'post_tags',
        'tag_id',
        'post_id',
      );
}

/// Example usage of the enhanced ORM
void main() async {
  print('🚀 Enhanced ORM Example - Harpy Framework');
  print('=' * 50);

  // Set up database connection
  final database = await Database.connect({
    'type': 'sqlite',
    'path': 'example.db',
  });

  // Set global connection for static methods
  ActiveRecord.setGlobalConnection(database.connection);

  try {
    await _createTables(database);
    await _demonstrateBasicOperations();
    await _demonstrateCopyWith();
    await _demonstrateStaticMethods();
    await _demonstrateRelationships();
    await _demonstrateManyToMany();
  } finally {
    await database.close();
  }

  print('\n✅ Example completed successfully!');
}

/// Create database tables
Future<void> _createTables(Database database) async {
  print('\n📋 Creating database tables...');

  await database.connection.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      age INTEGER,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await database.connection.execute('''
    CREATE TABLE IF NOT EXISTS posts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      content TEXT,
      user_id INTEGER,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users (id)
    )
  ''');

  await database.connection.execute('''
    CREATE TABLE IF NOT EXISTS profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER UNIQUE NOT NULL,
      bio TEXT,
      website TEXT,
      FOREIGN KEY (user_id) REFERENCES users (id)
    )
  ''');

  await database.connection.execute('''
    CREATE TABLE IF NOT EXISTS roles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      description TEXT
    )
  ''');

  await database.connection.execute('''
    CREATE TABLE IF NOT EXISTS tags (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      color TEXT DEFAULT '#000000'
    )
  ''');

  await database.connection.execute('''
    CREATE TABLE IF NOT EXISTS user_roles (
      user_id INTEGER,
      role_id INTEGER,
      granted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (user_id, role_id),
      FOREIGN KEY (user_id) REFERENCES users (id),
      FOREIGN KEY (role_id) REFERENCES roles (id)
    )
  ''');

  await database.connection.execute('''
    CREATE TABLE IF NOT EXISTS post_tags (
      post_id INTEGER,
      tag_id INTEGER,
      PRIMARY KEY (post_id, tag_id),
      FOREIGN KEY (post_id) REFERENCES posts (id),
      FOREIGN KEY (tag_id) REFERENCES tags (id)
    )
  ''');

  print('✅ Tables created successfully');
}

/// Demonstrate basic ORM operations
Future<void> _demonstrateBasicOperations() async {
  print('\n🔧 Basic ORM Operations');
  print('-' * 30);

  // Create and save a new user
  final user = EnhancedOrmExample()
    ..name = 'John Doe'
    ..email = 'john@example.com'
    ..age = 30;

  await user.save();
  print('➕ Created user: ${user.name ?? "N/A"} (ID: ${user.id ?? "N/A"})');

  // Update the user
  user.age = 31;
  await user.save();
  print('🔄 Updated user age to: ${user.age ?? "N/A"}');

  // Create another user with validation
  final invalidUser = EnhancedOrmExample()
    ..name = ''
    ..email = 'invalid-email';

  try {
    await invalidUser.save();
  } on ValidationException catch (e) {
    print('❌ Validation failed: ${e.message}');
  }

  // Create valid user
  final jane = EnhancedOrmExample()
    ..name = 'Jane Smith'
    ..email = 'jane@example.com'
    ..age = 28;

  await jane.save();
  print('➕ Created user: ${jane.name} (ID: ${jane.id})');
}

/// Demonstrate copyWith functionality
Future<void> _demonstrateCopyWith() async {
  print('\n📄 copyWith() Demonstration');
  print('-' * 30);

  // Find existing user
  final original = await ActiveRecord.find<EnhancedOrmExample>(1);
  if (original == null) return;

  print('👤 Original user: ${original.name}, Age: ${original.age}');

  // Create copy with modifications
  final copy = original.copyWith<EnhancedOrmExample>(
    attributes: {'name': 'John Doe Jr.', 'age': 25},
  );

  print('👶 Copied user: ${copy.name}, Age: ${copy.age}');
  print('🆔 Same ID: ${copy.id == original.id}');
  print('🔍 Different instances: ${!identical(copy, original)}');

  // Save the copy as a new user (remove ID to create new)
  copy.id = null;
  await copy.save();
  print('💾 Saved copy as new user (ID: ${copy.id})');
}

/// Demonstrate static ORM methods
Future<void> _demonstrateStaticMethods() async {
  print('\n🔍 Static ORM Methods');
  print('-' * 30);

  // Find by ID
  final user = await ActiveRecord.find<EnhancedOrmExample>(1);
  print('🔎 Found user by ID: ${user?.name}');

  // Find all users
  final allUsers = await ActiveRecord.fetchAll<EnhancedOrmExample>(
    orderBy: 'created_at ASC',
  );
  print('👥 All users count: ${allUsers.length}');

  // Find with conditions
  final youngUsers = await ActiveRecord.fetchAll<EnhancedOrmExample>(
    where: 'age < ?',
    parameters: [30],
    orderBy: 'age DESC',
  );
  print('👶 Young users (< 30): ${youngUsers.length}');

  // Count users
  final userCount = await ActiveRecord.count<EnhancedOrmExample>();
  print('🧮 Total user count: $userCount');

  // Check if users exist
  final hasAdults = await ActiveRecord.any<EnhancedOrmExample>(
    where: 'age >= ?',
    parameters: [18],
  );
  print('🎂 Has adult users: $hasAdults');

  // Create user using static method
  final newUser = await ActiveRecord.create<EnhancedOrmExample>({
    'name': 'Bob Wilson',
    'email': 'bob@example.com',
    'age': 35,
  });
  print('➕ Created user via static method: ${newUser.name}');
}

/// Demonstrate relationships
Future<void> _demonstrateRelationships() async {
  print('\n🔗 Relationships Demonstration');
  print('-' * 30);

  // Create some posts
  final user1 = await ActiveRecord.find<EnhancedOrmExample>(1);
  if (user1 == null) return;

  final post1 = await ActiveRecord.create<Post>({
    'title': 'My First Blog Post',
    'content': 'This is my first blog post content...',
    'user_id': user1.id,
  });

  final post2 = await ActiveRecord.create<Post>({
    'title': 'Learning Dart and Flutter',
    'content': 'Today I learned about Dart programming...',
    'user_id': user1.id,
  });

  print('📝 Created posts: "${post1.title}" and "${post2.title}"');

  // Create profile
  final profile = await ActiveRecord.create<Profile>({
    'user_id': user1.id,
    'bio': 'Software Developer passionate about Dart',
    'website': 'https://johndoe.dev',
  });

  print('👤 Created profile for ${user1.name}');

  // Demonstrate relationships
  print('\n🔄 Loading relationships...');

  // HasMany: User -> Posts
  final userPosts = await user1.posts;
  print('📚 ${user1.name} has ${userPosts.length} posts');

  // BelongsTo: Post -> User
  final postAuthor = await post1.author;
  print('✍️  "${post1.title}" was written by ${postAuthor?.name}');

  // HasOne: User -> Profile
  final userProfile = await user1.profile;
  print("🏠 ${user1.name}'s bio: ${userProfile?.bio}");

  // BelongsTo: Profile -> User
  final profileUser = await profile.user;
  print('👤 Profile belongs to: ${profileUser?.name}');
}

/// Demonstrate many-to-many relationships
Future<void> _demonstrateManyToMany() async {
  print('\n🔀 Many-to-Many Relationships');
  print('-' * 30);

  // Create roles
  final adminRole = await ActiveRecord.create<Role>({
    'name': 'Admin',
    'description': 'System administrator with full access',
  });

  final editorRole = await ActiveRecord.create<Role>({
    'name': 'Editor',
    'description': 'Content editor with publishing rights',
  });

  final viewerRole = await ActiveRecord.create<Role>({
    'name': 'Viewer',
    'description': 'Read-only access to content',
  });

  print('🏷️  Created roles: Admin, Editor, Viewer');

  // Create tags
  final dartTag = await ActiveRecord.create<Tag>({
    'name': 'Dart',
    'color': '#0175C2',
  });

  final flutterTag = await ActiveRecord.create<Tag>({
    'name': 'Flutter',
    'color': '#02569B',
  });

  print('🏷️  Created tags: Dart, Flutter');

  // Get users and posts
  final user1 = await ActiveRecord.find<EnhancedOrmExample>(1);
  final post1 = await ActiveRecord.find<Post>(1);

  if (user1 == null || post1 == null) return;

  // Attach roles to user (many-to-many)
  await user1.attach<Role>('user_roles', 'user_id', 'role_id', adminRole);
  await user1.attach<Role>('user_roles', 'user_id', 'role_id', editorRole);

  print('👤 Attached Admin and Editor roles to ${user1.name}');

  // Attach tags to post (many-to-many)
  await post1.attach<Tag>('post_tags', 'post_id', 'tag_id', dartTag);
  await post1.attach<Tag>('post_tags', 'post_id', 'tag_id', flutterTag);

  print('📝 Attached Dart and Flutter tags to "${post1.title}"');

  // Load many-to-many relationships
  final userRoles = await user1.roles;
  print("🎭 ${user1.name}'s roles: ${userRoles.map((r) => r.name).join(', ')}");

  final postTags = await post1.tags;
  print(
    '🏷️  "${post1.title}" tags: ${postTags.map((t) => t.name).join(', ')}',
  );

  // Demonstrate sync operation
  print('\n🔄 Syncing relationships...');

  // Sync user roles to only Viewer
  await user1.sync<Role>('user_roles', 'user_id', 'role_id', [viewerRole]);

  final newUserRoles = await user1.roles;
  print(
    "🎭 After sync, ${user1.name}'s roles: ${newUserRoles.map((r) => r.name).join(', ')}",
  );

  // Detach a tag from post
  await post1.detach<Tag>('post_tags', 'post_id', 'tag_id', flutterTag);

  final newPostTags = await post1.tags;
  print(
    '🏷️  After detach, "${post1.title}" tags: ${newPostTags.map((t) => t.name).join(', ')}',
  );
}
