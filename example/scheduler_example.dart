// ignore_for_file: avoid_print

import 'package:harpy/harpy.dart';

// Periodic task example
class SchedulerExample extends Task {
  SchedulerExample()
      : super.periodic(id: 'cleanup', interval: const Duration(seconds: 30));

  @override
  Future<void> execute() async {
    print('[${DateTime.now()}] Running cleanup task...');
    // Simulate cleanup work
    await Future<void>.delayed(const Duration(seconds: 2));
    print('[${DateTime.now()}] Cleanup completed');
  }

  @override
  void finalize() {
    print('Cleanup task finalized');
  }
}

// Scheduled task example
class DailyReportTask extends Task {
  DailyReportTask()
      : super.scheduled(
          id: 'daily-report',
          scheduled: DateTime.now().add(const Duration(minutes: 1)),
        );

  @override
  Future<void> execute() async {
    print('[${DateTime.now()}] Generating daily report...');
    await Future<void>.delayed(const Duration(seconds: 1));
    print('[${DateTime.now()}] Report generated');
  }

  @override
  void finalize() {
    print('Daily report task finalized');
  }
}

// Instant task example
class InitTask extends Task {
  InitTask() : super.instant(id: 'init');

  @override
  Future<void> execute() async {
    print('[${DateTime.now()}] Running initialization...');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    print('[${DateTime.now()}] Initialization completed');
  }

  @override
  void finalize() {
    print('Init task finalized');
  }
}

void main() async {
  final Harpy app = Harpy()

    // Enable scheduler middleware
    ..enableScheduler()

    // Add tasks
    ..addTask(SchedulerExample())
    ..addTask(DailyReportTask())
    ..addTask(InitTask())

    // Basic routes
    ..get(
      '/',
      (Request req, Response res) => res.json(<String, dynamic>{
        'message': 'Scheduler example running',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    )
    ..get(
      '/tasks',
      (Request req, Response res) => res.json(<String, dynamic>{
        'message': 'Check console for task execution logs',
        'tasks': <String>['cleanup', 'daily-report', 'init'],
      }),
    );

  print('🚀 Starting server with scheduled tasks...');
  print('📋 Active tasks:');
  print('  • CleanupTask (periodic, every 30s)');
  print('  • DailyReportTask (scheduled, runs in 1 minute)');
  print('  • InitTask (instant, runs immediately)');
  print('');

  await app.listen(port: 3000);
}
