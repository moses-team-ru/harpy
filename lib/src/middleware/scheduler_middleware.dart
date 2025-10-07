import 'dart:async';

import 'package:collection/collection.dart';
import 'package:harpy/src/scheduler/task.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:talker/talker.dart';

/// Scheduler middleware for managing scheduled tasks in Harpy applications
///
/// This middleware provides task scheduling capabilities including:
/// - Periodic tasks that run at regular intervals
/// - Scheduled tasks that run at specific times
/// - Instant tasks that run once immediately
///
/// Example:
/// ```dart
/// final app = Harpy();
/// app.enableScheduler();
/// app.addTask(MyPeriodicTask());
/// ```
class SchedulerMiddleware {
  /// List of tasks to be scheduled.
  final List<Task> _tasks = <Task>[];

  /// Talker instance for logging
  final Talker _talker = Talker();

  /// Flag to track if scheduler is initialized
  bool _isInitialized = false;

  /// Creates a shelf middleware that initializes the scheduler
  ///
  /// This middleware should be added to the Harpy application before
  /// starting the server. It will initialize all tasks when the first
  /// request is processed.
  shelf.Middleware middleware() =>
      (shelf.Handler innerHandler) => (shelf.Request request) {
            // Initialize scheduler on first request
            if (!_isInitialized) {
              _initialize();
            }
            return innerHandler(request);
          };

  /// Initialize the scheduler and start all registered tasks
  void _initialize() {
    if (_isInitialized) return;

    _isInitialized = true;
    _talker.info('⏱️ Scheduler middleware initialized');

    // Tasks are already added via add() method, just log initialization
    if (_tasks.isNotEmpty) {
      _talker.info('📋 ${_tasks.length} task(s) registered');
    }
  }

  /// Add a task to the scheduler.
  ///
  /// This method registers a task and starts it immediately if the scheduler
  /// is already initialized. Tasks can be periodic, scheduled, or instant.
  ///
  /// Example:
  /// ```dart
  /// scheduler.add(Task.periodic(
  ///   id: 'cleanup',
  ///   interval: Duration(hours: 1),
  /// ));
  /// ```
  void add(Task task) {
    if (!task.isEnabled) {
      _talker.warning('✖️ Task: ${task.id} is disabled, skipping addition');
      return;
    }

    if (_tasks.any((Task t) => t.id == task.id)) {
      _talker.warning('⚠️ Task: ${task.id} already exists, skipping');
      return;
    }

    if (task.isPeriodic) {
      _talker.info(
        '⏱️ Adding periodic task: ${task.runtimeType} with interval: ${task.interval ?? 'not set'}',
      );
      task.timer = Timer.periodic(task.interval!, (Timer timer) => task.run());
      _tasks.add(task);
    } else if (task.isScheduled) {
      _talker.info(
        '⏰ Adding scheduled task: ${task.runtimeType} at ${task.scheduled ?? 'not set'}',
      );
      task.timer = Timer.periodic(const Duration(minutes: 1), (_) {
        final DateTime now = DateTime.now().toUtc();
        final DateTime scheduled = task.scheduled!;
        if (now.hour == scheduled.hour && now.minute == scheduled.minute) {
          task.run();
        }
      });
      _tasks.add(task);
    } else if (task.isInstant) {
      _talker.info(
        '🚀 Running instant task: ${task.runtimeType} immediately',
      );
      _tasks.add(task);
      task.run().then((_) {
        task.finalize();
        _talker.info('✅ Instant task: ${task.runtimeType} completed');
      }).catchError((Object error) {
        _talker.error(
          'Error running instant task (${task.runtimeType}): $error',
        );
      });
    } else {
      _talker.warning(
        '✖️ Task: ${task.runtimeType} is neither periodic nor scheduled, skipping',
      );
    }
  }

  /// Check if a task is scheduled.
  ///
  /// Returns `true` if a task with the given ID exists and is a scheduled task.
  bool isScheduled(String id) =>
      _tasks.any((Task t) => t.id == id && t.isScheduled);

  /// Remove a task from the scheduler.
  ///
  /// This method stops and removes a task from the scheduler. Instant tasks
  /// cannot be removed as they complete immediately.
  ///
  /// Example:
  /// ```dart
  /// scheduler.remove('cleanup');
  /// ```
  void remove(String id) {
    if (!_tasks.any((Task t) => t.id == id)) {
      _talker.warning('⚠️ Task: $id not found');
      return;
    }

    final Task? task = _tasks.firstWhereOrNull((Task t) => t.id == id);
    if (task != null && !task.isInstant) {
      task.timer.cancel();
      task.finalize();
      _tasks.removeWhere((Task t) => t.id == task.id);
      _talker.info('🗑️ Task: $id removed');
    } else {
      _talker.warning('✖️ Task: $id is an instant task and cannot be removed');
    }
  }

  /// Stop the scheduler.
  ///
  /// This method cancels all scheduled tasks and logs the action.
  /// It should be called when the application is shutting down
  /// to ensure that all tasks are stopped gracefully.
  ///
  /// Example:
  /// ```dart
  /// scheduler.stop();
  /// ```
  void stop() {
    if (_tasks.isEmpty) {
      _talker.info('ℹ️ Scheduler stopped (no tasks were running)');
      return;
    }

    int stoppedCount = 0;
    for (final Task task in _tasks) {
      if (!task.isInstant) {
        try {
          task.timer.cancel();
          task.finalize();
          stoppedCount++;
        } on Exception catch (e) {
          _talker.error('Error stopping task ${task.id}: $e');
        }
      }
    }

    _tasks.clear();
    _talker.info('🛑 Scheduler stopped ($stoppedCount task(s) stopped)');
    _isInitialized = false;
  }

  /// Get the number of active tasks
  int get taskCount => _tasks.length;

  /// Get a list of all task IDs
  List<String> get taskIds => _tasks.map((t) => t.id).toList();
}
