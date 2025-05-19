import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    await _migrateDb(_db!);
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'student_management.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE,
            password TEXT,
            name TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE enrolled_courses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            course_name TEXT,
            student_name TEXT,
            student_mobile TEXT,
            father_name TEXT,
            father_mobile TEXT,
            currently_studying INTEGER,
            FOREIGN KEY(user_id) REFERENCES users(id)
          )
        ''');
      },
    );
  }

  // Migration to add profile_image column if it doesn't exist
  Future<void> _migrateDb(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info(users)");
    final hasProfileImage = columns.any((col) => col['name'] == 'profile_image');
    if (!hasProfileImage) {
      await db.execute("ALTER TABLE users ADD COLUMN profile_image TEXT");
    }
  }

  // User registration
  Future<int> registerUser(String email, String password, String name) async {
    final dbClient = await db;
    try {
      return await dbClient.insert('users', {
        'email': email,
        'password': password,
        'name': name,
      });
    } catch (e) {
      return -1; // Email already exists
    }
  }

  // User login
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final dbClient = await db;
    final res = await dbClient.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  // Save enrolled course
  Future<int> enrollCourse(int userId, Map<String, dynamic> courseData) async {
    final dbClient = await db;
    return await dbClient.insert('enrolled_courses', {
      'user_id': userId,
      'course_name': courseData['courseName'],
      'student_name': courseData['studentName'],
      'student_mobile': courseData['studentMobile'],
      'father_name': courseData['fatherName'],
      'father_mobile': courseData['fatherMobile'],
      'currently_studying': courseData['currentlyStudying'] ? 1 : 0,
    });
  }

  // Get enrolled courses for a user
  Future<List<Map<String, dynamic>>> getEnrolledCourses(int userId) async {
    final dbClient = await db;
    return await dbClient.query(
      'enrolled_courses',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
} 