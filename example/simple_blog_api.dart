// Simple Blog API Example using Harpy Framework v0.1.24+1
// This example demonstrates basic REST API endpoints without complex ORM features
// ignore_for_file: file_names, avoid_print, cascade_invocations, avoid_catches_without_on_clauses, deprecated_member_use, undefined_method, avoid-nullable-interpolation

import 'package:harpy/harpy.dart';

// Simple BlogPost model using the new ORM system
class SimpleBlogApi extends Model with ActiveRecord {
  @override
  String get tableName => 'posts';

  String? get title => get<String>('title');
  set title(String? value) => setAttribute('title', value);

  String? get content => get<String>('content');
  set content(String? value) => setAttribute('content', value);

  String? get author => get<String>('author');
  set author(String? value) => setAttribute('author', value);

  bool get published => get<bool>('published') ?? false;
  set published(bool value) => setAttribute('published', value);

  @override
  List<String> validate() {
    final List<String> errors = <String>[];
    if (title == null || title!.isEmpty) {
      errors.add('Title is required');
    }
    if (content == null || content!.isEmpty) {
      errors.add('Content is required');
    }
    if (author == null || author!.isEmpty) {
      errors.add('Author is required');
    }
    return errors;
  }
}

void main() async {
  final app = Harpy();

  // Register the model for the new ORM system
  ModelRegistry.register<SimpleBlogApi>(SimpleBlogApi.new);

  // Connect to SQLite database for simplicity
  await app.connectToDatabase({'type': 'sqlite', 'path': './blog.db'});

  // Enable middleware
  app
    ..enableCors()
    ..enableLogging(logBody: true);

  // API Routes
  app
    // Root endpoint
    ..get(
      '/',
      (req, res) => res.json({
        'message': 'Simple Blog API',
        'version': '1.0.0',
        'framework': 'Harpy v0.1.24+1',
      }),
    )

    // Get all posts (simplified)
    ..get('/posts', (req, res) {
      final posts = <Map<String, Object?>>[
        {
          'id': 1,
          'title': 'Welcome to Harpy',
          'content': 'This is a sample blog post using Harpy Framework',
          'author': 'Harpy Team',
          'published': true,
        },
        {
          'id': 2,
          'title': 'Getting Started',
          'content': 'Learn how to build APIs with Harpy',
          'author': 'Developer',
          'published': true,
        },
      ];

      return res.json({'posts': posts, 'count': posts.length});
    })

    // Get single post
    ..get('/posts/:id', (req, res) {
      final id = req.params['id'];

      // Mock data for demo
      final post = {
        'id': int.tryParse(id ?? '0') ?? 0,
        'title': 'Sample Post $id',
        'content': 'This is the content for post $id',
        'author': 'Sample Author',
        'published': true,
      };

      return res.json({'post': post});
    })

    // Create new post
    ..post('/posts', (req, res) async {
      try {
        final data = await req.json();

        // Create new post instance
        final post = SimpleBlogApi()
          ..title = data['title'] as String?
          ..content = data['content'] as String?
          ..author = data['author'] as String?
          ..published = data['published'] as bool? ?? false;

        // Validate
        final errors = post.validate();
        if (errors.isNotEmpty) {
          return res.badRequest({'errors': errors});
        }

        // In a real app, you would save to database here
        // await post.save();

        return res.created({
          'message': 'Post created successfully',
          'post': post.toJson(),
        });
      } catch (e) {
        return res.internalServerError({
          'error': 'Failed to create post: $e',
        });
      }
    })

    // Update post
    ..put('/posts/:id', (req, res) async {
      try {
        final id = req.params['id'];
        final data = await req.json();

        // Mock update response
        return res.json({
          'message': 'Post $id updated successfully',
          'data': data,
        });
      } catch (e) {
        return res.internalServerError({
          'error': 'Failed to update post: $e',
        });
      }
    })

    // Delete post
    ..delete('/posts/:id', (req, res) {
      final id = req.params['id'];

      return res.json({'message': 'Post $id deleted successfully'});
    });

  // Start the server
  try {
    await app.listen(port: 3001);
    print('🚀 Simple Blog API running on http://localhost:3001');
    print('📝 Available endpoints:');
    print('  GET    / - API info');
    print('  GET    /posts - List all posts');
    print('  GET    /posts/:id - Get single post');
    print('  POST   /posts - Create new post');
    print('  PUT    /posts/:id - Update post');
    print('  DELETE /posts/:id - Delete post');
  } catch (e) {
    print('❌ Failed to start server: $e');
    await app.close();
  }
}
