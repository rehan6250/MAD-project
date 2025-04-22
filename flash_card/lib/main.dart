import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FlashCardApp());
}

class FlashCardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FlashCardScreen(),
    );
  }
}

class FlashCardScreen extends StatefulWidget {
  @override
  _FlashCardScreenState createState() => _FlashCardScreenState();
}

class _FlashCardScreenState extends State<FlashCardScreen> {
  late Database _database;
  List<Map<String, dynamic>> _flashcards = [];
  List<bool> showAnswers = [];

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'flashcards.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE flashcards(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            question TEXT,
            answer TEXT
          )
        ''');
      },
    );

    // Insert sample data if empty
    final existing = await _database.query('flashcards');
    if (existing.isEmpty) {
      await _insertSampleData();
    }

    _loadFlashcards();
  }

  Future<void> _insertSampleData() async {
    List<Map<String, String>> data = [
      {"question": "What does HTML stand for?", "answer": "Hypertext Markup Language"},
      {"question": "Which tag is used for the largest heading in HTML?", "answer": "<h1>"},
      {"question": "What does CSS stand for?", "answer": "Cascading Style Sheets"},
      {"question": "Which language is used to add interactivity to websites?", "answer": "JavaScript"},
      {"question": "What is the purpose of the <meta> tag?", "answer": "To provide metadata"},
    ];

    for (var flashcard in data) {
      await _database.insert('flashcards', flashcard);
    }
  }

  Future<void> _loadFlashcards() async {
    final data = await _database.query('flashcards');
    setState(() {
      _flashcards = data;
      showAnswers = List.generate(_flashcards.length, (_) => false);
    });
  }

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
        child: _flashcards.isEmpty
            ? Center(child: CircularProgressIndicator())
            : ListView.builder(
          itemCount: _flashcards.length,
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
                  showAnswers[index]
                      ? _flashcards[index]['answer']
                      : _flashcards[index]['question'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
