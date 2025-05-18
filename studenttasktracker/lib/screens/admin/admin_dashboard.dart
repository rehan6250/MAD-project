import 'package:flutter/material.dart';
import 'students_tab.dart';
import 'tasks_tab.dart';
import 'assign_tasks_tab.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [ // Removed const
      StudentsTab(),
      TasksTab(),
      AssignTasksTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Students',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in),
            label: 'Assign Tasks',
          ),
        ],
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}