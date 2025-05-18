import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:studenttasktracker/database/database_helper.dart';
import 'package:studenttasktracker/models/student.dart';
import 'package:studenttasktracker/repositories/student_repository.dart';

class StudentsTab extends StatefulWidget {
  @override
  _StudentsTabState createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  late Future<List<Student>> _studentsFuture;
  late StudentRepository _studentRepository;

  @override
  void initState() {
    super.initState();
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);
    _studentRepository = StudentRepository(dbHelper);
    _refreshStudents();
  }

  Future<void> _refreshStudents() {
    setState(() {
      _studentsFuture = _studentRepository.getAllStudents();
    });
    return _studentsFuture;
  }

  Future<void> _addStudent() async {
    final newStudent = Student(
      name: 'New Student',
      email: 'new${DateTime.now().millisecondsSinceEpoch}@school.com',
      password: 'password',
    );

    await _studentRepository.insertStudent(newStudent);
    await _refreshStudents();
  }

  Future<void> _deleteStudent(int id) async {
    await _studentRepository.deleteStudent(id);
    await _refreshStudents();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _addStudent,
                child: const Text('Add Student'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement Excel import
                },
                child: const Text('Import from Excel'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshStudents,
            child: FutureBuilder<List<Student>>(
              future: _studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.data!.isEmpty) {
                  return const Center(child: Text('No students found'));
                }

                final students = snapshot.data!;
                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Dismissible(
                      key: Key(student.id.toString()),
                      background: Container(color: Colors.red),
                      onDismissed: (_) => _deleteStudent(student.id!),
                      child: ListTile(
                        title: Text(student.name),
                        subtitle: Text(student.email),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteStudent(student.id!),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}