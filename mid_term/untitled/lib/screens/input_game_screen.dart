import 'dart:math';
import 'package:flutter/material.dart';

class InputGameScreen extends StatefulWidget {
  final int difficulty;
  final String operator;

  const InputGameScreen({required this.difficulty, required this.operator});

  @override
  _InputGameScreenState createState() => _InputGameScreenState();
}

class _InputGameScreenState extends State<InputGameScreen> {
  final TextEditingController controller = TextEditingController();
  late int a, b, correctAnswer;
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
        correctAnswer = b == 0 ? 0 : a ~/ b;
        break;
    }
    controller.clear();
  }

  void checkAnswer() {
    if (int.tryParse(controller.text) == correctAnswer) {
      score++;
    }
    questionCount++;
    generateQuestion();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Input Game'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Score: $score', style: TextStyle(fontSize: 22, color: Colors.greenAccent)),
            SizedBox(height: 30),
            Text('$a ${widget.operator} $b = ?', style: TextStyle(fontSize: 26, color: Colors.white)),
            SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your answer',
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
              ),
              onSubmitted: (_) => checkAnswer(),
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: checkAnswer, child: Text("Submit"))
          ],
        ),
      ),
    );
  }
}
