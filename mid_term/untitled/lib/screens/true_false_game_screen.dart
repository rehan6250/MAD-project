import 'dart:math';
import 'package:flutter/material.dart';

class TrueFalseGameScreen extends StatefulWidget {
  final int difficulty;
  final String operator;

  const TrueFalseGameScreen({required this.difficulty, required this.operator});

  @override
  _TrueFalseGameScreenState createState() => _TrueFalseGameScreenState();
}

class _TrueFalseGameScreenState extends State<TrueFalseGameScreen> {
  late int a, b, correctAnswer;
  late String question;
  bool isCorrect = false;
  int score = 0;
  int questionCount = 0;

  @override
  void initState() {
    super.initState();
    generateQuestion();
  }

  void generateQuestion() {
    a = Random().nextInt(widget.difficulty + 1);
    b = Random().nextInt(widget.difficulty + 1);
    int fakeAnswer;
    switch (widget.operator) {
      case '+':
        correctAnswer = a + b;
        break;
      case '-':
        correctAnswer = a - b;
        break;
      case '×':
        correctAnswer = a * b;
        break;
      case '÷':
        correctAnswer = b == 0 ? 0 : (a ~/ b);
        break;
    }
    isCorrect = Random().nextBool();
    fakeAnswer = correctAnswer + (Random().nextInt(4) - 2);
    question = "$a ${widget.operator} $b = ${isCorrect ? correctAnswer : fakeAnswer}";
  }

  void checkAnswer(bool answer) {
    setState(() {
      if (answer == isCorrect) score++;
      questionCount++;
      generateQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('True / False'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Score: $score', style: TextStyle(fontSize: 22, color: Colors.greenAccent)),
            SizedBox(height: 30),
            Text(question, style: TextStyle(fontSize: 26, color: Colors.white)),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () => checkAnswer(true), child: Text("True")),
                ElevatedButton(onPressed: () => checkAnswer(false), child: Text("False")),
              ],
            )
          ],
        ),
      ),
    );
  }
}
