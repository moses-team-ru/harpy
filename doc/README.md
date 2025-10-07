# Harpy Framework Documentation

Welcome to the comprehensive documentation for the Harpy Backend Framework - a modern, fast, and lightweight backend framework for Dart.

## 📚 Complete Documentation Index

### 🚀 Getting Started
- **[Framework Overview](harpy_framework.md)** - Core concepts, installation, and your first API
- **[Configuration System](configuration.md)** - Environment variables, JSON files, and programmatic configuration
- **[Quick Examples](examples.md)** - Common patterns and code samples

### 🏗️ Core Components
- **[HTTP Components](http.md)** - Request and Response objects, headers, and status codes
- **[Routing System](routing.md)** - URL routing, parameters, sub-routers, and route matching
- **[Server Implementation](server.md)** - Server lifecycle, HTTPS, and deployment
- **[Middleware System](middleware.md)** - Built-in and custom middleware

### 🗄️ Database & Persistence
- **[Database Overview](database.md)** - ORM concepts, adapters, and connection management
- **[SQLite Adapter](sqlite_adapter.md)** - Production-ready SQLite implementation ✅
- **[PostgreSQL Adapter](postgresql_adapter.md)** - Advanced PostgreSQL features ✅
- **[MySQL Adapter](mysql_adapter.md)** - MySQL database integration ✅
- **[MongoDB Adapter](mongodb_adapter.md)** - Document database support ✅
- **[Redis Adapter](redis_adapter.md)** - Cache layer (stub implementation) ⚠️
- **[Migrations](migrations.md)** - Database schema version control
- **[Query Builder](query_builder.md)** - Type-safe query construction

### 🔧 Advanced Features
- **[Authentication](authentication.md)** - JWT, Basic Auth, and custom authentication
- **[Scheduler](scheduler.md)** - Task scheduling and background jobs
- **[Testing](testing.md)** - Unit testing, integration testing, and mocking
- **[Performance](performance.md)** - Optimization, caching, and monitoring
- **[Deployment](deployment.md)** - Docker, cloud deployment, and production setup

### 📖 Reference
- **[API Reference](api_reference.md)** - Complete class and method documentation
- **[CLI Tools](cli.md)** - Command-line interface and project scaffolding
- **[Contributing](../CONTRIBUTING.md)** - Development setup and contribution guidelines

## 🎯 Learning Path

### For Beginners
1. Start with **[Framework Overview](harpy_framework.md)** to understand the basics
2. Learn about **[Configuration](configuration.md)** to set up your environment
3. Explore **[HTTP Components](http.md)** to handle requests and responses
4. Master **[Routing](routing.md)** to define your API endpoints

### For Database Integration
1. Read the **[Database Overview](database.md)** to understand the ORM
2. Choose your database adapter: **[SQLite](sqlite_adapter.md)**, **[PostgreSQL](postgresql_adapter.md)**, **[MySQL](mysql_adapter.md)**, or **[MongoDB](mongodb_adapter.md)**
3. Learn about **[Migrations](migrations.md)** for schema management
4. Use the **[Query Builder](query_builder.md)** for complex queries

### For Production Deployment
1. Implement **[Authentication](authentication.md)** to secure your API
2. Add **[Middleware](middleware.md)** for cross-cutting concerns
3. Follow the **[Performance](performance.md)** guide for optimization
4. Use the **[Deployment](deployment.md)** guide for production setup

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────┐
│              Harpy Server               │ ← server.md
├─────────────────────────────────────────┤
│            Middleware Stack             │ ← middleware.md
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌──────────┐  │
│  │CORS │ │Auth │ │ Log │ │ Database │  │
│  └─────┘ └─────┘ └─────┘ └──────────┘  │
├─────────────────────────────────────────┤
│             Router System               │ ← routing.md
│  ┌─────────────┐ ┌─────────────────┐   │
│  │   Routes    │ │   Parameters    │   │
│  └─────────────┘ └─────────────────┘   │
├─────────────────────────────────────────┤
│           HTTP Components               │ ← http.md
│  ┌─────────────┐ ┌─────────────────┐   │
│  │   Request   │ │    Response     │   │
│  └─────────────┘ └─────────────────┘   │
├─────────────────────────────────────────┤
│           Database Layer                │ ← database.md
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐  │
│  │SQLite│ │ Pgsql│ │MySQL │ │ Mongo│  │
│  └──────┘ └──────┘ └──────┘ └──────┘  │
└─────────────────────────────────────────┘
```

## 🗄️ Database Adapter Status

| Database | Status | Documentation | Features |
|----------|--------|---------------|----------|
| **SQLite** | ✅ Production Ready | [sqlite_adapter.md](sqlite_adapter.md) | Full SQL, Transactions, Migrations |
| **PostgreSQL** | ✅ Production Ready | [postgresql_adapter.md](postgresql_adapter.md) | Advanced SQL, JSON, Full-text search |
| **MySQL** | ✅ Production Ready | [mysql_adapter.md](mysql_adapter.md) | Standard SQL, Stored procedures |
| **MongoDB** | ✅ Production Ready | [mongodb_adapter.md](mongodb_adapter.md) | Document queries, Aggregation |
| **Redis** | ⚠️ Stub Implementation | [redis_adapter.md](redis_adapter.md) | Basic key-value (development needed) |

## 🔧 Middleware Components

| Middleware | Status | Documentation | Purpose |
|------------|--------|---------------|---------|
| **CORS** | ✅ Production Ready | [middleware.md#cors](middleware.md#cors) | Cross-origin resource sharing |
| **Authentication** | ✅ Production Ready | [middleware.md#auth](middleware.md#auth) | JWT and Basic Auth |
| **Logging** | ✅ Production Ready | [middleware.md#logging](middleware.md#logging) | Request/response logging |
| **Database** | ✅ Production Ready | [middleware.md#database](middleware.md#database) | Connection management |
| **Scheduler** | ✅ Production Ready | [scheduler.md](scheduler.md) | Task scheduling and background jobs |

## 🚀 Quick Reference

### Common Tasks
- **Create a new API** → [harpy_framework.md#getting-started](harpy_framework.md#getting-started)
- **Add database support** → [database.md#quick-start](database.md#quick-start)
- **Set up authentication** → [authentication.md](authentication.md)
- **Configure environment** → [configuration.md](configuration.md)
- **Deploy to production** → [deployment.md](deployment.md)

### Code Examples
```dart
// Basic API
final app = Harpy();
app.get('/', (req, res) => res.json({'message': 'Hello Harpy!'}));
await app.listen(port: 3000);

// With database
final app = Harpy(config: Configuration.fromMap({
  'database': {'type': 'sqlite', 'path': './app.db'}
}));

// With middleware
app.enableCors();
app.enableAuth(jwtSecret: 'your-secret');
app.enableLogging();
```

## 🤝 Contributing

We welcome contributions! See our [Contributing Guide](../CONTRIBUTING.md) for:
- Development setup
- Code style guidelines
- Testing requirements
- Pull request process

## 📄 License

MIT License - see [LICENSE](../LICENSE) file for details.

---

**Need help?** Start with the [Framework Overview](harpy_framework.md) or check our [API Reference](api_reference.md) for detailed information about specific classes and methods.