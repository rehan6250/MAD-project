import 'package:sqflite/sqflite.dart';
import 'package:studenttasktracker/database/database_helper.dart';
import 'package:studenttasktracker/models/task.dart';

class TaskRepository {
  final DatabaseHelper dbHelper;

  TaskRepository(this.dbHelper);

  Future<int> insertTask(Task task) async {
    try {
      final db = await dbHelper.database;
      return await db.insert(
        'tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting task: $e');
      rethrow;
    }
  }

  Future<List<Task>> getAllTasks() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('tasks');
      return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
    } catch (e) {
      print('Error getting all tasks: $e');
      rethrow;
    }
  }

  Future<int> assignTaskToStudent(int taskId, int studentId) async {
    try {
      final db = await dbHelper.database;
      return await db.insert(
        'student_tasks',
        {
          'taskId': taskId,
          'studentId': studentId,
          'isCompleted': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error assigning task to student: $e');
      rethrow;
    }
  }

  Future<int> completeTask(int studentTaskId, int score) async {
    try {
      final db = await dbHelper.database;
      return await db.update(
        'student_tasks',
        {
          'isCompleted': 1,
          'completionDate': DateTime.now().toIso8601String(),
          'score': score,
        },
        where: 'id = ?',
        whereArgs: [studentTaskId],
      );
    } catch (e) {
      print('Error completing task: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getStudentTasks(int studentId) async {
    try {
      final db = await dbHelper.database;
      return await db.rawQuery('''
        SELECT st.id as studentTaskId, t.*, st.isCompleted, st.score, st.completionDate
        FROM student_tasks st
        JOIN tasks t ON st.taskId = t.id
        WHERE st.studentId = ?
        ORDER BY t.dueDate ASC
      ''', [studentId]);
    } catch (e) {
      print('Error getting student tasks: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getStudentProgress(int studentId) async {
    try {
      final db = await dbHelper.database;
      final results = await db.rawQuery('''
        SELECT 
          COUNT(*) as totalTasks,
          SUM(CASE WHEN st.isCompleted = 1 THEN 1 ELSE 0 END) as completedTasks,
          AVG(st.score) as averageScore
        FROM student_tasks st
        WHERE st.studentId = ?
      ''', [studentId]);

      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Error getting student progress: $e');
      rethrow;
    }
  }

  Future<int> updateTask(Task task) async {
    try {
      final db = await dbHelper.database;
      return await db.update(
        'tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    } catch (e) {
      print('Error updating task: $e');
      rethrow;
    }
  }

  Future<int> deleteTask(int taskId) async {
    try {
      final db = await dbHelper.database;
      // First delete assignments to avoid foreign key constraint violations
      await db.delete(
        'student_tasks',
        where: 'taskId = ?',
        whereArgs: [taskId],
      );
      // Then delete the task
      return await db.delete(
        'tasks',
        where: 'id = ?',
        whereArgs: [taskId],
      );
    } catch (e) {
      print('Error deleting task: $e');
      rethrow;
    }
  }
}