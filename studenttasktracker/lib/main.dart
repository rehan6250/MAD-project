import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studenttasktracker/database/database_helper.dart';
import 'package:studenttasktracker/services/auth_service.dart';
import 'package:studenttasktracker/repositories/student_repository.dart';
import 'package:studenttasktracker/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database factory for non-web platforms
  if (!kIsWeb) {
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile platforms use default sqflite
    } else {
      // Initialize FFI for desktop platforms
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  try {
    // Initialize database
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.initialize();

    // Initialize authentication
    final authService = AuthService(StudentRepository(dbHelper));
    await authService.createDefaultAdmin();

    runApp(
      MultiProvider(
        providers: [
          Provider<DatabaseHelper>(create: (_) => dbHelper),
          Provider<AuthService>(create: (_) => authService),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    _showErrorScreen(e.toString());
  }
}

void _showErrorScreen(String error) {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Initialization Error',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  error,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => main(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Task Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}