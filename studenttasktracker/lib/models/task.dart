// models/task.dart
class Task {
  final int? id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final int maxScore;

  Task({
    this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.maxScore = 100,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'maxScore': maxScore,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      maxScore: map['maxScore'],
    );
  }
}