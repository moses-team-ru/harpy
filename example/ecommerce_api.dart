// ignore_for_file: avoid_print, avoid-dynamic

import 'package:harpy/harpy.dart';

// Product model example
class EcommerceApi extends Model with ActiveRecord {
  @override
  String get tableName => 'products';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get description => get<String>('description');
  set description(String? value) => setAttribute('description', value);

  double? get price => get<double>('price');
  set price(double? value) => setAttribute('price', value);

  int? get categoryId => get<int>('category_id');
  set categoryId(int? value) => setAttribute('category_id', value);

  bool? get isActive => get<bool>('is_active');
  set isActive(bool? value) => setAttribute('is_active', value);

  @override
  List<String> validate() {
    final List<String> errors = <String>[];

    if (name == null || name!.isEmpty) {
      errors.add('Product name is required');
    }

    if (price == null || price! < 0) {
      errors.add('Price must be positive');
    }

    return errors;
  }
}

// Category model example
class Category extends Model with ActiveRecord {
  @override
  String get tableName => 'categories';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get description => get<String>('description');
  set description(String? value) => setAttribute('description', value);

  @override
  List<String> validate() {
    final List<String> errors = <String>[];

    if (name == null || name!.isEmpty) {
      errors.add('Category name is required');
    }

    return errors;
  }
}

void main() async {
  final Harpy app = Harpy();

  // Connect to PostgreSQL database
  await app.connectToDatabase(<String, dynamic>{
    'type': 'postgresql',
    'host': 'localhost',
    'port': 5432,
    'database': 'ecommerce',
    'username': 'postgres',
    'password': 'password',
  });

  // Register models
  app.database?.registerModel<Category>('categories', Category.new);
  app.database?.registerModel<EcommerceApi>('products', EcommerceApi.new);

  // Setup migrations
  final MigrationManager migrationManager =
      MigrationManager(app.database!.connection)

        // Categories table migration
        ..addMigration(Migration(
          version: '001',
          description: 'Create categories table',
          up: (SchemaBuilder schema) async {
            await schema.createTable('categories', (TableBuilder table) {
              table
                ..id()
                ..string('name', nullable: false)
                ..text('description')
                ..timestamps()
                ..unique(<String>['name']);
            });
          },
          down: (SchemaBuilder schema) async {
            await schema.dropTable('categories');
          },
        ))

        // Products table migration
        ..addMigration(Migration(
          version: '002',
          description: 'Create products table',
          up: (SchemaBuilder schema) async {
            await schema.createTable('products', (TableBuilder table) {
              table
                ..id()
                ..string('name', nullable: false)
                ..text('description')
                ..decimal('price', nullable: false)
                ..foreignKey('category_id', 'categories')
                ..boolean('is_active', defaultValue: true)
                ..timestamps()
                ..index(<String>['category_id'])
                ..index(<String>['price']);
            });
          },
          down: (SchemaBuilder schema) async {
            await schema.dropTable('products');
          },
        ));

  await migrationManager.migrate();

  // Middleware
  app

    /// Enable CORS
    ..enableCors()

    /// Enable logging
    ..enableLogging()
    // Add authentication
    ..enableAuth(
      jwtSecret: 'your-secret-key',
      excludePaths: <String>['/auth/login', '/health', '/'],
    )

    // Routes
    ..get(
      '/',
      (Request req, Response res) => res.json(<String, String>{
        'message': 'E-commerce API with PostgreSQL',
        'version': '1.0.0',
      }),
    )

    // Categories endpoints
    ..get('/categories', (Request req, Response res) async {
      try {
        final ModelRegistry<Category> categoryRegistry =
            app.database!.getModelRegistry<Category>();
        final List<Category> categories = await categoryRegistry.all();

        return res.json(<String, List<Map<String, Object?>>>{
          'categories': categories.map((Category c) => c.toJson()).toList(),
        });
      } on Exception catch (e) {
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    })
    ..post('/categories', (Request req, Response res) async {
      try {
        final Map<String, dynamic> data = await req.json();

        final Category category = Category()
          ..name = data['name'] as String?
          ..description = data['description'] as String?
          ..connection = app.database!.connection;

        await category.save();

        return res.created(
          <String, Map<String, Object?>>{'category': category.toJson()},
        );
      } on Exception catch (e) {
        return res.badRequest(<String, String>{'error': e.toString()});
      }
    })

    // Products endpoints with advanced queries
    ..get('/products', (Request req, Response res) async {
      try {
        final QueryBuilder<EcommerceApi> query =
            app.database!.table<EcommerceApi>();

        // Filtering
        final String? categoryId = req.query['category_id'];
        if (categoryId != null) {
          query.where('category_id', int.parse(categoryId));
        }

        final String? minPrice = req.query['min_price'];
        if (minPrice != null) {
          query.where('price', double.parse(minPrice), '>=');
        }

        final String? maxPrice = req.query['max_price'];
        if (maxPrice != null) {
          query.where('price', double.parse(maxPrice), '<=');
        }

        final String? search = req.query['search'];
        if (search != null) {
          query.whereLike('name', '%$search%');
        }

        final String? isActive = req.query['active'];
        if (isActive != null) {
          query.where('is_active', isActive.toLowerCase() == 'true');
        }

        // Sorting
        final String sortBy = req.query['sort_by'] ?? 'name';
        final String sortOrder = req.query['sort_order'] ?? 'ASC';
        query.orderBy(sortBy, sortOrder);

        // Pagination
        final int page = int.tryParse(req.query['page'] ?? '1') ?? 1;
        final int limit = int.tryParse(req.query['limit'] ?? '10') ?? 10;
        final int offset = (page - 1) * limit;

        query.limit(limit).offset(offset);

        final List<EcommerceApi> products = await query.get();
        final int total = await app.database!.table<EcommerceApi>().count();

        return res.json(<String, Object>{
          'products': products.map((EcommerceApi p) => p.toJson()).toList(),
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
    ..post('/products', (Request req, Response res) async {
      try {
        final Map<String, dynamic> data = await req.json();

        final EcommerceApi product = EcommerceApi()
          ..name = data['name'] as String?
          ..description = data['description'] as String?
          ..price = (data['price'] as num?)?.toDouble()
          ..categoryId = data['category_id'] as int?
          ..isActive = data['is_active'] as bool? ?? true
          ..connection = app.database!.connection;

        await product.save();

        return res.created(
          <String, Map<String, Object?>>{'product': product.toJson()},
        );
      } on Exception catch (e) {
        if (e is ValidationException) {
          return res.badRequest(<String, String>{'error': e.message});
        }
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    })

    // Batch operations
    ..post('/products/batch', (Request req, Response res) async {
      try {
        final Map<String, dynamic> data = await req.json();
        final List productsList = data['products'] as List<dynamic>;

        final List<Map<String, dynamic>> createdProducts =
            <Map<String, dynamic>>[];

        // Use transaction for batch operations
        await app.database!
            .transaction((DatabaseTransaction transaction) async {
          for (final productData in productsList) {
            final EcommerceApi product = EcommerceApi()
              ..name = productData['name'] as String?
              ..description = productData['description'] as String?
              ..price = (productData['price'] as num?)?.toDouble()
              ..categoryId = productData['category_id'] as int?
              ..isActive = productData['is_active'] as bool? ?? true
              ..connection = app.database!.connection;

            await product.save();
            createdProducts.add(product.toJson());
          }
        });

        return res.created(<String, Object>{
          'products': createdProducts,
          'count': createdProducts.length,
        });
      } on Exception catch (e) {
        return res.badRequest(<String, String>{'error': e.toString()});
      }
    })

    // Statistics endpoint
    ..get('/stats', (Request req, Response res) async {
      try {
        final int totalProducts =
            await app.database!.table<EcommerceApi>().count();
        final int activeProducts = await app.database!
            .table<EcommerceApi>()
            .where('is_active', true)
            .count();
        final int totalCategories =
            await app.database!.table<Category>().count();

        // Advanced aggregation would require raw SQL in real implementation
        final Map<String, Map<String, int>> stats = <String, Map<String, int>>{
          'products': <String, int>{
            'total': totalProducts,
            'active': activeProducts,
            'inactive': totalProducts - activeProducts,
          },
          'categories': <String, int>{'total': totalCategories},
        };

        return res
            .json(<String, Map<String, Map<String, int>>>{'stats': stats});
      } on Exception catch (e) {
        return res.internalServerError(<String, String>{'error': e.toString()});
      }
    });

  // Start server
  try {
    await app.serve(port: 3001);
    print('🚀 E-commerce API running on http://localhost:3001');
    print('🐘 Connected to PostgreSQL database');
  } on Exception catch (e) {
    print('❌ Failed to start server: $e');
    await app.close();
  }
}
