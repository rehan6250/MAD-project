import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Center(child: Text("Student Information"),),
          backgroundColor: Colors.lightBlueAccent,
        ),
        backgroundColor: Colors.blueGrey,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Name: Rehan Ashraf", style: TextStyle(fontSize: 24)),
              Text(
                "RegistrationNumber: BSE 088",
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

