import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:studenttasktracker/repositories/task_repository.dart';

class StudentDashboard extends StatefulWidget {
  final int studentId;

  const StudentDashboard({required this.studentId, Key? key}) : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  late Future<List<Map<String, dynamic>>> _tasksFuture;
  late Future<Map<String, dynamic>?> _progressFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final taskRepo = Provider.of<TaskRepository>(context, listen: false);
    setState(() {
      _tasksFuture = taskRepo.getStudentTasks(widget.studentId);
      _progressFuture = taskRepo.getStudentProgress(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Tasks'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.assignment)),
              Tab(icon: Icon(Icons.assessment)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _loadData,
              child: _buildTasksList(),
            ),
            _buildProgressView(),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.data == null || snapshot.data!.isEmpty) {
          return const Center(child: Text('No tasks assigned'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final task = snapshot.data![index];
            return Card(
              child: ListTile(
                title: Text(task['title']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task['description'] ?? 'No description'),
                    if (task['dueDate'] != null)
                      Text('Due: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(task['dueDate']))}'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProgressView() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _progressFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final progress = snapshot.data!;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: (progress['completedTasks'] ?? 0) / (progress['totalTasks'] ?? 1),
              ),
              const SizedBox(height: 20),
              Text('Completed: ${progress['completedTasks']}/${progress['totalTasks']}'),
              const SizedBox(height: 10),
              Text('Average: ${progress['averageScore']?.toStringAsFixed(1) ?? 'N/A'}'),
            ],
          ),
        );
      },
    );
  }
}