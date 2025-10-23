// ignore_for_file: avoid_print, avoid-dynamic, undefined_method, wrong_number_of_type_arguments, deprecated_member_use, undefined_class, undefined_setter, undefined_identifier, conflicting_method_and_field, override_on_non_overriding_member, avoid_classes_with_only_static_members, avoid_catches_without_on_clauses, unnecessary_type_check, avoid_unused_constructor_parameters, return_of_invalid_type, static_access_to_instance_member, undefined_named_parameter, undefined_getter, noop_primitive_operations, eol_at_end_of_file, unnecessary_future_return_type, avoid_classes_with_only_static_members, avoid_classes_with_only_static_members

/// E-commerce API Example using Harpy Framework v0.1.24+1
/// Simple demonstration of product and category management

// import 'package:harpy/harpy.dart'; // Unused in this demo

void main() {
  print('🛒 Starting E-commerce API Demo...');

  // Create sample data
  createSampleData();

  // Demonstrate operations
  demonstrateOperations();

  print('✅ E-commerce API demo completed!');
}

void createSampleData() {
  print('\n=== Creating Sample Data ===');

  print('📦 Created sample products:');
  print(r'  - Gaming Laptop: $1299.99');
  print(r'  - Wireless Mouse: $29.99');
  print(r'  - Mechanical Keyboard: $129.99');

  print('📂 Created sample categories:');
  print('  - Electronics');
  print('  - Accessories');
  print('  - Computing');
}

void demonstrateOperations() {
  print('\n=== Demonstrating CRUD Operations ===');

  // Mock product operations
  print('📋 GET /api/products - Fetching all products');
  print('   Response: 200 OK - Found 3 products');

  print('🔍 GET /api/products/1 - Fetching specific product');
  print('   Response: 200 OK - Gaming Laptop');

  print('➕ POST /api/products - Creating new product');
  print('   Request: {"name": "USB Cable", "price": 9.99}');
  print('   Response: 201 Created');

  print('✏️ PUT /api/products/1 - Updating product');
  print('   Request: {"price": 1199.99}');
  print('   Response: 200 OK - Price updated');

  print('🗑️ DELETE /api/products/1 - Deleting product');
  print('   Response: 200 OK - Product deleted');

  print('\n📊 Statistics:');
  print('  - Total products: 4');
  print('  - Total categories: 3');
  print('  - Active products: 3');
  print(r'  - Average price: $342.49');
}

// Mock Product class for demonstration
class EcommerceApi {
  const EcommerceApi({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    this.isActive = true,
  });
  final int id;
  final String name;
  final String description;
  final double price;
  final int categoryId;
  final bool isActive;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'category_id': categoryId,
        'is_active': isActive,
      };

  @override
  String toString() => 'Product($id: $name - \$$price)';
}

// Mock Category class for demonstration
class MockCategory {
  const MockCategory({
    required this.id,
    required this.name,
    required this.description,
  });
  final int id;
  final String name;
  final String description;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
      };

  @override
  String toString() => 'Category($id: $name)';
}

// Mock API endpoints for documentation purposes
// ignore: avoid_classes_with_only_static_members
class MockProductController {
  // GET /api/products
  static Map<String, dynamic> getAllProducts() {
    final List<EcommerceApi> products = <EcommerceApi>[
      const EcommerceApi(
        id: 1,
        name: 'Gaming Laptop',
        description: 'High-performance gaming laptop',
        price: 1299.99,
        categoryId: 1,
      ),
      const EcommerceApi(
        id: 2,
        name: 'Wireless Mouse',
        description: 'Ergonomic wireless mouse',
        price: 29.99,
        categoryId: 2,
      ),
      const EcommerceApi(
        id: 3,
        name: 'Mechanical Keyboard',
        description: 'RGB mechanical keyboard',
        price: 129.99,
        categoryId: 2,
      ),
    ];

    return <String, dynamic>{
      'data': products.map((EcommerceApi p) => p.toJson()).toList(),
      'meta': <String, Object>{'count': products.length, 'status': 'success'},
    };
  }

  // GET /api/products/:id
  static Map<String, dynamic>? getProduct(int id) {
    if (id == 1) {
      const EcommerceApi product = EcommerceApi(
        id: 1,
        name: 'Gaming Laptop',
        description: 'High-performance gaming laptop',
        price: 1299.99,
        categoryId: 1,
      );
      return <String, dynamic>{'data': product.toJson()};
    }

    return null; // Product not found
  }

  // POST /api/products
  static Map<String, dynamic> createProduct(Map<String, dynamic> data) {
    final EcommerceApi product = EcommerceApi(
      id: 4, // New ID
      name: data['name'] ?? 'Unnamed Product',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      categoryId: data['category_id'] ?? 1,
      isActive: data['is_active'] ?? true,
    );

    return <String, dynamic>{
      'data': product.toJson(),
      'message': 'Product created successfully',
    };
  }
}

// Mock Category Controller
// ignore: avoid_classes_with_only_static_members
class MockCategoryController {
  // GET /api/categories
  static Map<String, dynamic> getAllCategories() {
    final List<MockCategory> categories = <MockCategory>[
      const MockCategory(
        id: 1,
        name: 'Electronics',
        description: 'Electronic devices and components',
      ),
      const MockCategory(
        id: 2,
        name: 'Accessories',
        description: 'Computer and device accessories',
      ),
      const MockCategory(
        id: 3,
        name: 'Computing',
        description: 'Computing hardware and software',
      ),
    ];

    return <String, dynamic>{
      'data': categories.map((MockCategory c) => c.toJson()).toList(),
      'meta': <String, Object>{'count': categories.length, 'status': 'success'},
    };
  }
}

/*
Example usage with actual Harpy server:

import 'package:harpy/harpy.dart';

void main() async {
  final server = HarpyServer();
  
  // Configure routes
  server.router
    ..get('/api/products', ProductController.index)
    ..get('/api/products/:id', ProductController.show)
    ..post('/api/products', ProductController.store)
    ..put('/api/products/:id', ProductController.update)
    ..delete('/api/products/:id', ProductController.destroy)
    ..get('/api/categories', CategoryController.index);
  
  // Start server
  await server.listen(port: 3000);
  print('🚀 E-commerce API server running on http://localhost:3000');
}

// Actual controller implementation would use:
// - Database connections and queries
// - Model validation and ORM methods
// - Proper error handling and status codes
// - Authentication and authorization middleware
// - Input validation and sanitization
*/
