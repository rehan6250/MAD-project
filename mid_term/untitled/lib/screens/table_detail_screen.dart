import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TableDetailScreen extends StatelessWidget {
  final int number;

  TableDetailScreen({required this.number});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
            icon: Icon(FontAwesomeIcons.arrowLeft),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("Table of $number")),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, i) {
          final result = number * (i + 1);
          return ListTile(
            leading: Icon(
              FontAwesomeIcons.equals,
              color: Colors.indigo,
            ),
            title: Text(
              '$number × ${i + 1} = $result',
              style: TextStyle(fontSize: 22),
            ),
          );
        },
      ),
    );
  }
}
