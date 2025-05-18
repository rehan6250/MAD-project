// database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        isAdmin INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        dueDate TEXT,
        maxScore INTEGER DEFAULT 100
      )
    ''');

    await db.execute('''
      CREATE TABLE student_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL,
        taskId INTEGER NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        completionDate TEXT,
        score INTEGER,
        FOREIGN KEY (studentId) REFERENCES students (id),
        FOREIGN KEY (taskId) REFERENCES tasks (id)
      )
    ''');
  }

  // Close the database
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}