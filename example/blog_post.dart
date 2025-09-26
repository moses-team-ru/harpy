// ignore_for_file: avoid_print, avoid-dynamic

import 'package:harpy/harpy.dart';

// Blog post model for MongoDB
class BlogPost extends Model with ActiveRecord {
  @override
  String get tableName => 'posts'; // Collection name in MongoDB

  String? get title => get<String>('title');
  set title(String? value) => setAttribute('title', value);

  String? get content => get<String>('content');
  set content(String? value) => setAttribute('content', value);

  String? get author => get<String>('author');
  set author(String? value) => setAttribute('author', value);

  List<String>? get tags => get<List<String>>('tags');
  set tags(List<String>? value) => setAttribute('tags', value);

  bool? get published => get<bool>('published');
  set published(bool? value) => setAttribute('published', value);

  int? get viewCount => get<int>('view_count');
  set viewCount(int? value) => setAttribute('view_count', value);

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
  final Harpy app = Harpy();

  // Connect to MongoDB
  await app.connectToDatabase(<String, dynamic>{
    'type': 'mongodb',
    'uri': 'mongodb://localhost:27017/blog',
    // Alternative configuration:
    // 'host': 'localhost',
    // 'port': 27017,
    // 'database': 'blog',
    // 'username': 'user',
    // 'password': 'password',
  });

  // Register models (no migrations needed for MongoDB)
  app.database?.registerModel<BlogPost>('posts', BlogPost.new);

  // Middleware
  app
    ..enableCors()
    ..enableLogging(logBody: true)

    // Routes
    ..get(
      '/',
      (Request req, Response res) => res.json(<String, String>{
        'message': 'Blog API with MongoDB',
        'version': '1.0.0',
        'database': 'MongoDB NoSQL',
      }),
    )

    // Get all blog posts with pagination and filtering
    ..get('/posts', (Request req, Response res) async {
      try {
        final QueryBuilder<BlogPost> query = app.database!.table<BlogPost>();

        // Filtering
        final String? author = req.query['author'];
        if (author != null) {
          query.where('author', author);
        }

        final String? published = req.query['published'];
        if (published != null) {
          query.where('published', published.toLowerCase() == 'true');
        }

        final String? tag = req.query['tag'];
        if (tag != null) {
          // MongoDB array query (in real implementation)
          query.where('tags', tag); // This would be: {"tags": {"$in": [tag]}}
        }

        // Text search (MongoDB full-text search)
        final String? search = req.query['search'];
        if (search != null) {
          // In real MongoDB implementation, this would use $text search
          query.whereLike('title', '%$search%');
        }

        // Sorting
        final String sortBy = req.query['sort_by'] ?? 'created_at';
        final String sortOrder = req.query['sort_order'] ?? 'DESC';
        query.orderBy(sortBy, sortOrder);

        // Pagination
        final int page = int.tryParse(req.query['page'] ?? '1') ?? 1;
        final int limit = int.tryParse(req.query['limit'] ?? '10') ?? 10;
        final int offset = (page - 1) * limit;

        query.limit(limit).offset(offset);

        final List<BlogPost> posts = await query.get();
        final int total = await app.database!.table<BlogPost>().count();

        return res.json(<String, Object>{
          'posts': posts.map((BlogPost p) => p.toJson()).toList(),
          'pagination': <String, int>{
            'page': page,
            'limit': limit,
            'total': total,
            'pages': (total / limit).ceil(),
          },
        });
      } on Exception catch (e) {
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    })

    // Get single blog post and increment view count
    ..get('/posts/:id', (Request req, Response res) async {
      try {
        final String? id = req.params['id'];
        if (id == null) {
          return res
              .badRequest(<String, String>{'error': 'Post ID is required'});
        }

        final ModelRegistry<BlogPost> postRegistry =
            app.database!.getModelRegistry<BlogPost>();
        final BlogPost? post = await postRegistry.find(id); // MongoDB ObjectId

        if (post == null) {
          return res.notFound(<String, String>{'error': 'Post not found'});
        }

        // Increment view count
        post
          ..viewCount = (post.viewCount ?? 0) + 1
          ..connection = app.database!.connection;
        await post.save();

        return res.json(<String, Map<String, Object?>>{'post': post.toJson()});
      } on Exception catch (e) {
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    })

    // Create new blog post
    ..post('/posts', (Request req, Response res) async {
      try {
        final Map<String, dynamic> data = await req.json();

        final BlogPost post = BlogPost()
          ..title = data['title'] as String?
          ..content = data['content'] as String?
          ..author = data['author'] as String?
          ..tags = (data['tags'] as List<dynamic>?)?.cast<String>()
          ..published = data['published'] as bool? ?? false
          ..viewCount = 0
          ..connection = app.database!.connection;

        await post.save();

        return res
            .created(<String, Map<String, Object?>>{'post': post.toJson()});
      } on Exception catch (e) {
        if (e is ValidationException) {
          return res.badRequest(<String, String>{'error': e.message});
        }
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    })

    // Update blog post
    ..put('/posts/:id', (Request req, Response res) async {
      try {
        final String? id = req.params['id'];
        if (id == null) {
          return res
              .badRequest(<String, String>{'error': 'Post ID is required'});
        }

        final ModelRegistry<BlogPost> postRegistry =
            app.database!.getModelRegistry<BlogPost>();
        final BlogPost? post = await postRegistry.find(id);

        if (post == null) {
          return res.notFound(<String, String>{'error': 'Post not found'});
        }

        final Map<String, dynamic> data = await req.json();

        if (data['title'] != null) post.title = data['title'] as String;
        if (data['content'] != null) post.content = data['content'] as String;
        if (data['author'] != null) post.author = data['author'] as String;
        if (data['tags'] != null) {
          post.tags = (data['tags'] as List<dynamic>).cast<String>();
        }
        if (data['published'] != null) {
          post.published = data['published'] as bool;
        }

        post.connection = app.database!.connection;
        await post.save();

        return res.json(<String, Map<String, Object?>>{'post': post.toJson()});
      } on Exception catch (e) {
        if (e is ValidationException) {
          return res.badRequest(<String, String>{'error': e.message});
        }
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    })

    // Delete blog post
    ..delete('/posts/:id', (Request req, Response res) async {
      try {
        final String? id = req.params['id'];
        if (id == null) {
          return res
              .badRequest(<String, String>{'error': 'Post ID is required'});
        }

        final ModelRegistry<BlogPost> postRegistry =
            app.database!.getModelRegistry<BlogPost>();
        final BlogPost? post = await postRegistry.find(id);

        if (post == null) {
          return res.notFound(<String, String>{'error': 'Post not found'});
        }

        post.connection = app.database!.connection;
        await post.delete();

        return res
            .json(<String, String>{'message': 'Post deleted successfully'});
      } on Exception catch (e) {
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    })

    // Get posts by tag (MongoDB-specific query)
    ..get('/tags/:tag/posts', (Request req, Response res) async {
      try {
        final String? tag = req.params['tag'];
        if (tag == null) {
          return res.badRequest(<String, String>{'error': 'Tag is required'});
        }

        // In real MongoDB implementation, this would use:
        // db.posts.find({"tags": {"$in": [tag]}})
        final List<BlogPost> posts = await app.database!
            .table<BlogPost>()
            .where('tags', tag) // Simplified for demo
            .where('published', true)
            .orderBy('created_at', 'DESC')
            .get();

        return res.json(<String, Object>{
          'tag': tag,
          'posts': posts.map((BlogPost p) => p.toJson()).toList(),
          'count': posts.length,
        });
      } on Exception catch (e) {
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    })

    // Get popular posts (by view count)
    ..get('/posts/popular', (Request req, Response res) async {
      try {
        final int limit = int.tryParse(req.query['limit'] ?? '5') ?? 5;

        final List<BlogPost> posts = await app.database!
            .table<BlogPost>()
            .where('published', true)
            .orderBy('view_count', 'DESC')
            .limit(limit)
            .get();

        return res.json(<String, List<Map<String, Object?>>>{
          'popular_posts': posts.map((BlogPost p) => p.toJson()).toList(),
        });
      } on Exception catch (e) {
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    })

    // Get all unique tags
    ..get('/tags', (Request req, Response res) async {
      try {
        // In real MongoDB, this would use aggregation pipeline:
        // db.posts.aggregate([
        //   {$unwind: "$tags"},
        //   {$group: {_id: "$tags", count: {$sum: 1}}},
        //   {$sort: {count: -1}}
        // ])

        final List<BlogPost> posts = await app.database!
            .table<BlogPost>()
            .where('published', true)
            .get();

        final Map<String, int> tagCounts = <String, int>{};
        for (final BlogPost post in posts) {
          final List<String> tags = post.tags ?? <String>[];
          for (final String tag in tags) {
            tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
          }
        }

        final List<MapEntry<String, int>> sortedTags = tagCounts.entries
            .toList()
          ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
              b.value.compareTo(a.value));

        return res.json(<String, List<Map<String, Object>>>{
          'tags': sortedTags
              .map((MapEntry<String, int> entry) => <String, Object>{
                    'name': entry.key,
                    'count': entry.value,
                  })
              .toList(),
        });
      } on Exception catch (e) {
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    })

    // Statistics
    ..get('/stats', (Request req, Response res) async {
      try {
        final int totalPosts = await app.database!.table<BlogPost>().count();
        final int publishedPosts = await app.database!
            .table<BlogPost>()
            .where('published', true)
            .count();

        // Get all posts to calculate total views (in real MongoDB, use aggregation)
        final List<BlogPost> posts =
            await app.database!.table<BlogPost>().get();
        final int totalViews = posts.fold<int>(
          0,
          (int sum, BlogPost post) => sum + (post.viewCount ?? 0),
        );

        return res.json(<String, Map<String, num>>{
          'stats': <String, num>{
            'total_posts': totalPosts,
            'published_posts': publishedPosts,
            'draft_posts': totalPosts - publishedPosts,
            'total_views': totalViews,
            'average_views': totalPosts > 0 ? totalViews / totalPosts : 0,
          },
        });
      } on Exception catch (e) {
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    });

  // Start server
  try {
    await app.serve(port: 3002);
    print('🚀 Blog API running on http://localhost:3002');
    print('🍃 Connected to MongoDB database');
    print('📖 Available endpoints:');
    print('  GET    /posts - List posts with filtering');
    print('  GET    /posts/:id - Get single post');
    print('  POST   /posts - Create post');
    print('  PUT    /posts/:id - Update post');
    print('  DELETE /posts/:id - Delete post');
    print('  GET    /tags/:tag/posts - Posts by tag');
    print('  GET    /posts/popular - Popular posts');
    print('  GET    /tags - All tags with counts');
    print('  GET    /stats - Blog statistics');
  } on Exception catch (e) {
    print('❌ Failed to start server: $e');
    await app.close();
  }
}
