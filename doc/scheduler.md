# Scheduler Middleware

The Scheduler Middleware provides a powerful task scheduling system for Harpy applications. It allows you to run background tasks at regular intervals, at specific times, or execute one-time initialization tasks.

## Overview

The Scheduler Middleware integrates seamlessly with Harpy's middleware architecture, providing:

- **Periodic Tasks** - Execute tasks at regular intervals (e.g., every 5 minutes, hourly, daily)
- **Scheduled Tasks** - Execute tasks at specific times (e.g., daily at 9:00 AM UTC)
- **Instant Tasks** - Execute tasks once immediately on application startup
- **Lifecycle Management** - Automatic initialization and graceful shutdown
- **Error Handling** - Built-in error handling and logging
- **Task Management** - Add, remove, and monitor tasks at runtime

## Quick Start

### 1. Enable Scheduler

First, enable the scheduler middleware in your Harpy application:

```dart
import 'package:harpy/harpy.dart';

void main() async {
  final app = Harpy();
  
  // Enable scheduler middleware
  app.enableScheduler();
  
  // Add your routes...
  app.get('/', (req, res) => res.json({'status': 'ok'}));
  
  await app.listen(port: 3000);
}
```

### 2. Create a Task

Create a custom task by extending the `Task` class:

```dart
import 'package:harpy/harpy.dart';

class CleanupTask extends Task {
  CleanupTask() : super.periodic(
    id: 'cleanup',
    interval: Duration(hours: 1),
  );
  
  @override
  Future<void> execute() async {
    print('[cleanup] Running cleanup task...');
    // Your cleanup logic here
    print('[cleanup] Cleanup completed');
  }
  
  @override
  void finalize() {
    print('[cleanup] Task finalized');
  }
}
```

### 3. Register the Task

Add the task to your application:

```dart
void main() async {
  final app = Harpy();
  app.enableScheduler();
  
  // Register tasks
  app.addTask(CleanupTask());
  
  await app.listen(port: 3000);
}
```

## Task Types

### Periodic Tasks

Periodic tasks run at regular intervals. They're perfect for maintenance operations, health checks, or any recurring background work.

```dart
class DatabaseCleanupTask extends Task {
  DatabaseCleanupTask() : super.periodic(
    id: 'db-cleanup',
    interval: Duration(hours: 6), // Every 6 hours
  );
  
  @override
  Future<void> execute() async {
    // Clean up old records
    await database.execute(
      'DELETE FROM sessions WHERE expires_at < ?',
      [DateTime.now().toIso8601String()],
    );
  }
  
  @override
  void finalize() {
    print('Database cleanup task stopped');
  }
}
```

**Common Intervals:**
- `Duration(minutes: 5)` - Every 5 minutes
- `Duration(hours: 1)` - Every hour
- `Duration(days: 1)` - Every day
- `Duration(seconds: 30)` - Every 30 seconds

### Scheduled Tasks

Scheduled tasks run at specific times. Use them for daily reports, backups, or any time-specific operations.

```dart
class DailyReportTask extends Task {
  DailyReportTask() : super.scheduled(
    id: 'daily-report',
    // Runs at 9:00 AM UTC every day
    scheduled: DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      9, // hour
      0, // minute
    ),
  );
  
  @override
  Future<void> execute() async {
    print('Generating daily report...');
    // Generate and send report
    await generateReport();
    await sendReportEmail();
  }
  
  @override
  void finalize() {
    print('Daily report task stopped');
  }
}
```

**Note:** Scheduled tasks use UTC time and check every minute for matching hour and minute.

### Instant Tasks

Instant tasks run once immediately when the application starts. Perfect for initialization, cache warming, or startup checks.

```dart
class WarmupCacheTask extends Task {
  WarmupCacheTask() : super.instant(
    id: 'warmup-cache',
  );
  
  @override
  Future<void> execute() async {
    print('Warming up cache...');
    // Preload frequently accessed data
    await cache.preload();
    print('Cache warmed up successfully');
  }
  
  @override
  void finalize() {
    print('Warmup task completed');
  }
}
```

## Task Management

### Adding Tasks

Add tasks using the `addTask()` method:

```dart
app.addTask(CleanupTask());
app.addTask(DailyReportTask());
app.addTask(WarmupCacheTask());
```

### Removing Tasks

Remove a task by its ID:

```dart
app.removeTask('cleanup');
```

**Note:** Instant tasks cannot be removed as they complete immediately.

### Stopping All Tasks

Stop the scheduler and all tasks:

```dart
app.stopScheduler();
```

This is automatically called when the application shuts down.

## Advanced Usage

### Tasks with Parameters

Pass parameters to tasks for flexible configuration:

```dart
class EmailNotificationTask extends Task {
  EmailNotificationTask({required String recipient}) 
    : super.periodic(
        id: 'email-notification-$recipient',
        interval: Duration(hours: 1),
        params: {'recipient': recipient},
      );
  
  @override
  Future<void> execute() async {
    final recipient = params?['recipient'] as String;
    print('Sending notification to $recipient');
    await sendEmail(recipient);
  }
  
  @override
  void finalize() {}
}

// Usage
app.addTask(EmailNotificationTask(recipient: 'admin@example.com'));
```

### Database Integration

Tasks can work with the database:

```dart
class DataArchiveTask extends Task {
  final Database database;
  
  DataArchiveTask(this.database) : super.periodic(
    id: 'archive',
    interval: Duration(days: 1),
  );
  
  @override
  Future<void> execute() async {
    // Archive old data
    await database.transaction((tx) async {
      final result = await tx.execute(
        'SELECT * FROM logs WHERE created_at < ?',
        [DateTime.now().subtract(Duration(days: 30)).toIso8601String()],
      );
      
      // Process and archive
      for (final row in result.rows) {
        await archiveToS3(row);
      }
      
      // Delete archived data
      await tx.execute(
        'DELETE FROM logs WHERE created_at < ?',
        [DateTime.now().subtract(Duration(days: 30)).toIso8601String()],
      );
    });
  }
  
  @override
  void finalize() {
    print('Archive task stopped');
  }
}

// Usage
final db = await Database.connect({'type': 'sqlite', 'path': 'app.db'});
app.addTask(DataArchiveTask(db));
```

### Error Handling

Tasks should handle errors gracefully:

```dart
class RobustTask extends Task {
  RobustTask() : super.periodic(
    id: 'robust',
    interval: Duration(minutes: 5),
  );
  
  @override
  Future<void> execute() async {
    try {
      await performRiskyOperation();
    } on Exception catch (e, stackTrace) {
      print('Error in robust task: $e');
      print('Stack trace: $stackTrace');
      // Log to monitoring system
      await logError(e, stackTrace);
      // Don't rethrow - task will continue running
    }
  }
  
  @override
  void finalize() {}
}
```

### Conditional Execution

Control when tasks should execute:

```dart
class ConditionalTask extends Task {
  ConditionalTask() : super.periodic(
    id: 'conditional',
    interval: Duration(minutes: 10),
  );
  
  @override
  Future<void> execute() async {
    // Only run during business hours
    final now = DateTime.now();
    if (now.hour >= 9 && now.hour < 17) {
      await performBusinessHoursWork();
    }
  }
  
  @override
  void finalize() {}
}
```

## CLI Integration

Generate tasks using the project CLI:

```bash
# Create a new task
dart run bin/myproject.dart task add cleanup

# List all tasks
dart run bin/myproject.dart task list

# Get help
dart run bin/myproject.dart task help
```

The CLI will:
1. Prompt you to select the task type (periodic, scheduled, or instant)
2. Generate a task file in `lib/tasks/`
3. Provide instructions for registration

## Best Practices

### 1. Use Unique Task IDs

Always use unique IDs for your tasks:

```dart
// Good
CleanupTask() : super.periodic(id: 'cleanup', ...)
ReportTask() : super.periodic(id: 'daily-report', ...)

// Bad - duplicate IDs
Task1() : super.periodic(id: 'task', ...)
Task2() : super.periodic(id: 'task', ...) // Will be rejected
```

### 2. Keep Tasks Lightweight

Tasks should complete quickly to avoid blocking:

```dart
// Good - quick cleanup
@override
Future<void> execute() async {
  await database.execute('DELETE FROM cache WHERE expired = 1');
}

// Bad - long-running operation
@override
Future<void> execute() async {
  await processMillionsOfRecords(); // Too slow!
}
```

### 3. Handle Errors Gracefully

Never let exceptions crash your tasks:

```dart
@override
Future<void> execute() async {
  try {
    await riskyOperation();
  } catch (e) {
    print('Error: $e');
    // Log and continue
  }
}
```

### 4. Use Appropriate Intervals

Choose intervals based on your needs:

- **High frequency** (< 1 minute): Only for critical monitoring
- **Medium frequency** (5-30 minutes): Regular maintenance
- **Low frequency** (1+ hours): Heavy operations, reports

### 5. Clean Up Resources

Always implement `finalize()` to clean up:

```dart
@override
void finalize() {
  // Close connections, release resources
  connection?.close();
  print('Task finalized');
}
```

### 6. Enable/Disable Tasks

Use the `isEnabled` property for conditional execution:

```dart
class OptionalTask extends Task {
  OptionalTask({bool enabled = true}) : super.periodic(
    id: 'optional',
    interval: Duration(minutes: 5),
  ) {
    isEnabled = enabled;
  }
  
  @override
  Future<void> execute() async {
    // Task logic
  }
  
  @override
  void finalize() {}
}

// Usage
app.addTask(OptionalTask(enabled: config.get<bool>('features.task', false)));
```

## Testing

Test your tasks in isolation:

```dart
import 'package:test/test.dart';
import 'package:harpy/harpy.dart';

void main() {
  group('CleanupTask', () {
    test('executes cleanup logic', () async {
      final task = CleanupTask();
      
      // Execute the task
      await task.execute();
      
      // Verify cleanup occurred
      expect(cleanupWasCalled, isTrue);
    });
    
    test('handles errors gracefully', () async {
      final task = CleanupTask();
      
      // Should not throw
      expect(() => task.execute(), returnsNormally);
    });
  });
}
```

## Troubleshooting

### Task Not Running

**Problem:** Task added but not executing.

**Solutions:**
1. Check if scheduler is enabled: `app.enableScheduler()`
2. Verify task is not disabled: `task.isEnabled` should be `true`
3. Check logs for warning messages
4. Ensure unique task ID

### Task Running Multiple Times

**Problem:** Task executes more than expected.

**Solutions:**
1. Check for duplicate task registrations
2. Verify interval is set correctly
3. Ensure you're not adding the same task multiple times

### Memory Leaks

**Problem:** Memory usage grows over time.

**Solutions:**
1. Implement proper `finalize()` cleanup
2. Cancel timers and close connections
3. Call `app.stopScheduler()` on shutdown

### Scheduled Task Not Firing

**Problem:** Scheduled task doesn't run at expected time.

**Solutions:**
1. Verify scheduled time is in UTC
2. Check system clock is correct
3. Remember scheduled tasks check every minute
4. Ensure date is in the future

## Performance Considerations

- **Task Count:** Limit to 10-20 tasks per application
- **Execution Time:** Keep tasks under 1 minute
- **Interval:** Don't use intervals shorter than needed
- **Database:** Use connection pooling for database tasks
- **Logging:** Avoid excessive logging in production

## Migration from Old Scheduler

If you're migrating from the standalone `Scheduler` class:

**Before:**
```dart
final scheduler = Scheduler();
scheduler.add(MyTask());
```

**After:**
```dart
final app = Harpy();
app.enableScheduler();
app.addTask(MyTask());
```

The Task class remains unchanged, so your existing tasks will work without modifications.

## See Also

- [Middleware Documentation](middleware.md)
- [Database Integration](database.md)
- [Configuration Management](configuration.md)
- [Harpy Framework Overview](harpy_framework.md)
