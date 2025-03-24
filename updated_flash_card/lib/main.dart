import 'package:flutter/material.dart';

void main() =>
    runApp(MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()));

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Flashcard Categories")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:
              ["Web Development", "Flutter"].map((deck) {
                return ElevatedButton(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FlashCardScreen(deckName: deck),
                        ),
                      ),
                  child: Text(deck),
                );
              }).toList(),
        ),
      ),
    );
  }
}

class FlashCardScreen extends StatefulWidget {
  final String deckName;
  FlashCardScreen({required this.deckName});

  @override
  _FlashCardScreenState createState() => _FlashCardScreenState();
}

class _FlashCardScreenState extends State<FlashCardScreen> {
  int currentIndex = 0, score = 0;
  bool showAnswer = false, quizCompleted = false;
  List<Map<String, String>> userFlashcards = [];

  final Map<String, List<Map<String, String>>> decks = {
    "Web Development": [
      {
        "question": "What does HTML stand for?",
        "answer": "Hypertext Markup Language",
      },
      {"question": "What is CSS used for?", "answer": "Styling websites"},
    ],
    "Flutter": [
      {"question": "Which language does Flutter use?", "answer": "Dart"},
      {
        "question": "What is a StatefulWidget?",
        "answer": "A widget that maintains state",
      },
    ],
  };

  void flipCard() => setState(() => showAnswer = !showAnswer);

  void nextCard(bool isCorrect) {
    setState(() {
      if (isCorrect) score++;
      showAnswer = false;

      var totalCards = decks[widget.deckName]!.length + userFlashcards.length;
      if (currentIndex < totalCards - 1) {
        currentIndex++;
      } else {
        quizCompleted = true;
      }
    });
  }

  void addFlashcard(String question, String answer) {
    if (question.isNotEmpty && answer.isNotEmpty) {
      setState(
        () => userFlashcards.add({"question": question, "answer": answer}),
      );
    }
  }

  void restartQuiz() {
    setState(() {
      currentIndex = 0;
      score = 0;
      showAnswer = false;
      quizCompleted = false;
    });
  }

  void showAddFlashcardDialog() {
    TextEditingController questionController = TextEditingController(),
        answerController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Add Flashcard"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  decoration: InputDecoration(labelText: "Question"),
                ),
                TextField(
                  controller: answerController,
                  decoration: InputDecoration(labelText: "Answer"),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  addFlashcard(questionController.text, answerController.text);
                  Navigator.pop(context);
                },
                child: Text("Add"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var currentDeck = [...decks[widget.deckName]!, ...userFlashcards];

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.deckName} Flashcards"),
        actions: [
          IconButton(icon: Icon(Icons.add), onPressed: showAddFlashcardDialog),
        ],
      ),
      body: Center(
        child:
            quizCompleted
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Quiz Completed!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Your Score: $score / ${currentDeck.length}",
                      style: TextStyle(fontSize: 20),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: restartQuiz,
                      child: Text("Restart Quiz"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Back to Home"),
                    ),
                  ],
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: flipCard,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        width: 300,
                        height: 200,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          showAnswer
                              ? currentDeck[currentIndex]["answer"]!
                              : currentDeck[currentIndex]["question"]!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    if (showAnswer) ...[
                      ElevatedButton(
                        onPressed: () => nextCard(true),
                        child: Text("Correct"),
                      ),
                      ElevatedButton(
                        onPressed: () => nextCard(false),
                        child: Text("Incorrect"),
                      ),
                    ],
                    SizedBox(height: 20),
                    Text("Score: $score", style: TextStyle(fontSize: 18)),
                  ],
                ),
      ),
    );
  }
}
