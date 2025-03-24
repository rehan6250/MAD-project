import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(CommitteeApp());
}

class CommitteeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CommitteeScreen(),
    );
  }
}

class CommitteeScreen extends StatefulWidget {
  @override
  _CommitteeScreenState createState() => _CommitteeScreenState();
}

class _CommitteeScreenState extends State<CommitteeScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController limitController = TextEditingController();

  List<String> members = [];
  List<String> committeeOrder = [];
  double? moneyLimit;
  double totalCommitteeAmount = 0;

  void setMoneyLimit() {
    double? limit = double.tryParse(limitController.text);
    if (limit != null && limit > 0) {
      setState(() {
        moneyLimit = limit;
        totalCommitteeAmount = 0;
        members.clear();
        committeeOrder.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Money limit set to $moneyLimit")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter a valid money limit greater than 0")),
      );
    }
  }

  void addMember() {
    String name = nameController.text;

    if (moneyLimit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Set the money limit first!")),
      );
      return;
    }

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter a valid name")),
      );
      return;
    }

    setState(() {
      members.add(name);
      totalCommitteeAmount = members.length * moneyLimit!;
      nameController.clear();
    });
  }

  void startCommittee() {
    if (members.isNotEmpty) {
      List<String> shuffledList = List.from(members);
      shuffledList.shuffle(Random());
      setState(() {
        committeeOrder = shuffledList;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Committee Management")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Set Money Limit"),
            ),
            ElevatedButton(onPressed: setMoneyLimit, child: Text("Set Limit")),
            SizedBox(height: 10),
            TextField(controller: nameController, decoration: InputDecoration(labelText: "Enter Member Name")),
            ElevatedButton(onPressed: addMember, child: Text("Add Member")),
            SizedBox(height: 20),
            Text("Members List", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(members[index]),
                  );
                },
              ),
            ),
            Text("Total Committee Amount: $totalCommitteeAmount", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton(onPressed: startCommittee, child: Text("Start Committee")),
            SizedBox(height: 20),
            if (committeeOrder.isNotEmpty)
              Column(
                children: [
                  Text("Committee Order", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ...committeeOrder.asMap().entries.map((entry) {
                    int position = entry.key + 1;
                    return Text("$position: ${entry.value} receives the committee", style: TextStyle(fontSize: 16));
                  }).toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
