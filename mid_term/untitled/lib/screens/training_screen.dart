import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'test_game_screen.dart';
import 'true_false_game_screen.dart';
import 'input_game_screen.dart';

class TrainingScreen extends StatefulWidget {
  @override
  _TrainingScreenState createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  String selectedOperator = '+';
  double difficulty = 20;

  void startGame(String gameType) {
    Widget screen;

    switch (gameType) {
      case 'Test':
        screen = TestGameScreen(
          difficulty: difficulty.toInt(),
          operator: selectedOperator,
        );
        break;
      case 'TrueFalse':
        screen = TrueFalseGameScreen(
          difficulty: difficulty.toInt(),
          operator: selectedOperator,
        );
        break;
      case 'Input':
        screen = InputGameScreen(
          difficulty: difficulty.toInt(),
          operator: selectedOperator,
        );
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget operatorButton(String label, IconData icon) {
    final isSelected = selectedOperator == label;
    return ElevatedButton.icon(
      onPressed: () => setState(() => selectedOperator = label),
      icon: Icon(icon, color: isSelected ? Colors.white : Colors.grey),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.indigo : Colors.transparent,
        side: BorderSide(color: Colors.white24),
        foregroundColor: isSelected ? Colors.white : Colors.white70,
      ),
    );
  }

  Widget gameTypeButton(String title, IconData icon, String gameType) {
    return ElevatedButton.icon(
      onPressed: () => startGame(gameType),
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: BackButton(),
        title: Text("Training Mode"),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("What would you like to train?", style: TextStyle(color: Colors.white, fontSize: 18)),
            SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                operatorButton('+', FontAwesomeIcons.plus),
                operatorButton('-', FontAwesomeIcons.minus),
                operatorButton('×', FontAwesomeIcons.xmark),
                operatorButton('÷', FontAwesomeIcons.divide),
              ],
            ),
            SizedBox(height: 30),
            Text("Difficulty (${difficulty.toInt()} / 100)", style: TextStyle(color: Colors.white)),
            Slider(
              value: difficulty,
              onChanged: (value) => setState(() => difficulty = value),
              min: 0,
              max: 100,
              activeColor: Colors.purpleAccent,
              inactiveColor: Colors.purple.shade900,
            ),
            SizedBox(height: 30),
            Text("Choose Game Type", style: TextStyle(color: Colors.white, fontSize: 16)),
            SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                gameTypeButton('Test', FontAwesomeIcons.pen, 'Test'),
                gameTypeButton('True / False', FontAwesomeIcons.checkDouble, 'TrueFalse'),
                gameTypeButton('Input', FontAwesomeIcons.keyboard, 'Input'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
