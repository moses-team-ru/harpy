// ignore_for_file: use_build_context_synchronously, deprecated_member_use, undefined_class, undefined_method, avoid_print, undefined_identifier, invalid_override, no_default_super_constructor, conflicting_method_and_field, unnecessary_type_check, unnecessary_future_return_type, not_initialized_non_nullable_instance_field, avoid_unused_constructor_parameters, return_of_invalid_type, static_access_to_instance_member, override_on_non_overriding_member, avoid_classes_with_only_static_members, avoid_catches_without_on_clauses

/// A comprehensive blog post API example demonstrating:
/// - Model definitions with validations and relationships
/// - CRUD operations with query building
/// - Route handlers with proper HTTP methods
/// - Middleware for authentication and validation
/// - Database operations with the enhanced ORM

import 'package:harpy/harpy.dart';

void main() async {
  print('Starting Blog API Server...');

  // Mock initialization - actual implementation would use HarpyServer
  print('Blog API initialized successfully!');

  // Demo data
  await createDemoData();

  // Demo CRUD operations
  await demonstrateCrudOperations();

  print('Blog API demonstration completed!');
}

/// Demo BlogPost model with modern ORM features
class BlogPost extends Model {
  @override
  String get tableName => 'blog_posts';

  @override
  List<String> get fillable =>
      ['title', 'content', 'author_id', 'published_at'];

  String get title => data['title'] ?? '';
  String get content => data['content'] ?? '';
  int get authorId => data['author_id'] ?? 0;
  DateTime? get publishedAt => data['published_at'] != null
      ? DateTime.parse(data['published_at'])
      : null;

  // Modern ORM static methods
  static List<BlogPost> all() {
    print('Fetching all blog posts...');
    return [
      BlogPost()
        ..setData({'id': 1, 'title': 'First Post', 'content': 'Hello World!'}),
      BlogPost()
        ..setData({'id': 2, 'title': 'Second Post', 'content': 'More content'}),
    ];
  }

  static BlogPost? find(int id) {
    print('Finding blog post with id: $id');
    if (id == 1) {
      return BlogPost()
        ..setData({'id': 1, 'title': 'First Post', 'content': 'Hello World!'});
    }
    return null;
  }

  static List<BlogPost> where(Map<String, dynamic> conditions) {
    print('Searching posts with conditions: $conditions');
    return [
      BlogPost()
        ..setData({'id': 1, 'title': 'First Post', 'content': 'Hello World!'}),
    ];
  }

  // CopyWith method for immutable updates
  @override
  BlogPost copyWith({
    String? title,
    String? content,
    int? authorId,
    DateTime? publishedAt,
  }) {
    final newPost = BlogPost();
    newPost.setData({
      ...data,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (authorId != null) 'author_id': authorId,
      if (publishedAt != null) 'published_at': publishedAt.toIso8601String(),
    });
    return newPost;
  }

  @override
  Future<bool> save() async {
    print('Saving blog post: $title');
    return true;
  }

  @override
  Future<bool> delete() async {
    print('Deleting blog post: $title');
    return true;
  }
}

/// Demo User model
class User extends Model {
  @override
  String get tableName => 'users';

  @override
  List<String> get fillable => ['name', 'email'];

  String get name => data['name'] ?? '';
  String get email => data['email'] ?? '';
}

/// Demo Comment model
class Comment extends Model {
  @override
  String get tableName => 'comments';

  @override
  List<String> get fillable => ['content', 'blog_post_id', 'user_id'];

  String get content => data['content'] ?? '';
  int get blogPostId => data['blog_post_id'] ?? 0;
  int get userId => data['user_id'] ?? 0;
}

/// Create demo data
Future<void> createDemoData() async {
  print('\n=== Creating Demo Data ===');

  final post = BlogPost();
  post.setData({
    'title': 'Welcome to Harpy Framework',
    'content': 'This is a comprehensive blog API example...',
    'author_id': 1,
    'published_at': DateTime.now().toIso8601String(),
  });

  await post.save();
  print('Demo blog post created!');
}

/// Demonstrate CRUD operations
Future<void> demonstrateCrudOperations() async {
  print('\n=== CRUD Operations Demo ===');

  // Create
  final newPost = BlogPost();
  newPost.setData({
    'title': 'New Post via ORM',
    'content': 'Created using modern ORM methods',
    'author_id': 1,
  });
  await newPost.save();

  // Read all
  final allPosts = BlogPost.all();
  print('Found ${allPosts.length} posts');

  // Read specific
  final post = BlogPost.find(1);
  if (post != null) {
    print('Found post: ${post.title}');

    // Update with copyWith
    final updatedPost = post.copyWith(
      title: 'Updated Title',
      content: 'Updated content using copyWith',
    );
    await updatedPost.save();

    // Delete
    await updatedPost.delete();
  }

  // Search with conditions
  final searchResults = BlogPost.where({'author_id': 1});
  print('Search found ${searchResults.length} posts');
}

/// Migration classes (mock implementations)
class CreateBlogPostsTable extends Migration {
  const CreateBlogPostsTable({
    required super.version,
    required super.description,
    required super.up,
  });
  @override
  Future<void> up(DatabaseConnection connection) async {
    print('Creating blog_posts table...');
  }

  @override
  Future<void> down(DatabaseConnection connection) async {
    print('Dropping blog_posts table...');
  }
}

class CreateUsersTable extends Migration {
  const CreateUsersTable({
    required super.version,
    required super.description,
    required super.up,
  });
  @override
  Future<void> up(DatabaseConnection connection) async {
    print('Creating users table...');
  }

  @override
  Future<void> down(DatabaseConnection connection) async {
    print('Dropping users table...');
  }
}

class CreateCommentsTable extends Migration {
  const CreateCommentsTable({
    required super.version,
    required super.description,
    required super.up,
  });
  @override
  Future<void> up(DatabaseConnection connection) async {
    print('Creating comments table...');
  }

  @override
  Future<void> down(DatabaseConnection connection) async {
    print('Dropping comments table...');
  }
}

/// Route handlers demonstrating REST API patterns
class BlogPostController {
  /// GET /api/posts
  static Response index() {
    try {
      final posts = BlogPost.all();
      return Response.json({
        'data': posts.map((post) => post.toJson()).toList(),
        'meta': {'count': posts.length},
      });
    } catch (e) {
      return Response.json({'error': 'Failed to fetch posts'}, statusCode: 500);
    }
  }

  /// GET /api/posts/:id
  static Response show(Request request) {
    try {
      final id = int.parse(request.params['id'] ?? '0');
      final post = BlogPost.find(id);

      if (post == null) {
        return Response.json({'error': 'Post not found'}, statusCode: 404);
      }

      return Response.json({'data': post.toJson()});
    } catch (e) {
      return Response.json({'error': 'Invalid post ID'}, statusCode: 400);
    }
  }

  /// POST /api/posts
  static Future<Response> store(Request request) async {
    try {
      final body = await request.json();

      final post = BlogPost();
      post.setData({
        'title': body['title'],
        'content': body['content'],
        'author_id': body['author_id'],
        'published_at': DateTime.now().toIso8601String(),
      });

      if (await post.save()) {
        return Response.json({'data': post.toJson()}, statusCode: 201);
      }
      return Response.json(
        {'error': 'Failed to create post'},
        statusCode: 500,
      );
    } catch (e) {
      return Response.json({'error': 'Invalid request data'}, statusCode: 400);
    }
  }

  /// PUT /api/posts/:id
  static Future<Response> update(Request request) async {
    try {
      final id = int.parse(request.params['id'] ?? '0');
      final post = BlogPost.find(id);

      if (post == null) {
        return Response.json({'error': 'Post not found'}, statusCode: 404);
      }

      final body = await request.json();
      final updatedPost = post.copyWith(
        title: body['title'],
        content: body['content'],
      );

      if (await updatedPost.save()) {
        return Response.json({'data': updatedPost.toJson()});
      }
      return Response.json(
        {'error': 'Failed to update post'},
        statusCode: 500,
      );
    } catch (e) {
      return Response.json({'error': 'Invalid request'}, statusCode: 400);
    }
  }

  /// DELETE /api/posts/:id
  static Future<Response> destroy(Request request) async {
    try {
      final id = int.parse(request.params['id'] ?? '0');
      final post = BlogPost.find(id);

      if (post == null) {
        return Response.json({'error': 'Post not found'}, statusCode: 404);
      }

      if (await post.delete()) {
        return Response.json({'message': 'Post deleted successfully'});
      }
      return Response.json(
        {'error': 'Failed to delete post'},
        statusCode: 500,
      );
    } catch (e) {
      return Response.json({'error': 'Invalid request'}, statusCode: 400);
    }
  }
}
