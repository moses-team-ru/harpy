/// Base database connection interface
///
/// Provides a unified interface for different database types (SQL and NoSQL)
abstract class DatabaseConnection {
  /// Connection configuration
  Map<String, dynamic> get config;

  /// Whether the connection is currently active
  bool get isConnected;

  /// Connect to the database
  Future<void> connect();

  /// Disconnect from the database
  Future<void> disconnect();

  /// Execute a raw query/command
  Future<DatabaseResult> execute(String query, [List<Object?>? parameters]);

  /// Start a transaction (for databases that support it)
  Future<DatabaseTransaction?> beginTransaction();

  /// Check if the connection is healthy
  Future<bool> ping();

  /// Get database metadata/info
  Future<Map<String, dynamic>> getDatabaseInfo();
}

/// Transaction interface for databases that support transactions
abstract class DatabaseTransaction {
  /// Commit the transaction
  Future<void> commit();

  /// Rollback the transaction
  Future<void> rollback();

  /// Execute a query within the transaction
  Future<DatabaseResult> execute(String query, [List<Object?>? parameters]);

  /// Whether the transaction is still active
  bool get isActive;
}

/// Generic database result interface
abstract class DatabaseResult {
  /// Number of affected rows (for INSERT, UPDATE, DELETE)
  int get affectedRows;

  /// Inserted ID (for INSERT operations with auto-increment)
  Object? get insertId;

  /// Result rows (for SELECT operations)
  List<Map<String, dynamic>> get rows;

  /// Check if the result has any rows
  bool get hasRows;

  /// Get the first row or null if no rows
  Map<String, dynamic>? get firstRow;

  /// Get result metadata
  Map<String, dynamic> get metadata;
}

/// Database adapter factory interface
abstract class DatabaseAdapter {
  /// Create a connection from configuration
  DatabaseConnection createConnection(Map<String, dynamic> config);

  /// Get the adapter type (postgresql, mysql, sqlite, mongodb, redis)
  String get type;

  /// Get supported features
  Set<DatabaseFeature> get supportedFeatures;

  /// Validate connection configuration
  bool validateConfig(Map<String, dynamic> config);
}

/// Supported database features
enum DatabaseFeature {
  /// Basic CRUD operations
  transactions,

  /// Foreign key constraints
  foreignKeys,

  /// Indexing support
  indexing,

  /// Full-text search capabilities
  fullTextSearch,

  /// JSON data type support
  jsonSupport,

  /// Stored procedures
  geoSpatial,

  /// Replication support
  replication,

  /// Sharding support
  sharding,

  /// Streaming support
  streaming,

  /// Aggregation framework
  aggregation,
}

/// Database-specific exceptions
class DatabaseException implements Exception {
  /// Create a new DatabaseException
  const DatabaseException(this.message, {this.code, this.details});

  /// Error message
  final String message;

  /// Optional error code
  final String? code;

  /// Optional additional details
  final Map<String, dynamic>? details;

  @override
  String toString() =>
      'DatabaseException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Specific exception for connection errors
class ConnectionException extends DatabaseException {
  /// Create a new ConnectionException
  const ConnectionException(super.message, {super.code, super.details});
}

/// Specific exception for query errors
class QueryException extends DatabaseException {
  /// Create a new QueryException
  const QueryException(super.message, {super.code, super.details});
}

/// Specific exception for transaction errors
class TransactionException extends DatabaseException {
  /// Create a new TransactionException
  const TransactionException(super.message, {super.code, super.details});
}
