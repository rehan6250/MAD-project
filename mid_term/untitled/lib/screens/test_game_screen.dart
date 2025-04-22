import 'dart:math';
import 'package:flutter/material.dart';

class TestGameScreen extends StatefulWidget {
  final String operator;
  final int difficulty;

  const TestGameScreen({required this.operator, required this.difficulty});

  @override
  _TestGameScreenState createState() => _TestGameScreenState();
}

class _TestGameScreenState extends State<TestGameScreen> {
  int questionIndex = 0;
  int correct = 0;
  int wrong = 0;

  late int num1;
  late int num2;
  late int answer;
  List<int> options = [];

  @override
  void initState() {
    super.initState();
    generateQuestion();
  }

  void generateQuestion() {
    final rand = Random();
    num1 = rand.nextInt(widget.difficulty + 1) + 1;
    num2 = rand.nextInt(widget.difficulty + 1) + 1;

    switch (widget.operator) {
      case '+':
        answer = num1 + num2;
        break;
      case '-':
        answer = num1 - num2;
        break;
      case '×':
        answer = num1 * num2;
        break;
      case '÷':
        num2 = num2 == 0 ? 1 : num2;
        num1 = num1 * num2; // to ensure it's divisible
        answer = num1 ~/ num2;
        break;
      default:
        answer = num1 + num2;
    }

    options = List.generate(3, (_) => answer + rand.nextInt(10) - 5).toSet().toList();
    options.add(answer);
    options.shuffle();
  }

  void checkAnswer(int selected) {
    setState(() {
      questionIndex++;
      if (selected == answer) {
        correct++;
      } else {
        wrong++;
      }
      generateQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Test Game"),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text("${questionIndex}/10", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("$correct", style: TextStyle(color: Colors.green, fontSize: 22)),
                SizedBox(width: 12),
                Text("$wrong", style: TextStyle(color: Colors.red, fontSize: 22)),
              ],
            ),
            Spacer(),
            Text(
              "$num1 ${widget.operator} $num2 = ?",
              style: TextStyle(fontSize: 32, color: Colors.white),
            ),
            SizedBox(height: 30),
            ...options.map((opt) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton(
                  onPressed: () => checkAnswer(opt),
                  child: Text("$opt", style: TextStyle(fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    minimumSize: Size(double.infinity, 48),
                  ),
                ),
              );
            }).toList(),
            Spacer(),
          ],
        ),
      ),
    );
  }
}
