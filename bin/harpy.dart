#!/usr/bin/env dart

import 'dart:io';

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
      print('Unknown command: ${command ?? '--unknown--'}');
      printUsage();
      exit(1);
  }
}

void printUsage() {
  print('''
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
}

void printVersion() {
  print('Harpy CLI v0.1.0');
  print('Framework: Harpy v0.1.0');
}

Future<void> createProject(List<String> args) async {
  if (args.isEmpty) {
    print('Error: Project name is required');
    print('Usage: harpy create <project_name>');
    exit(1);
  }

  final String projectName = args.elementAtOrNull(0)!;
  final Directory projectDir = Directory(projectName);

  // ignore: avoid_slow_async_io
  if (await projectDir.exists()) {
    print('Error: Directory $projectName already exists');
    exit(1);
  }

  print('Creating Harpy project: $projectName');

  // Create project directory
  await projectDir.create();

  // Create pubspec.yaml
  final String pubspecContent = '''
name: $projectName
description: A Harpy backend application
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  harpy: ^0.1.0

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

  await File('$projectName/bin/main.dart').create(recursive: true);
  await File('$projectName/bin/main.dart').writeAsString(mainContent);

  // Create README.md
  final String readmeContent = '''
# $projectName

A Harpy backend application.

## Getting Started

1. Install dependencies:
   ```bash
   dart pub get
   ```

2. Run the application:
   ```bash
   dart run bin/main.dart
   ```

3. Test the API:
   ```bash
   curl http://localhost:3000
   ```

## API Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check

## Development

Add your routes and middleware in `bin/main.dart`.

For more information about Harpy, visit: https://github.com/yourusername/harpy
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

  print('✅ Project $projectName created successfully!');
  print('');
  print('Next steps:');
  print('  cd $projectName');
  print('  dart pub get');
  print('  dart run bin/main.dart');
  print('');
  print('Your API will be available at http://localhost:3000');
}
