import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('school_tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path;

    if (kIsWeb) {
      // Web platform
      path = filePath;
    } else {
      // Mobile/Desktop platforms
      final directory = await getDatabasesPath();
      path = join(directory, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _createDB(Database db, int version) async {
    // Students table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        isAdmin INTEGER DEFAULT 0
      )
    ''');

    // Tasks table
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        dueDate TEXT,
        maxScore INTEGER DEFAULT 100
      )
    ''');

    // Student-Tasks junction table
    await db.execute('''
      CREATE TABLE student_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL,
        taskId INTEGER NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        completionDate TEXT,
        score INTEGER,
        FOREIGN KEY (studentId) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE,
        UNIQUE(studentId, taskId)
      )
    ''');
  }

  Future<void> initialize() async {
    await database; // Ensures database is initialized
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}