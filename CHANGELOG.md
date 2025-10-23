# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2025-10-23

### Added - Major ORM Enhancement Release 🚀
- **ModelRegistry System**: Centralized model constructor registration for automatic instantiation
  - `ModelRegistry.register<T>()` - Register model constructors
  - `ModelRegistry.create<T>()` - Create instances by type
  - `ModelRegistry.fromJson<T>()` - Create from JSON data with automatic type detection
  - Comprehensive error handling with `ModelNotRegisteredException`

- **Enhanced Model copyWith() Method**: Flexible model copying with attribute changes
  - `model.copyWith(attributes: {...})` - Create modified copies while preserving state
  - Support for partial updates and nested attribute modification
  - Maintains model existence state and primary key information
  - Type-safe implementation with proper inheritance handling

- **Composite Primary Key Support**: Advanced primary key handling
  - `getPrimaryKeyValue()` - Extract single or composite primary keys
  - `setPrimaryKeyValue()` - Set single or composite primary keys  
  - Support for multi-column primary keys with proper equality comparison
  - Enhanced `operator ==` and `hashCode` implementation for composite keys

- **Static ORM Query Methods**: Comprehensive ActiveRecord static methods
  - `Model.where<T>(column, value)` - Find records by column value
  - `Model.fetchOne<T>()` - Fetch single record with conditions
  - `Model.fetchAll<T>()` - Fetch multiple records with filtering, ordering, pagination
  - `Model.findBy<T>(attributes)` - Find by multiple attributes
  - `Model.count<T>()` - Count records with optional conditions
  - `Model.exists<T>()` - Check record existence
  - `Model.deleteWhere<T>()` - Bulk delete operations
  - `Model.updateWhere<T>()` - Bulk update operations

- **Comprehensive Relationship System**: Full ORM relationship support
  - **BelongsTo Relationships**: `belongsTo<T>(foreignKey, localKey)`
  - **HasOne Relationships**: `hasOne<T>(foreignKey, localKey)`
  - **HasMany Relationships**: `hasMany<T>(foreignKey, localKey)`
  - **BelongsToMany Relationships**: `belongsToMany<T>(pivotTable, foreignKey, relatedKey)`
  - **Pivot Table Operations**: `attach()`, `detach()`, `sync()` for many-to-many relationships
  - **Eager Loading Support**: Load relationships efficiently to prevent N+1 queries
  - **Relationship Caching**: Automatic caching of loaded relationships

### Enhanced
- **Model Base Class**: Significantly expanded with new capabilities
  - Improved attribute management with better type safety
  - Enhanced JSON serialization/deserialization
  - Better validation integration and error handling
  - Optimized performance for large datasets

- **ActiveRecord Mixin**: Extended with static query methods
  - Backward compatible with existing instance methods
  - New static methods work with all database adapters
  - Integrated with QueryBuilder for complex queries
  - Proper transaction support in all methods

- **Database Integration**: Enhanced adapter compatibility
  - All new features work with SQLite, PostgreSQL, MySQL, MongoDB
  - Proper type conversion and mapping
  - Enhanced connection pooling and error handling
  - Better performance optimization

### Technical Implementation
- **54 New Comprehensive Tests**: Complete test coverage for all new features
  - ModelRegistry tests (20 tests) - Registration, creation, error handling
  - ActiveRecord static methods tests (17 tests) - All query operations with real database
  - Relationships tests (14 tests) - All relationship types with complex scenarios
  - Primary key handling tests - Composite keys and edge cases
  - CopyWith functionality tests - All attribute modification scenarios

- **Backward Compatibility**: 100% preserved
  - All existing APIs remain unchanged
  - Existing projects work without modification
  - New features are additive, not replacing
  - Seamless migration path for enhanced functionality

- **Performance Optimizations**: Efficient implementation
  - Optimized query generation for static methods
  - Relationship caching to minimize database calls
  - Efficient primary key handling for composite keys
  - Memory-efficient model copying and attribute management

### Documentation & Examples
- **Enhanced ORM Example**: Complete demonstration (`example/enhanced_orm_example.dart`)
  - Shows all new ORM features in action
  - Real-world usage patterns and best practices
  - Performance optimization examples
  - Comprehensive relationship usage

- **Implementation Summary**: Detailed technical documentation (`orm_refactoring_summary.md`)
  - Complete feature overview and implementation details
  - Architecture decisions and design patterns
  - Migration guide from previous versions
  - Performance considerations and optimization tips

### Breaking Changes
- None - Full backward compatibility maintained

### Migration Guide
No migration required for existing projects. New features are available immediately:

**Enhanced Model Usage:**
```dart
// Register models (add to your app initialization)
ModelRegistry.register<User>(() => User());
ModelRegistry.register<Post>(() => Post());

// Use new static query methods
final users = await User.fetchAll<User>(limit: 10);
final user = await User.fetchOne<User>(where: 'email = ?', parameters: ['john@example.com']);
final activeUsers = await User.where<User>('active', true);

// Use copyWith for immutable updates
final updatedUser = user.copyWith(attributes: {'name': 'New Name'});

// Use relationships
final userPosts = await user.hasMany<Post>('user_id');
final post = await Post.fetchOne<Post>(where: 'id = ?', parameters: [1]);
final postAuthor = await post?.belongsTo<User>('user_id');
```

## [0.1.2] - 2025-10-07

### Changed
- **Scheduler → Middleware Refactoring**: Converted Scheduler system to Middleware architecture
  - `Scheduler` class moved to `SchedulerMiddleware` in `lib/src/middleware/`
  - Integrated task scheduling into the middleware pipeline
  - Improved lifecycle management with automatic startup and shutdown
  - Better integration with Harpy application lifecycle
  - Graceful shutdown of all tasks when server stops

### Added
- **Scheduler Middleware Documentation**: Complete guide for task scheduling
  - Comprehensive documentation in `doc/scheduler.md`
  - Examples for periodic, scheduled, and instant tasks
  - Best practices and patterns
  - Integration examples with database operations
- **Enhanced CLI Structure**: Clear separation between global and project CLIs
  - Global CLI (`bin/harpy.dart`) - Framework-level commands (create, version, help)
  - Project CLI (`bin/<project>.dart`) - Project-specific commands (serve, migrate, task)
  - New `lib/src/cli/` directory for CLI generation logic
  - `create_project_cli.dart` - Separate file for project CLI template generation
- **Task Management via CLI**: New command to add tasks to projects
  - `dart run bin/<project>.dart task add <task_name>` - Generate task template
  - Automatic task file creation in `lib/tasks/` directory
  - Task templates for periodic, scheduled, and instant tasks
  - Auto-registration hints in generated code
  - `task list` command to display all tasks
  - `task help` command for task management help

### Technical Details
- **Middleware Integration**: Scheduler now follows the standard middleware pattern
  - Consistent API with other Harpy middlewares
  - Easy to enable via `app.enableScheduler()`
  - Automatic initialization and cleanup
- **CLI Architecture**: Improved separation of concerns
  - Framework CLI handles project scaffolding
  - Project CLI handles application lifecycle and development tasks
  - Reusable CLI generation components via `ProjectCliGenerator`
  - Extensible command structure for custom commands
- **Task Management**: Enhanced developer experience
  - CLI-driven task creation with interactive type selection
  - Template-based task generation
  - Clear task registration patterns
  - Built-in logging and error handling

### Migration Guide
For projects using the old Scheduler:

**Before (v0.1.1):**
```dart
import 'package:harpy/harpy.dart';

void main() async {
  final scheduler = Scheduler();
  scheduler.add(MyTask());
  
  final app = Harpy();
  // Scheduler separate from app
  await app.listen(port: 3000);
}
```

**After (v0.1.2):**
```dart
import 'package:harpy/harpy.dart';

void main() async {
  final app = Harpy();
  app.enableScheduler();
  app.addTask(MyTask());
  
  await app.listen(port: 3000);
  // Scheduler automatically stops with the app
}
```

### Breaking Changes
- `Scheduler` class deprecated (use `SchedulerMiddleware` through `app.enableScheduler()`)
- Direct imports of `src/scheduler/scheduler.dart` should be updated to use middleware approach
- Task lifecycle now managed by Harpy application instead of standalone Scheduler

### Deprecated
- `Scheduler` class (use `app.enableScheduler()` instead)
- Direct Scheduler instantiation (tasks should be added via `app.addTask()`)

## [0.1.1+4] - 2025-10-03

### Changed
- **Project Structure Refactoring**: Generated projects now use `lib/main.dart` instead of `bin/main.dart` for the main application
  - Main application code now resides in `lib/` following Dart conventions
  - Improves testability and code organization
  - Allows for better code reuse and modularization

### Added
- **CLI Management Tool**: Each generated project now includes a CLI utility in `bin/<project_name>.dart`
  - `serve` command - Starts the development server
  - `migrate` command - Placeholder for database migrations (ready for implementation)
  - `version` command - Shows project and framework version
  - `help` command - Displays available commands and usage
- Enhanced project scaffolding with improved documentation
- Updated README templates for generated projects with CLI usage examples
- Better output messages after project creation showing project structure and available commands

### Technical Details
- CLI utility supports extensibility - developers can add custom commands
- Local project management without global installation conflicts
- Cleaner separation between application logic (`lib/`) and management tools (`bin/`)

### Migration Guide
For existing projects created with earlier versions:
1. Move `bin/main.dart` to `lib/main.dart`
2. Optionally create a CLI utility in `bin/<your_project>.dart` (see template in new projects)
3. Update your IDE run configurations if needed

## [0.1.1+3] - Previous Version

### Added
- Initial framework structure
- HTTP server implementation  
- Routing system with parameter support
- Middleware support
- Request/Response handling
- Configuration management
- Built-in middlewares (CORS, logging, authentication)

### Database & ORM System
- **Complete ORM Implementation** - Active Record and Repository patterns
- **SQLite Adapter** - Production-ready implementation with full SQL support
- **PostgreSQL Adapter** - Advanced features including JSON support and full-text search
- **MySQL Adapter** - Complete MySQL integration with connection pooling
- **MongoDB Adapter** - Document database support with aggregation pipeline
- **Redis Adapter** - Basic key-value operations (stub implementation)
- **Database Migrations** - Schema version control and management system
- **Query Builder** - Type-safe, fluent query construction
- **ACID Transactions** - Full transaction support with automatic rollback
- **Connection Pooling** - Efficient database connection management
- **Model Validation** - Built-in data validation with custom rules
- **Active Record Pattern** - Instance methods for database operations (save, delete, refresh)
- **Repository Pattern** - Static methods for querying and bulk operations
- **Security Features** - Built-in SQL injection prevention through parameterized queries

### Database Features Details
- **Multi-Database Support** - Unified interface across all database types
- **Type Conversion** - Automatic type mapping between Dart and database types
- **Foreign Key Support** - Relationship management and constraint enforcement
- **Index Management** - Create and manage database indexes for performance
- **Schema Introspection** - Query database structure and metadata
- **Bulk Operations** - Efficient batch inserts, updates, and deletes
- **Connection Retry Logic** - Automatic reconnection on connection failures
- **Database Health Checks** - Built-in connection monitoring and diagnostics

### Database Adapters Status
- **SQLite** ✅ Production Ready - Full implementation with file and in-memory support
- **PostgreSQL** ✅ Production Ready - Advanced SQL features, JSON/JSONB, arrays
- **MySQL** ✅ Production Ready - Standard SQL with stored procedures support  
- **MongoDB** ✅ Production Ready - Document operations and aggregation pipelines
- **Redis** ⚠️ Stub Implementation - Basic structure, full implementation planned

### Technical Implementation
- **Package Dependencies** - sqlite3: ^2.9.0, postgres: ^3.5.6, mysql1: ^0.20.0, mongo_dart: ^0.10.5, redis: ^4.0.0
- **Model System** - Base Model class with attribute management and serialization
- **Migration System** - TableBuilder with fluent API for schema definition
- **Connection Management** - Factory pattern for database adapter creation
- **Error Handling** - Comprehensive exception hierarchy (QueryException, ConnectionException, TransactionException, ValidationException)
- **Testing Support** - In-memory database options for unit testing

### Documentation Added
- Complete API documentation for all ORM components
- Database adapter configuration guides
- Migration system documentation  
- Model definition and validation examples
- Query builder usage patterns
- Transaction management best practices
- Performance optimization guidelines

## [0.1.0] - 2025-09-25

### Added
- Initial release of Harpy framework
- Basic HTTP server functionality
- RESTful routing
- Middleware system

### Known Limitations
- **Redis Adapter** - Currently implemented as stub for demonstration purposes
- **Model Relationships** - Basic implementation, advanced relationships (One-to-Many, Many-to-Many) planned for future releases
- **Query Builder Joins** - Basic join support, complex join operations under development
- **Schema Migrations** - Manual rollback required, automatic rollback planned

### Planned Features (Future Releases)  
- **Complete Redis Implementation** - Full Redis client integration with all data types
- **Advanced ORM Features** - Model relationships, lazy loading, eager loading
- **Query Optimization** - Query caching, performance monitoring, query hints
- **Additional Database Adapters** - CouchDB, InfluxDB, Neo4j support
- **Enhanced Security** - Row-level security, audit logging, encryption at rest
- **Performance Improvements** - Connection pool optimization, query result caching

### Testing & Quality Assurance
- **Comprehensive Test Suite** - Over 100 tests covering all ORM functionality  
- **Database Adapter Tests** - Individual test suites for each database adapter
- **Integration Tests** - Full request-response cycle testing with database operations
- **Performance Tests** - Connection pooling, query performance, and memory usage validation
- **Security Tests** - SQL injection prevention and input validation testing
- **Migration Tests** - Schema creation, modification, and rollback validation

### Performance Benchmarks
- **SQLite Operations** - 10,000+ inserts/second in single transaction
- **PostgreSQL Connections** - Efficient connection pooling with configurable pool sizes
- **MySQL Compatibility** - Full compatibility with MySQL 5.7+ and MariaDB 10.3+
- **MongoDB Performance** - Optimized document operations with aggregation pipeline support
- **Memory Usage** - Efficient model attribute management with minimal memory overhead
- **Transaction Performance** - ACID compliance with minimal performance impact

### Breaking Changes
- None in this initial release

### Fixed
- **Deprecated Function** - Replaced `getUpdatedRows()` with `updatedRows` in SQLite adapter for compatibility with sqlite3 ^2.9.0
- **Router 404 Bug** - Fixed critical bug where all routes returned 404 errors. The router was using `request.url.path` which returns paths without leading slash (e.g., `""` for `/`, `"test"` for `/test`), while regex patterns expected paths with leading slash (e.g., `^/$`, `^/test$`). Changed to use `request.requestedUri.path` and added path normalization for trailing slashes. Added 30 comprehensive routing tests (14 integration tests + 16 edge case tests) to prevent regressions.