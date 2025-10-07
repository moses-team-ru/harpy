#!/usr/bin/env dart

import 'dart:io';

import 'package:talker/talker.dart';

const String version = 'Harpy CLI v0.1.2+1';

final Talker talker = Talker(
  settings: TalkerSettings(titles: {
    TalkerKey.info: version,
    TalkerKey.verbose: version,
  }),
);

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    printUsage();
    return;
  }

  final String? command =
      arguments.elementAtOrNull(0); // Safe because we checked isEmpty above

  switch (command) {
    case 'create':
      await createProject(arguments.skip(1).toList());
      break;
    case 'version':
      printVersion();
      break;
    case 'help':
      printUsage();
      break;
    default:
      talker.warning('Unknown command: ${command ?? '--unknown--'}');
      printUsage();
      exit(1);
  }
}

void printUsage() => talker.verbose('''
Harpy CLI - A tool for creating and managing Harpy applications

Usage:
  harpy <command> [arguments]

Available commands:
  create <project_name>  Create a new Harpy project
  version               Show version information
  help                  Show this help message

Examples:
  harpy create my_api   Create a new project called 'my_api'
  harpy version         Show version
''');

void printVersion() => talker.info('Framework: Harpy v0.1.2+1');

Future<void> createProject(List<String> args) async {
  if (args.isEmpty) {
    talker
      ..error('Project name is required!')
      ..verbose('Usage: harpy create <project_name>');
    exit(1);
  }

  final String projectName = args.elementAtOrNull(0)!;
  final Directory projectDir = Directory(projectName);

  // ignore: avoid_slow_async_io
  if (await projectDir.exists()) {
    talker.error('Directory $projectName already exists');
    exit(1);
  }

  talker.verbose('Creating Harpy project: $projectName');

  // Create project directory
  await projectDir.create();

  // Create pubspec.yaml
  final String pubspecContent = '''
name: $projectName
description: A Harpy backend application
version: 1.0.0
publish_to: 'none' # Remove this line if you wish to publish to pub.dev

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  harpy: ^0.1.1

dev_dependencies:
  lints: ^3.0.0
  test: ^1.24.0
''';

  await File('$projectName/pubspec.yaml').writeAsString(pubspecContent);

  // Create main.dart
  final String mainContent = '''
import 'package:harpy/harpy.dart';

void main() async {
  final app = Harpy();
  
  // Enable CORS and logging
  app.enableCors();
  app.enableLogging();
  
  // Basic routes
  app.get('/', (req, res) {
    return res.json({
      'message': 'Welcome to $projectName!',
      'timestamp': DateTime.now().toIso8601String(),
    });
  });
  
  app.get('/health', (req, res) {
    return res.json({'status': 'healthy'});
  });
  
  // Start server
  await app.listen(port: 3000);
}
''';

  await File('$projectName/lib/main.dart').create(recursive: true);
  await File('$projectName/lib/main.dart').writeAsString(mainContent);

  // Create CLI utility for project management
  final String cliContent = '''
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

void printVersion() {
  print('$projectName CLI v1.0.0');
  print(${version.replaceFirst('CLI', 'Framework')});
}

void printHelp() {
  print(\'\'\'
$projectName - Project Management CLI

Usage:
  dart run bin/$projectName.dart <command>

Available commands:
  serve      Start the development server
  migrate    Run database migrations
  version    Show version information
  help       Show this help message

Examples:
  dart run bin/$projectName.dart serve
  dart run bin/$projectName.dart migrate
\'\'\');
}
''';

  await File('$projectName/bin/$projectName.dart').create(recursive: true);
  await File('$projectName/bin/$projectName.dart').writeAsString(cliContent);

  // Create README.md
  final String readmeContent = '''
# $projectName

A Harpy backend application.

## Getting Started

1. Install dependencies:
   ```bash
   dart pub get
   ```

2. Run the application using the CLI tool:
   ```bash
   dart run bin/$projectName.dart serve
   ```

   Or run directly:
   ```bash
   dart run lib/main.dart
   ```

3. Test the API:
   ```bash
   curl http://localhost:3000
   ```

## Project Structure

```
$projectName/
  ├── bin/
  │   └── $projectName.dart    # CLI management tool
  ├── lib/
  │   └── main.dart            # Main application
  ├── pubspec.yaml
  └── README.md
```

## CLI Commands

The project includes a CLI tool for managing your application:

- **serve** - Start the development server
  ```bash
  dart run bin/$projectName.dart serve
  ```

- **migrate** - Run database migrations (when configured)
  ```bash
  dart run bin/$projectName.dart migrate
  ```

- **version** - Show version information
  ```bash
  dart run bin/$projectName.dart version
  ```

- **help** - Show help message
  ```bash
  dart run bin/$projectName.dart help
  ```

## API Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check

## Development

Add your routes and middleware in `lib/main.dart`. 
The CLI tool in `bin/$projectName.dart` can be extended with additional commands as needed.

For more information about Harpy, visit: https://github.com/moses-team-ru/harpy
''';

  await File('$projectName/README.md').writeAsString(readmeContent);

  // Create .gitignore
  const String gitignoreContent = '''
.dart_tool/
.packages
pubspec.lock
build/

# IDE
.vscode/
.idea/

# OS
.DS_Store

# Environment
.env
''';

  await File('$projectName/.gitignore').writeAsString(gitignoreContent);

  talker
    ..info('✅ Project $projectName created successfully!')
    ..verbose('📁 Project structure:'
        '   $projectName/'
        '     ├── bin/'
        '     │   └── $projectName.dart    # CLI management tool'
        '     ├── lib/'
        '     │   └── main.dart            # Main application'
        '     ├── pubspec.yaml'
        '     └── README.md'
        ' '
        '🚀 Next steps:'
        '  cd $projectName'
        '  dart pub get'
        '  dart run bin/$projectName.dart serve'
        ' '
        '💡 Available CLI commands:'
        '  dart run bin/$projectName.dart serve    # Start the server'
        '  dart run bin/$projectName.dart migrate  # Run migrations'
        '  dart run bin/$projectName.dart help     # Show help'
        ' '
        'Your API will be available at http://localhost:3000');
}
