import 'package:studenttasktracker/models/student.dart';
import 'package:studenttasktracker/repositories/student_repository.dart';

class AuthService {
  final StudentRepository studentRepository;

  AuthService(this.studentRepository);

  // Add this method
  Future<void> createDefaultAdmin() async {
    final adminExists = await studentRepository.getStudentByEmail('admin@school.com');
    if (adminExists == null) {
      await studentRepository.insertStudent(
        Student(
          name: 'Admin',
          email: 'admin@school.com',
          password: 'admin123', // Note: In production, hash this password
          isAdmin: true,
        ),
      );
    }
  }

  Future<Student?> login(String email, String password) async {
    final student = await studentRepository.getStudentByEmail(email);
    if (student != null && student.password == password) {
      return student;
    }
    return null;
  }

  Future<void> logout() async {
    // Implement logout logic if needed
  }
}