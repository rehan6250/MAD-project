import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'learn_table_screen.dart';
import 'test_screen.dart';
import 'training_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Home")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _navButton(
              context,
              icon: FontAwesomeIcons.calculator,
              label: "Learn Table",
              screen: LearnTableScreen(),
            ),
            _navButton(
              context,
              icon: FontAwesomeIcons.clipboardQuestion,
              label: "Test",
              screen: TestScreen(),
            ),
            _navButton(
              context,
              icon: FontAwesomeIcons.dumbbell,
              label: "Training",
              screen: TrainingScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton(BuildContext context,
      {required IconData icon, required String label, required Widget screen}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 24),
        label: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(label, style: TextStyle(fontSize: 18)),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ),
      ),
    );
  }
}
