import 'package:flutter/material.dart';
import 'test_game_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String selectedDifficulty = 'Easy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        leading: IconButton(
          icon: Icon(FontAwesomeIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBox('Completed', '0'),
                _buildStatBox('Accuracy Rate', '0%'),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCorrectWrongBox('Correct', '0', Colors.green, FontAwesomeIcons.check),
                _buildCorrectWrongBox('Wrong', '0', Colors.red, FontAwesomeIcons.xmark),
              ],
            ),
            SizedBox(height: 30),
            Text('Choose Test Complexity', style: TextStyle(fontSize: 18, color: Colors.white)),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['Easy', 'Middle', 'Hard'].map((level) {
                return GestureDetector(
                  onTap: () => setState(() => selectedDifficulty = level),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: selectedDifficulty == level ? Colors.indigo : Colors.grey[800],
                        child: Icon(
                          level == 'Easy'
                              ? FontAwesomeIcons.child
                              : level == 'Middle'
                              ? FontAwesomeIcons.graduationCap
                              : FontAwesomeIcons.brain,
                          color: Colors.white,
                        ),
                        radius: 28,
                      ),
                      SizedBox(height: 8),
                      Text(level, style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                );
              }).toList(),
            ),
            Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TestGameScreen(
                      difficulty: getDifficultyLevel(selectedDifficulty),
                      operator: '×',
                    ),
                  ),
                );
              },
              icon: Icon(Icons.play_arrow),
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                child: Text("START TEST", style: TextStyle(fontSize: 18)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String title, String value) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.withAlpha(20),
            border: Border.all(color: Colors.indigo),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 20, color: Colors.white)),
              SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 14, color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCorrectWrongBox(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, color: Colors.white)),
          SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  int getDifficultyLevel(String label) {
    switch (label) {
      case 'Easy':
        return 1;
      case 'Middle':
        return 2;
      case 'Hard':
        return 3;
      default:
        return 1;
    }
  }
}
