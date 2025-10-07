import 'dart:async';

/// Task class for managing periodic and scheduled tasks
abstract class Task {
  /// Periodic task constructor
  Task.periodic({
    required Duration interval,
    required String id,
    Map<String, dynamic>? params,
  }) : this._(id: id, interval: interval, params: params);

  /// Scheduled task constructor
  Task.scheduled({
    required DateTime scheduled,
    required String id,
    Map<String, dynamic>? params,
  }) : this._(id: id, scheduled: scheduled, params: params);

  /// Instant task constructor
  Task.instant({required String id, Map<String, dynamic>? params})
      : this._(id: id, params: params);

  /// Private constructor to enforce the use of named constructors
  Task._({required this.id, this.interval, this.scheduled, this.params})
      : assert(
          (interval != null && scheduled == null) ||
              (scheduled != null && interval == null) ||
              (interval == null && scheduled == null),
          'Task must be either periodic or scheduled, not both',
        );

  /// Unique identifier for the task
  final String id;

  /// Additional parameters for the task
  final Map<String, dynamic>? params;

  /// Only one of these will be non-null depending on type
  final DateTime? scheduled;

  /// If type is periodic, this will be the interval between runs
  final Duration? interval;

  /// Timer for periodic tasks
  Timer? _timer;

  /// Backing field for isEnabled
  bool _isEnabled = true;

  /// Backing field for _isRunning
  bool _isRunningFlag = false;

  /// Finalize the task, cleaning up resources if necessary
  void finalize();

  /// Execute the task logic
  Future<void> execute();

  /// Enable or disable the task
  set isEnabled(bool value) {
    if (!value && _isRunningFlag) {
      throw StateError('Task is running, cannot disable');
    }
    _isEnabled = value;
  }

  /// Indicates if the task is currently running
  bool get isEnabled => _isEnabled;

  /// Indicates if the task is periodic
  bool get isPeriodic => interval != null;

  /// Indicates if the task is scheduled
  bool get isScheduled => scheduled != null;

  /// Indicates if the task is instant
  bool get isInstant => !isPeriodic && !isScheduled;

  /// Get the timer for periodic tasks
  set timer(Timer t) {
    if (_timer != null && _timer!.isActive) {
      throw StateError('Timer is already set and active');
    }
    _timer = t;
  }

  /// Get the timer for periodic tasks
  Timer get timer => _timer ?? (throw StateError('Timer is not set'));

  /// Enable or disable the task
  set _isRunning(bool value) {
    if (value) {
      if (!isEnabled) {
        throw StateError('Task is not enabled, cannot run');
      }
    }
    _isRunningFlag = value;
  }

  /// Indicates if the task is currently running
  bool get _isRunning => _isRunningFlag;

  /// Start the task if it is not already running
  Future<void> run() {
    /// If the task is already running or not enabled, return a completed future
    if (_isRunning || !isEnabled) return Future<void>.value();

    _isRunning = true;
    return execute().whenComplete(() => _isRunning = false);
  }
}
