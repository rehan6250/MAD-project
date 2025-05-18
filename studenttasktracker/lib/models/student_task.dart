// models/student_task.dart
class StudentTask {
  final int? id;
  final int studentId;
  final int taskId;
  final bool isCompleted;
  final DateTime? completionDate;
  final int? score;

  StudentTask({
    this.id,
    required this.studentId,
    required this.taskId,
    this.isCompleted = false,
    this.completionDate,
    this.score,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'taskId': taskId,
      'isCompleted': isCompleted ? 1 : 0,
      'completionDate': completionDate?.toIso8601String(),
      'score': score,
    };
  }

  factory StudentTask.fromMap(Map<String, dynamic> map) {
    return StudentTask(
      id: map['id'],
      studentId: map['studentId'],
      taskId: map['taskId'],
      isCompleted: map['isCompleted'] == 1,
      completionDate: map['completionDate'] != null
          ? DateTime.parse(map['completionDate'])
          : null,
      score: map['score'],
    );
  }
}