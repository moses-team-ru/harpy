// ignore_for_file: file_names
import 'package:collection/collection.dart';
import 'package:harpy/harpy.dart';
import 'package:test/test.dart';

void main() {
  group('ModelRegistry', () {
    // Test model with single primary key
    late ModelRegistryTest Function() userConstructor;
    late TestOrderItem Function() orderItemConstructor;

    setUp(() {
      // Clear registry before each test
      ModelRegistry.clear();

      // Define constructors
      userConstructor = ModelRegistryTest.new;
      orderItemConstructor = TestOrderItem.new;

      // Register test models
      ModelRegistry.register<ModelRegistryTest>(userConstructor);
      ModelRegistry.register<TestOrderItem>(orderItemConstructor);
    });

    test('should register and create models', () {
      expect(ModelRegistry.isRegistered<ModelRegistryTest>(), isTrue);
      expect(ModelRegistry.isRegistered<TestOrderItem>(), isTrue);
      expect(ModelRegistry.isRegistered<UnregisteredModel>(), isFalse);

      final user = ModelRegistry.create<ModelRegistryTest>();
      expect(user, isA<ModelRegistryTest>());
      expect(user.tableName, equals('users'));

      final orderItem = ModelRegistry.create<TestOrderItem>();
      expect(orderItem, isA<TestOrderItem>());
      expect(orderItem.tableName, equals('order_items'));
    });

    test('should throw exception for unregistered model', () {
      expect(
        () => ModelRegistry.create<UnregisteredModel>(),
        throwsA(isA<ModelNotRegisteredException>()),
      );
    });

    test('should create model from JSON', () {
      final user = ModelRegistry.fromJson<ModelRegistryTest>({
        'id': 1,
        'name': 'John Doe',
        'email': 'john@example.com',
        'age': 30,
      });

      expect(user.id, equals(1));
      expect(user.name, equals('John Doe'));
      expect(user.email, equals('john@example.com'));
      expect(user.age, equals(30));
      expect(
        user.exists,
        isTrue,
      ); // Should be marked as existing because id is set
    });

    test('should create models from JSON list', () {
      final users = ModelRegistry.fromJsonList<ModelRegistryTest>([
        {'id': 1, 'name': 'John', 'email': 'john@test.com'},
        {'id': 2, 'name': 'Jane', 'email': 'jane@test.com'},
      ]);

      expect(users.length, equals(2));
      expect(users.elementAtOrNull(0)?.name, equals('John'));
      expect(users.elementAtOrNull(1)?.name, equals('Jane'));
      expect(users.every((user) => user.exists), isTrue);
    });

    test('should get registered types', () {
      final types = ModelRegistry.getRegisteredTypes();
      expect(types.contains(ModelRegistryTest), isTrue);
      expect(types.contains(TestOrderItem), isTrue);
      expect(types.length, equals(2));
    });

    test('should clear all registrations', () {
      expect(ModelRegistry.isRegistered<ModelRegistryTest>(), isTrue);
      ModelRegistry.clear();
      expect(ModelRegistry.isRegistered<ModelRegistryTest>(), isFalse);
    });
  });

  group('Primary Key Management', () {
    setUp(() {
      ModelRegistry.clear();
      ModelRegistry.register<ModelRegistryTest>(ModelRegistryTest.new);
      ModelRegistry.register<TestOrderItem>(TestOrderItem.new);
    });

    test('should handle single primary key', () {
      final user = ModelRegistryTest()..id = 42;

      expect(user.primaryKeys, equals(['id']));
      expect(user.getPrimaryKeyValue(), equals(42));

      user.setPrimaryKeyValue(100);
      expect(user.id, equals(100));
    });

    test('should handle composite primary key', () {
      final item = TestOrderItem()
        ..orderId = 1
        ..productId = 2;

      expect(item.primaryKeys, equals(['order_id', 'product_id']));

      final pk = item.getPrimaryKeyValue();
      expect(pk, isA<Map<String, Object?>>());
      final pkMap = pk! as Map<String, Object?>;
      expect(pkMap['order_id'], equals(1));
      expect(pkMap['product_id'], equals(2));

      // Test setting composite key
      item.setPrimaryKeyValue({'order_id': 10, 'product_id': 20});
      expect(item.orderId, equals(10));
      expect(item.productId, equals(20));
    });

    test('should return null for incomplete composite key', () {
      final item = TestOrderItem()..orderId = 1; // productId is null

      expect(item.getPrimaryKeyValue(), isNull);
    });

    test('should throw error for invalid composite key format', () {
      final item = TestOrderItem();

      expect(() => item.setPrimaryKeyValue('invalid'), throwsArgumentError);
    });
  });

  group('Equality and Hashing', () {
    setUp(() {
      ModelRegistry.clear();
      ModelRegistry.register<ModelRegistryTest>(ModelRegistryTest.new);
      ModelRegistry.register<TestOrderItem>(TestOrderItem.new);
    });

    test('should compare single primary key models correctly', () {
      final user1 = ModelRegistryTest()..id = 1;
      final user2 = ModelRegistryTest()..id = 1;
      final user3 = ModelRegistryTest()..id = 2;

      expect(user1, equals(user2));
      expect(user1, isNot(equals(user3)));
      expect(user1.hashCode, equals(user2.hashCode));
    });

    test('should compare composite primary key models correctly', () {
      final item1 = TestOrderItem()
        ..orderId = 1
        ..productId = 2;
      final item2 = TestOrderItem()
        ..orderId = 1
        ..productId = 2;
      final item3 = TestOrderItem()
        ..orderId = 1
        ..productId = 3;

      expect(item1, equals(item2));
      expect(item1, isNot(equals(item3)));
      expect(item1.hashCode, equals(item2.hashCode));
    });

    test('should not be equal when primary key is null', () {
      final user1 = ModelRegistryTest();
      final user2 = ModelRegistryTest();

      expect(user1, isNot(equals(user2)));
      expect(user1, equals(user1)); // Identity comparison
    });

    test('should not be equal across different model types', () {
      final user = ModelRegistryTest()..id = 1;
      final item = TestOrderItem()
        ..orderId = 1
        ..productId = 1;

      expect(user, isNot(equals(item)));
    });
  });

  group('CopyWith Functionality', () {
    setUp(() {
      ModelRegistry.clear();
      ModelRegistry.register<ModelRegistryTest>(ModelRegistryTest.new);
      ModelRegistry.register<TestOrderItem>(TestOrderItem.new);
    });

    test('should copy model with no changes', () {
      final original = ModelRegistryTest()
        ..id = 1
        ..name = 'John'
        ..email = 'john@test.com'
        ..age = 30
        ..markAsExisting();

      final copy = original.copyWith<ModelRegistryTest>();

      expect(identical(copy, original), isFalse);
      expect(copy.id, equals(original.id));
      expect(copy.name, equals(original.name));
      expect(copy.email, equals(original.email));
      expect(copy.age, equals(original.age));
      expect(copy.exists, equals(original.exists));
    });

    test('should copy model with attribute changes', () {
      final original = ModelRegistryTest()
        ..id = 1
        ..name = 'John'
        ..email = 'john@test.com'
        ..age = 30;

      final copy = original.copyWith<ModelRegistryTest>(
        attributes: {'name': 'Jane', 'age': 25},
      );

      expect(copy.id, equals(1));
      expect(copy.name, equals('Jane')); // Changed
      expect(copy.email, equals('john@test.com')); // Unchanged
      expect(copy.age, equals(25)); // Changed
    });

    test('should copy composite key model', () {
      final original = TestOrderItem()
        ..orderId = 1
        ..productId = 2
        ..quantity = 10
        ..price = 99.99;

      final copy = original.copyWith<TestOrderItem>(
        attributes: {'quantity': 5, 'price': 49.99},
      );

      expect(copy.orderId, equals(1));
      expect(copy.productId, equals(2));
      expect(copy.quantity, equals(5)); // Changed
      expect(copy.price, equals(49.99)); // Changed
    });

    test('should throw error for unregistered model', () {
      final unregistered = UnregisteredModel();

      expect(
        () => unregistered.copyWith<UnregisteredModel>(),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should create clone without parameters', () {
      final original = ModelRegistryTest()
        ..name = 'John'
        ..email = 'john@test.com';

      final clone = original.clone<ModelRegistryTest>();

      expect(identical(clone, original), isFalse);
      expect(clone.name, equals(original.name));
      expect(clone.email, equals(original.email));
    });

    test('should preserve existence state in copy', () {
      final newModel = ModelRegistryTest()..name = 'New User';
      expect(newModel.exists, isFalse);

      final copyOfNew = newModel.copyWith<ModelRegistryTest>();
      expect(copyOfNew.exists, isFalse);

      newModel.markAsExisting();
      final copyOfExisting = newModel.copyWith<ModelRegistryTest>();
      expect(copyOfExisting.exists, isTrue);
    });
  });
}

// Test model with single primary key
class ModelRegistryTest extends Model with ActiveRecord {
  @override
  String get tableName => 'users';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get email => get<String>('email');
  set email(String? value) => setAttribute('email', value);

  int? get age => get<int>('age');
  set age(int? value) => setAttribute('age', value);
}

// Test model with composite primary key
class TestOrderItem extends Model with ActiveRecord {
  @override
  String get tableName => 'order_items';

  @override
  List<String> get primaryKeys => ['order_id', 'product_id'];

  int? get orderId => get<int>('order_id');
  set orderId(int? value) => setAttribute('order_id', value);

  int? get productId => get<int>('product_id');
  set productId(int? value) => setAttribute('product_id', value);

  int? get quantity => get<int>('quantity');
  set quantity(int? value) => setAttribute('quantity', value);

  double? get price => get<double>('price');
  set price(double? value) => setAttribute('price', value);
}

// Test model without registration (for error testing)
class UnregisteredModel extends Model {
  @override
  String get tableName => 'unregistered';
}
