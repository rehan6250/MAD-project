import 'package:flutter/material.dart';

void main() {
  runApp(FlashCardApp());
}

class FlashCardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: FlashCardScreen(),
    );
  }
}

class FlashCardScreen extends StatefulWidget {
  @override
  _FlashCardScreenState createState() => _FlashCardScreenState();
}

class _FlashCardScreenState extends State<FlashCardScreen> {
  List<bool> showAnswers = List.generate(5, (_) => false);

  final List<Map<String, String>> flashcards = [
    {"question": "What does HTML stand for?", "answer": "Hypertext Markup Language"},
    {"question": "Which tag is used for the largest heading in HTML?", "answer": "<h1>"},
    {"question": "What does CSS stand for?", "answer": "Cascading Style Sheets"},
    {"question": "Which language is used to add interactivity to websites?", "answer": "JavaScript"},
    {"question": "What is the purpose of the <meta> tag?", "answer": "To provide metadata"},
  ];

  void flipCard(int index) {
    setState(() {
      showAnswers[index] = !showAnswers[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Flashcard App")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: flashcards.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => flipCard(index),
              child: Container(
                width: double.infinity,
                height: 120,
                margin: EdgeInsets.only(bottom: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  showAnswers[index] ? flashcards[index]["answer"]! : flashcards[index]["question"]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

