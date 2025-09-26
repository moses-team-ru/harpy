import 'package:collection/collection.dart';
import 'package:harpy/harpy.dart';
import 'package:test/test.dart';

// Test models for database functionality
class ModelTest extends Model with ActiveRecord {
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
    final List<String> errors = <String>[];
    if (name == null || name!.trim().isEmpty) {
      errors.add('Name is required');
    }
    if (email == null || !_isValidEmailFormat(email!)) {
      errors.add('Valid email is required');
    }
    if (age != null && age! < 0) {
      errors.add('Age must be positive');
    }
    return errors;
  }

  bool _isValidEmailFormat(String emailString) {
    if (emailString.trim().isEmpty) return false;
    final List<String> parts = emailString.split('@');
    if (parts.length != 2) return false;
    final String? localPart = parts.elementAtOrNull(0);
    final String? domainPart = parts.elementAtOrNull(1);
    if (localPart == null || domainPart == null) return false;
    if (localPart.isEmpty || domainPart.isEmpty) return false;
    if (!domainPart.contains('.')) return false;
    final List<String> domainParts = domainPart.split('.');
    return domainParts.every((String part) => part.isNotEmpty);
  }
}

class Product extends Model with ActiveRecord {
  @override
  String get tableName => 'products';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  double? get price => get<double>('price');
  set price(double? value) => setAttribute('price', value);

  bool? get active => get<bool>('active');
  set active(bool? value) => setAttribute('active', value);

  @override
  List<String> validate() {
    final List<String> errors = <String>[];
    if (name == null || name!.trim().isEmpty) {
      errors.add('Product name is required');
    }
    if (price == null || price! <= 0) {
      errors.add('Price must be greater than 0');
    }
    return errors;
  }
}

void main() {
  group('Model Base Functionality', () {
    test('should create model instance with default values', () {
      final ModelTest user = ModelTest();

      expect(user.tableName, equals('users'));
      expect(user.exists, isFalse);
      expect(user.isDirty, isFalse);
      expect(user.id, isNull);
      expect(user.name, isNull);
      expect(user.email, isNull);
    });

    test('should set and get attributes correctly', () {
      final ModelTest user = ModelTest()
        ..name = 'John Doe'
        ..email = 'john@example.com'
        ..age = 30;

      expect(user.name, equals('John Doe'));
      expect(user.email, equals('john@example.com'));
      expect(user.age, equals(30));
      expect(user.isDirty, isTrue);
    });

    test('should track attribute changes', () {
      final ModelTest user = ModelTest()
        ..fillAttributes(<String, Object?>{
          'id': 1,
          'name': 'Original Name',
          'email': 'original@test.com',
          'age': 25,
        })
        ..markAsExisting();

      expect(user.isDirty, isFalse);
      expect(user.exists, isTrue);

      // Make changes to the model
      user
        ..name = 'Updated Name'
        ..age = 26;

      expect(user.isDirty, isTrue);

      final Map<String, Object?> changes = user.getChanges();
      expect(changes['name'], equals('Updated Name'));
      expect(changes['age'], equals(26));
      expect(changes.containsKey('email'), isFalse);
      expect(changes.length, equals(2));
    });

    test('should reset changes correctly', () {
      final ModelTest user = ModelTest()
        ..fillAttributes(<String, Object?>{
          'name': 'Original Name',
          'email': 'original@test.com',
        })
        ..markAsExisting()
        ..name = 'Updated Name';
      expect(user.isDirty, isTrue);

      user.reset();
      expect(user.name, equals('Original Name'));
      expect(user.isDirty, isFalse);
    });

    test('should serialize to JSON correctly', () {
      final ModelTest user = ModelTest()
        ..fillAttributes(<String, Object?>{
          'id': 42,
          'name': 'Jane Doe',
          'email': 'jane@example.com',
          'age': 28,
        });

      final Map<String, Object?> json = user.toJson();
      expect(json['id'], equals(42));
      expect(json['name'], equals('Jane Doe'));
      expect(json['email'], equals('jane@example.com'));
      expect(json['age'], equals(28));

      final String jsonString = user.toJsonString();
      expect(jsonString, contains('Jane Doe'));
      expect(jsonString, contains('jane@example.com'));
    });

    test('should handle null values in JSON serialization', () {
      final ModelTest user = ModelTest()
        ..name = 'Test User'
        ..email = null // Explicitly set to null
        ..age = null; // Explicitly set to null

      final Map<String, Object?> json = user.toJson();
      expect(json['name'], equals('Test User'));
      expect(json.containsKey('email'), isTrue);
      expect(json['email'], isNull);
      expect(json.containsKey('age'), isTrue);
      expect(json['age'], isNull);
    });
  });

  group('Model Validation', () {
    test('should validate required fields', () {
      final ModelTest user = ModelTest();

      final List<String> errors = user.validate();
      expect(errors.length, equals(2));
      expect(errors.elementAtOrNull(0), contains('Name is required'));
      expect(errors.elementAtOrNull(1), contains('Valid email is required'));
    });

    test('should validate email format', () {
      final ModelTest user = ModelTest()
        ..name = 'Test User'
        ..email = 'invalid-email';
      List<String> errors = user.validate();
      expect(
        errors.any((String e) => e.contains('Valid email is required')),
        isTrue,
      );

      user.email = 'test@';
      errors = user.validate();
      expect(
        errors.any((String e) => e.contains('Valid email is required')),
        isTrue,
      );

      user.email = '@example.com';
      errors = user.validate();
      expect(
        errors.any((String e) => e.contains('Valid email is required')),
        isTrue,
      );

      // Valid email
      user.email = 'test@example.com';
      errors = user.validate();
      expect(
        errors.where((String e) => e.contains('Valid email is required')),
        isEmpty,
      );
    });

    test('should validate age constraints', () {
      final ModelTest user = ModelTest()
        ..name = 'Test User'
        ..email = 'test@example.com'
        ..age = -5;
      List<String> errors = user.validate();
      expect(
        errors.any((String e) => e.contains('Age must be positive')),
        isTrue,
      );

      user.age = 0;
      errors = user.validate();
      expect(
        errors.where((String e) => e.contains('Age must be positive')),
        isEmpty,
      );

      user.age = 25;
      errors = user.validate();
      expect(
        errors.where((String e) => e.contains('Age must be positive')),
        isEmpty,
      );
    });

    test('should pass validation with valid data', () {
      final ModelTest user = ModelTest()
        ..name = 'Valid User'
        ..email = 'valid@example.com'
        ..age = 30;

      final List<String> errors = user.validate();
      expect(errors, isEmpty);
    });

    test('should validate product model', () {
      final Product product = Product();

      List<String> errors = product.validate();
      expect(errors.length, equals(2));
      expect(
        errors.any((String e) => e.contains('Product name is required')),
        isTrue,
      );
      expect(
        errors.any((String e) => e.contains('Price must be greater than 0')),
        isTrue,
      );

      product
        ..name = 'Test Product'
        ..price = 99.99;

      errors = product.validate();
      expect(errors, isEmpty);
    });
  });

  group('Model Equality and Hashing', () {
    test('should compare models by ID when both exist', () {
      final ModelTest user1 = ModelTest()..id = 1;
      final ModelTest user2 = ModelTest()..id = 1;
      final ModelTest user3 = ModelTest()..id = 2;

      expect(user1, equals(user2));
      expect(user1, isNot(equals(user3)));
      expect(user1.hashCode, equals(user2.hashCode));
    });

    test('should use identity comparison for new models', () {
      final ModelTest user1 = ModelTest();
      final ModelTest user2 = ModelTest();

      expect(user1, isNot(equals(user2)));
      expect(user1, equals(user1));
    });

    test('should handle mixed ID and null ID comparisons', () {
      final ModelTest user1 = ModelTest()..id = 1;
      final ModelTest user2 = ModelTest(); // no ID

      expect(user1, isNot(equals(user2)));
      expect(user2, isNot(equals(user1)));
    });
  });

  group('Model State Management', () {
    test('should track existing vs new model state', () {
      final ModelTest user = ModelTest();

      // New model
      expect(user.exists, isFalse);

      // Mark as existing
      user.markAsExisting();
      expect(user.exists, isTrue);
    });

    test('should handle dirty state tracking', () {
      final ModelTest user = ModelTest()
        ..fillAttributes(
          <String, Object?>{'name': 'Original', 'email': 'original@test.com'},
        )
        ..markAsExisting();

      expect(user.isDirty, isFalse);

      user.name = 'Modified';
      expect(user.isDirty, isTrue);
    });

    test('should fill attributes from map', () {
      final ModelTest user = ModelTest()
        ..fillAttributes(<String, Object?>{
          'id': 123,
          'name': 'Filled User',
          'email': 'filled@example.com',
          'age': 35,
          'unknown_field': 'ignored',
        });

      expect(user.id, equals(123));
      expect(user.name, equals('Filled User'));
      expect(user.email, equals('filled@example.com'));
      expect(user.age, equals(35));
      // Unknown fields should be stored but not accessible via getters
    });
  });

  group('Model Attribute Access', () {
    test('should handle typed attribute access', () {
      final ModelTest user = ModelTest()
        ..setAttribute('name', 'Test')
        ..setAttribute('age', 25)
        ..setAttribute('active', true);

      expect(user.get<String>('name'), equals('Test'));
      expect(user.get<int>('age'), equals(25));
      expect(user.get<bool>('active'), isTrue);
      expect(user.get<String>('nonexistent'), isNull);
    });

    test('should handle custom attributes', () {
      final ModelTest user = ModelTest()
        ..setAttribute('custom_field', 'custom_value');
      expect(user.get<String>('custom_field'), equals('custom_value'));

      // Test that we can check if attributes exist by trying to get them
      expect(user.get<String>('missing_field'), isNull);
    });
  });

  group('Model Collections and Bulk Operations', () {
    test('should handle multiple model creation', () {
      final List<Map<String, String>> users = <Map<String, String>>[
        <String, String>{'name': 'User 1', 'email': 'user1@test.com'},
        <String, String>{'name': 'User 2', 'email': 'user2@test.com'},
        <String, String>{'name': 'User 3', 'email': 'user3@test.com'},
      ];

      final List<ModelTest> models = users.map((Map<String, String> data) {
        final ModelTest user = ModelTest()..fillAttributes(data);
        return user;
      }).toList();

      expect(models.length, equals(3));
      expect(models.elementAtOrNull(0)?.name, equals('User 1'));
      expect(models.elementAtOrNull(1)?.name, equals('User 2'));
      expect(models.elementAtOrNull(2)?.name, equals('User 3'));

      // All should be valid
      for (final ModelTest user in models) {
        expect(user.validate(), isEmpty);
      }
    });

    test('should convert model collections to JSON', () {
      final List<ModelTest> users = <ModelTest>[
        ModelTest()
          ..fillAttributes(<String, Object?>{
            'id': 1,
            'name': 'User 1',
            'email': 'u1@test.com',
          }),
        ModelTest()
          ..fillAttributes(<String, Object?>{
            'id': 2,
            'name': 'User 2',
            'email': 'u2@test.com',
          }),
      ];

      final List<Map<String, Object?>> jsonList =
          users.map((ModelTest u) => u.toJson()).toList();

      expect(jsonList.length, equals(2));
      expect(jsonList.elementAtOrNull(0)?['name'], equals('User 1'));
      expect(jsonList.elementAtOrNull(1)?['name'], equals('User 2'));
    });
  });

  group('Edge Cases and Error Handling', () {
    test('should handle empty attribute names', () {
      final ModelTest user = ModelTest()

        // Empty string should be handled gracefully
        ..setAttribute('', 'value');
      expect(user.get<String>(''), equals('value'));
    });

    test('should handle very long attribute values', () {
      final ModelTest user = ModelTest();
      final String longString = 'a' * 10000;

      user.name = longString;
      expect(user.name, equals(longString));
      expect(user.name!.length, equals(10000));
    });

    test('should handle special characters in attributes', () {
      final ModelTest user = ModelTest()
        ..name = 'Test User с русскими символами 🎉'
        ..email = 'test+special@example.com';

      expect(user.name, contains('русскими'));
      expect(user.name, contains('🎉'));
      expect(user.email, contains('+'));

      final Map<String, Object?> json = user.toJson();
      expect(json['name'], contains('русскими'));
      expect(json['email'], contains('+'));
    });

    test('should handle type conversion edge cases', () {
      final ModelTest user = ModelTest()

        // Setting string as number
        ..setAttribute('age', '25');
      expect(user.get<String>('age'), equals('25'));

      // Getting as different type should return null or default
      user.setAttribute('active', 1);
      expect(user.get<int>('active'), equals(1));
    });
  });
}
