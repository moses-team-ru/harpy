import 'package:harpy/harpy.dart';
import 'package:test/test.dart';

class SchedulerMiddlewareTest extends Task {
  SchedulerMiddlewareTest.periodic()
      : super.periodic(
          id: 'test-periodic',
          interval: const Duration(milliseconds: 100),
        );

  SchedulerMiddlewareTest.instant() : super.instant(id: 'test-instant');
  int executionCount = 0;

  @override
  Future<void> execute() async {
    executionCount++;
  }

  @override
  void finalize() {
    executionCount = 0;
  }
}

void main() {
  group('SchedulerMiddleware', () {
    test('should add and execute periodic task', () async {
      final Harpy app = Harpy()..enableScheduler();

      final SchedulerMiddlewareTest task = SchedulerMiddlewareTest.periodic();
      app.addTask(task);

      // Wait for a few executions
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(task.executionCount, greaterThan(2));

      app.stopScheduler();
    });

    test('should execute instant task immediately', () async {
      final Harpy app = Harpy()..enableScheduler();

      final SchedulerMiddlewareTest task = SchedulerMiddlewareTest.instant();
      app.addTask(task);

      // Give it time to execute
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(task.executionCount, equals(1));
    });

    test('should remove task', () async {
      final Harpy app = Harpy()..enableScheduler();

      final SchedulerMiddlewareTest task = SchedulerMiddlewareTest.periodic();
      app.addTask(task);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      final int countBefore = task.executionCount;

      app.removeTask('test-periodic');

      await Future<void>.delayed(const Duration(milliseconds: 250));
      final int countAfter = task.executionCount;

      expect(countAfter, equals(countBefore));
    });

    test('should stop all tasks', () async {
      final Harpy app = Harpy()..enableScheduler();

      final SchedulerMiddlewareTest task1 = SchedulerMiddlewareTest.periodic();
      app.addTask(task1);

      await Future<void>.delayed(const Duration(milliseconds: 150));

      app.stopScheduler();
      final int countBefore = task1.executionCount;

      await Future<void>.delayed(const Duration(milliseconds: 150));
      final int countAfter = task1.executionCount;

      expect(countAfter, equals(countBefore));
    });

    test('should throw error when adding task without enabling scheduler', () {
      final Harpy app = Harpy();

      expect(
        () => app.addTask(SchedulerMiddlewareTest.instant()),
        throwsStateError,
      );
    });

    test('should track task count', () {
      final Harpy app = Harpy()..enableScheduler();

      expect(app.taskCount, equals(0));

      app
        ..addTask(SchedulerMiddlewareTest.periodic())
        ..addTask(SchedulerMiddlewareTest.instant());

      expect(app.taskCount, equals(2));
    });

    test('should list task IDs', () {
      final Harpy app = Harpy()
        ..enableScheduler()
        ..addTask(SchedulerMiddlewareTest.periodic())
        ..addTask(SchedulerMiddlewareTest.instant());

      expect(app.taskIds, contains('test-periodic'));
      expect(app.taskIds, contains('test-instant'));
      expect(app.taskIds.length, equals(2));
    });
  });
}
