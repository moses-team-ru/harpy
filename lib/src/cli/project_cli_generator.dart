/// Generator for project-specific CLI tools
///
/// This class generates the CLI utility that will be placed in
/// bin/<project_name>.dart of each created Harpy project.
class ProjectCliGenerator {
  /// Creates a new CLI generator
  const ProjectCliGenerator({
    required this.projectName,
    required this.frameworkVersion,
  });

  /// The name of the project
  final String projectName;

  /// The framework version string
  final String frameworkVersion;

  /// Generate the complete CLI file content
  String generate() => '''
#!/usr/bin/env dart

import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    printHelp();
    exit(0);
  }

  final command = args[0];

  switch (command) {
    case 'serve':
      await serve();
      break;
    case 'migrate':
      await migrate();
      break;
    case 'task':
      await handleTask(args.skip(1).toList());
      break;
    case 'version':
      printVersion();
      break;
    case 'help':
    case '--help':
    case '-h':
      printHelp();
      break;
    default:
      print('Unknown command: \\\$command');
      printHelp();
      exit(1);
  }
}

Future<void> serve() async {
  print('🚀 Starting $projectName server...');
  print('');
  
  // Run the main application
  final result = await Process.start(
    'dart',
    ['run', 'lib/main.dart'],
    mode: ProcessStartMode.inheritStdio,
  );
  
  await result.exitCode;
}

Future<void> migrate() async {
  print('🔄 Running database migrations...');
  
  // TODO: Implement database migration logic
  // This is a placeholder for migration functionality
  print('Migration functionality not yet implemented.');
  print('You can add your migration logic here.');
}

Future<void> handleTask(List<String> args) async {
  if (args.isEmpty) {
    printTaskHelp();
    exit(1);
  }
  
  final subcommand = args[0];
  
  switch (subcommand) {
    case 'add':
      await taskAdd(args.skip(1).toList());
      break;
    case 'list':
      await taskList();
      break;
    case 'help':
      printTaskHelp();
      break;
    default:
      print('Unknown task command: \\\$subcommand');
      printTaskHelp();
      exit(1);
  }
}

Future<void> taskAdd(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Task name is required!');
    print('Usage: dart run bin/$projectName.dart task add <task_name>');
    exit(1);
  }
  
  final taskName = args[0];
  final className = _toCamelCase(taskName);
  
  print('🔨 Creating task: \\\$taskName');
  
  // Выбор типа задачи
  print('');
  print('Select task type:');
  print('  1. Periodic (runs at regular intervals)');
  print('  2. Scheduled (runs at specific time)');
  print('  3. Instant (runs once immediately)');
  print('');
  stdout.write('Enter choice [1-3]: ');
  
  final choice = stdin.readLineSync() ?? '1';
  
  final taskContent = _generateTaskContent(className, taskName, choice);
  
  // Создать директорию tasks если не существует
  final tasksDir = Directory('lib/tasks');
  if (!await tasksDir.exists()) {
    await tasksDir.create(recursive: true);
  }
  
  // Создать файл задачи
  final taskFile = File('lib/tasks/\\\${taskName}_task.dart');
  await taskFile.writeAsString(taskContent);
  
  print('');
  print('✅ Task created: lib/tasks/\\\${taskName}_task.dart');
  print('');
  print('📝 Next steps:');
  print('  1. Implement the execute() method in \\\$className');
  print('  2. Register the task in lib/main.dart:');
  print('     app.addTask(\\\$className());');
  print('  3. Run your app: dart run bin/$projectName.dart serve');
}

String _generateTaskContent(String className, String taskName, String type) {
  switch (type) {
    case '1': // Periodic
      return \'\'\'
import 'package:harpy/harpy.dart';

/// \$className - Periodic task
/// 
/// This task runs at regular intervals
class \$className extends Task {
  \$className() : super.periodic(
    id: '\$taskName',
    interval: Duration(minutes: 5), // Configure your interval
  );
  
  @override
  Future<void> execute() async {
    // TODO: Implement your periodic task logic here
    print('[\$taskName] Executing periodic task...');
    
    // Example: Database cleanup
    // final result = await database.execute('DELETE FROM cache WHERE expired = 1');
    
    print('[\$taskName] Task completed');
  }
  
  @override
  void finalize() {
    print('[\$taskName] Task finalized');
  }
}
\'\'\';
    case '2': // Scheduled
      return \'\'\'
import 'package:harpy/harpy.dart';

/// \$className - Scheduled task
/// 
/// This task runs at a specific time
class \$className extends Task {
  \$className() : super.scheduled(
    id: '\$taskName',
    scheduled: DateTime.utc(2025, 10, 8, 9, 0), // Configure your schedule (UTC)
  );
  
  @override
  Future<void> execute() async {
    // TODO: Implement your scheduled task logic here
    print('[\$taskName] Executing scheduled task...');
    
    // Example: Daily report generation
    // await generateDailyReport();
    
    print('[\$taskName] Task completed');
  }
  
  @override
  void finalize() {
    print('[\$taskName] Task finalized');
  }
}
\'\'\';
    case '3': // Instant
    default:
      return \'\'\'
import 'package:harpy/harpy.dart';

/// \$className - Instant task
/// 
/// This task runs once immediately on startup
class \$className extends Task {
  \$className() : super.instant(
    id: '\$taskName',
  );
  
  @override
  Future<void> execute() async {
    // TODO: Implement your instant task logic here
    print('[\$taskName] Executing instant task...');
    
    // Example: Initialization logic
    // await initializeCache();
    
    print('[\$taskName] Task completed');
  }
  
  @override
  void finalize() {
    print('[\$taskName] Task finalized');
  }
}
\'\'\';
  }
}

Future<void> taskList() async {
  print('📋 Tasks in project:');
  print('');
  
  final tasksDir = Directory('lib/tasks');
  if (!await tasksDir.exists()) {
    print('  No tasks found.');
    print('  Create one with: dart run bin/$projectName.dart task add <name>');
    return;
  }
  
  final tasks = await tasksDir
      .list()
      .where((entity) => entity is File && entity.path.endsWith('_task.dart'))
      .toList();
  
  if (tasks.isEmpty) {
    print('  No tasks found.');
    print('  Create one with: dart run bin/$projectName.dart task add <name>');
    return;
  }
  
  for (var task in tasks) {
    final name = task.uri.pathSegments.last.replaceAll('_task.dart', '');
    print('  • \\\$name');
  }
  
  print('');
  print('Total: \\\${tasks.length} task(s)');
}

String _toCamelCase(String str) {
  final parts = str.split(RegExp(r'[-_]'));
  return parts.map((part) {
    if (part.isEmpty) return '';
    return part[0].toUpperCase() + part.substring(1).toLowerCase();
  }).join('') + 'Task';
}

void printVersion() {
  print('$projectName CLI v1.0.0');
  print('$frameworkVersion');
}

void printHelp() {
  print(\'\'\'
$projectName - Project Management CLI

Usage:
  dart run bin/$projectName.dart <command> [arguments]

Available commands:
  serve      Start the development server
  migrate    Run database migrations
  task       Manage scheduled tasks (add, list, help)
  version    Show version information
  help       Show this help message

Examples:
  dart run bin/$projectName.dart serve
  dart run bin/$projectName.dart migrate
  dart run bin/$projectName.dart task add cleanup
  dart run bin/$projectName.dart task list

For more information about tasks:
  dart run bin/$projectName.dart task help

This CLI tool is specific to the $projectName project.
For framework-level operations, use the global 'harpy' command.
\'\'\');
}

void printTaskHelp() {
  print(\'\'\'
Task Management Commands

Usage:
  dart run bin/$projectName.dart task <command> [arguments]

Available commands:
  add <task_name>   Create a new task
  list              List all tasks in the project
  help              Show this help message

Examples:
  dart run bin/$projectName.dart task add cleanup
  dart run bin/$projectName.dart task add daily-report
  dart run bin/$projectName.dart task list

Task Types:
  1. Periodic   - Runs at regular intervals (e.g., every 5 minutes)
  2. Scheduled  - Runs at specific time (e.g., daily at 9:00 AM)
  3. Instant    - Runs once immediately on startup
\'\'\');
}
''';
}
