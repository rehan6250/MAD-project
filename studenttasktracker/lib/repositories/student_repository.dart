import 'package:sqflite/sqflite.dart';
import 'package:studenttasktracker/database/database_helper.dart';
import 'package:studenttasktracker/models/student.dart';

class StudentRepository {
  final DatabaseHelper dbHelper;

  StudentRepository(this.dbHelper);

  Future<int> insertStudent(Student student) async {
    try {
      final db = await dbHelper.database;
      return await db.insert(
        'students',
        student.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting student: $e');
      rethrow;
    }
  }

  Future<List<Student>> getAllStudents() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('students');
      return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
    } catch (e) {
      print('Error getting all students: $e');
      rethrow;
    }
  }

  Future<Student?> getStudentByEmail(String email) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'students',
        where: 'email = ?',
        whereArgs: [email],
        limit: 1,
      );
      return maps.isNotEmpty ? Student.fromMap(maps.first) : null;
    } catch (e) {
      print('Error getting student by email: $e');
      rethrow;
    }
  }

  Future<int> importStudentsFromExcel(List<Student> students) async {
    try {
      final db = await dbHelper.database;
      final batch = db.batch();

      for (final student in students) {
        batch.insert(
          'students',
          student.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final results = await batch.commit();
      return results.length;
    } catch (e) {
      print('Error importing students: $e');
      rethrow;
    }
  }

  Future<int> updateStudent(Student student) async {
    try {
      final db = await dbHelper.database;
      return await db.update(
        'students',
        student.toMap(),
        where: 'id = ?',
        whereArgs: [student.id],
      );
    } catch (e) {
      print('Error updating student: $e');
      rethrow;
    }
  }

  Future<int> deleteStudent(int id) async {
    try {
      final db = await dbHelper.database;
      return await db.delete(
        'students',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting student: $e');
      rethrow;
    }
  }
}