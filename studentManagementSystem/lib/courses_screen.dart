import 'package:flutter/material.dart';
import 'enrolled_courses_screen.dart';
import 'enrollment_form_screen.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class CoursesScreen extends StatefulWidget {
  final int userId;
  const CoursesScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final List<String> courses = [
    'Google SEO',
    'C++ OOP and DS',
    'Python',
    'Supabase',
    'Flutter',
  ];

  Map<String, Map<String, dynamic>> enrolledCourses = {};
  bool isLoading = true;
  int totalStudents = 0;
  int totalEnrolledCourses = 0;
  String? profileImagePath;
  String? userName;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchStats();
    _fetchEnrolledCourses();
  }

  Future<void> _fetchUserProfile() async {
    final db = await DBHelper().db;
    final res = await db.query('users', where: 'id = ?', whereArgs: [widget.userId]);
    if (res.isNotEmpty) {
      setState(() {
        profileImagePath = res.first['profile_image']?.toString();
        userName = res.first['name']?.toString();
        userEmail = res.first['email']?.toString();
      });
    }
  }

  Future<void> _fetchStats() async {
    final db = await DBHelper().db;
    final students = await db.query('users');
    final enrolled = await db.query('enrolled_courses');
    setState(() {
      totalStudents = students.length;
      totalEnrolledCourses = enrolled.length;
    });
  }

  Future<void> _fetchEnrolledCourses() async {
    setState(() => isLoading = true);
    final dbCourses = await DBHelper().getEnrolledCourses(widget.userId);
    setState(() {
      enrolledCourses = {
        for (var c in dbCourses) c['course_name'].toString(): c,
      };
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Text('App Info', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: Icon(Icons.people, color: Theme.of(context).primaryColor),
              title: Text('Registered Students: $totalStudents'),
            ),
            ListTile(
              leading: Icon(Icons.book, color: Theme.of(context).primaryColor),
              title: Text('Enrolled Courses: $totalEnrolledCourses'),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFEAF6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: PopupMenuButton<String>(
          icon: profileImagePath != null && profileImagePath!.isNotEmpty
              ? CircleAvatar(
                  backgroundImage: FileImage(File(profileImagePath!)),
                )
              : Icon(Icons.menu, color: Theme.of(context).primaryColor),
          onSelected: (value) async {
            if (value == 'edit') {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditProfileScreen(userId: widget.userId)),
              );
              await _fetchUserProfile();
            } else if (value == 'logout') {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('userId');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: (profileImagePath != null && profileImagePath!.isNotEmpty)
                        ? FileImage(File(profileImagePath!))
                        : null,
                    child: (profileImagePath == null || profileImagePath!.isEmpty)
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(userEmail ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit Profile'),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Text('Logout'),
            ),
          ],
        ),
        title: Text(
          'Student',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: Theme.of(context).primaryColor),
            onPressed: () {},
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  color: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Text(
                    'Available Courses',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      final isEnrolled = enrolledCourses.containsKey(course);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          title: Text(
                            course,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          subtitle: Text(
                            isEnrolled ? 'Status: Enrolled' : 'Status: N/A',
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          trailing: ElevatedButton(
                            onPressed: isEnrolled
                                ? null
                                : () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EnrollmentFormScreen(courseName: course),
                                      ),
                                    );
                                    if (result != null && result is Map<String, dynamic>) {
                                      await DBHelper().enrollCourse(widget.userId, result);
                                      await _fetchEnrolledCourses();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEnrolled ? Colors.grey : Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            ),
                            child: Text(
                              isEnrolled ? 'Enrolled' : 'Enroll',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).primaryColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.white,
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EnrolledCoursesScreen(
                  userId: widget.userId,
                ),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_list),
            label: '',
          ),
        ],
      ),
    );
  }
} 