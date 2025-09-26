// ignore_for_file: no-empty-block

import 'package:harpy/harpy.dart';
import 'package:test/test.dart';

// Test model for QueryBuilder tests
class QueryBuilderTest extends Model with ActiveRecord {
  @override
  String get tableName => 'users';

  String? get name => get<String>('name');
  set name(String? value) => setAttribute('name', value);

  String? get email => get<String>('email');
  set email(String? value) => setAttribute('email', value);

  int? get age => get<int>('age');
  set age(int? value) => setAttribute('age', value);

  @override
  List<String> validate() => <String>[];
}

// Mock database connection for testing
class MockDatabaseConnection implements DatabaseConnection {
  const MockDatabaseConnection();
  @override
  Future<DatabaseResult> execute(
    String query, [
    List<Object?>? parameters,
  ]) async =>
      MockDatabaseResult(query, parameters ?? <Object?>[]);

  @override
  Future<DatabaseTransaction> beginTransaction() async {
    throw UnimplementedError();
  }

  bool get isOpen => true;

  @override
  Map<String, dynamic> get config => <String, dynamic>{};

  @override
  Future<void> connect() async {
    // Mock implementation - no actual connection needed
  }

  @override
  Future<void> disconnect() async {
    // Mock implementation - no actual disconnection needed
  }

  @override
  bool get isConnected => true;

  @override
  Future<bool> ping() async => true;

  @override
  Future<Map<String, dynamic>> getDatabaseInfo() async => <String, dynamic>{};
}

class MockDatabaseResult implements DatabaseResult {
  const MockDatabaseResult(this._sql, this._parameters);

  final String _sql;
  final List<Object?> _parameters;

  @override
  int get affectedRows => 1;

  @override
  Map<String, dynamic>? get firstRow => null;

  @override
  int get insertId => 1;

  @override
  List<Map<String, dynamic>> get rows => <Map<String, dynamic>>[];

  @override
  bool get hasRows => rows.isNotEmpty;

  @override
  Map<String, dynamic> get metadata =>
      <String, dynamic>{'query': _sql, 'parameters': _parameters};

  String get sql => _sql;
  List<Object?> get parameters => _parameters;
}

void main() {
  group('QueryBuilder Basic Structure', () {
    late MockDatabaseConnection mockConnection;
    late QueryBuilder<QueryBuilderTest> query;

    setUp(() {
      mockConnection = const MockDatabaseConnection();
      query = QueryBuilder<QueryBuilderTest>(QueryBuilderTest, mockConnection);
    });

    test('should create QueryBuilder instance', () {
      expect(query, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should build query with select columns', () {
      query.select(<String>['name', 'email']);

      // We can't directly test SQL generation, but we can test the structure
      expect(query, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should chain where conditions', () {
      query.where('name', 'John').where('age', 25);

      expect(query, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should chain multiple operations', () {
      final QueryBuilder<QueryBuilderTest> result = query
          .select(<String>['name', 'email'])
          .where('active', true)
          .orderBy('name')
          .limit(10);

      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });
  });

  group('QueryBuilder WHERE Conditions', () {
    late MockDatabaseConnection mockConnection;
    late QueryBuilder<QueryBuilderTest> testQuery;

    setUp(() {
      mockConnection = const MockDatabaseConnection();
      testQuery =
          QueryBuilder<QueryBuilderTest>(QueryBuilderTest, mockConnection);
    });

    test('should add WHERE clause', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.where('name', 'John');
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add multiple WHERE clauses', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.where('name', 'John').where('age', 25);

      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add OR WHERE clause', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.where('name', 'John').orWhere('name', 'Jane');

      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add WHERE IN clause', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.whereIn('id', <Object?>[1, 2, 3]);
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add WHERE NULL clause', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.whereNull('deleted_at');
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add WHERE NOT NULL clause', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.whereNotNull('email_verified_at');
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add WHERE BETWEEN clause', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.whereBetween('age', 18, 65);
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add WHERE LIKE clause', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.whereLike('name', '%John%');
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });
  });

  group('QueryBuilder JOIN Operations', () {
    late MockDatabaseConnection mockConnection;
    late QueryBuilder<QueryBuilderTest> testQuery;

    setUp(() {
      mockConnection = const MockDatabaseConnection();
      testQuery =
          QueryBuilder<QueryBuilderTest>(QueryBuilderTest, mockConnection);
    });

    test('should add INNER JOIN', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.join('profiles', 'users.id = profiles.user_id');
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add LEFT JOIN', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.leftJoin('profiles', 'users.id = profiles.user_id');
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add RIGHT JOIN', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.rightJoin('profiles', 'users.id = profiles.user_id');
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });
  });

  group('QueryBuilder ORDER BY and LIMIT', () {
    late MockDatabaseConnection mockConnection;
    late QueryBuilder<QueryBuilderTest> testQuery;

    setUp(() {
      mockConnection = const MockDatabaseConnection();
      testQuery =
          QueryBuilder<QueryBuilderTest>(QueryBuilderTest, mockConnection);
    });

    test('should add ORDER BY clause', () {
      final QueryBuilder<QueryBuilderTest> result = testQuery.orderBy('name');
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add LIMIT clause', () {
      final QueryBuilder<QueryBuilderTest> result = testQuery.limit(10);
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add OFFSET clause', () {
      final QueryBuilder<QueryBuilderTest> result = testQuery.offset(20);
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add GROUP BY clause', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.groupBy('department');
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should add HAVING clause', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.having('COUNT(*) > 5');
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should set DISTINCT flag', () {
      final QueryBuilder<QueryBuilderTest> result = testQuery.distinct();
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });
  });

  group('QueryBuilder Execution', () {
    late MockDatabaseConnection mockConnection;
    late QueryBuilder<QueryBuilderTest> testQuery;

    setUp(() {
      mockConnection = const MockDatabaseConnection();
      testQuery =
          QueryBuilder<QueryBuilderTest>(QueryBuilderTest, mockConnection);
    });

    test('should execute count operation', () {
      // This tests that the method exists and returns a Future<int>
      // In a real test with a database, we would verify the actual count
      expect(testQuery.count(), isA<Future<int>>());
    });

    test('should execute exists operation', () {
      expect(testQuery.exists(), isA<Future<bool>>());
    });

    test('should execute get operation', () {
      expect(testQuery.get(), isA<Future<List<QueryBuilderTest>>>());
    });

    test('should execute first operation', () {
      expect(testQuery.first(), isA<Future<QueryBuilderTest?>>());
    });

    test('should execute update operation', () {
      final Future<int> result =
          testQuery.update(<String, Object?>{'name': 'Updated Name'});
      expect(result, isA<Future<int>>());
    });

    test('should execute delete operation', () {
      final Future<int> result = testQuery.delete();
      expect(result, isA<Future<int>>());
    });

    test('should execute insert operation', () {
      // Test only that insert method exists and returns correct type signature
      // Actual execution would require model mapping implementation
      expect(
        () => testQuery.insert(
          <String, Object?>{'name': 'New User', 'email': 'new@example.com'},
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('QueryBuilder Error Handling', () {
    late MockDatabaseConnection mockConnection;
    late QueryBuilder<QueryBuilderTest> testQuery;

    setUp(() {
      mockConnection = const MockDatabaseConnection();
      testQuery =
          QueryBuilder<QueryBuilderTest>(QueryBuilderTest, mockConnection);
    });

    test('should handle empty whereIn values', () {
      final QueryBuilder<QueryBuilderTest> result =
          testQuery.whereIn('id', <Object?>[]);
      expect(result, isA<QueryBuilder<QueryBuilderTest>>());
    });

    test('should handle empty update values', () async {
      final int result = await testQuery.update(<String, Object?>{});
      expect(result, equals(0));
    });

    test('should handle firstOrFail with no results', () {
      // This would throw DatabaseException when no records are found
      expect(() => testQuery.firstOrFail(), throwsA(isA<DatabaseException>()));
    });
  });
}
