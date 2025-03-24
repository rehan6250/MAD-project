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
  final TextEditingController amountController = TextEditingController();
  final TextEditingController limitController = TextEditingController();

  List<Map<String, dynamic>> members = [];
  List<String> committeeOrder = [];
  double? moneyLimit; // Ensures limit is set
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
    double? amount = double.tryParse(amountController.text);

    if (moneyLimit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Set the money limit first!")),
      );
      return;
    }

    if (name.isEmpty || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter a valid name and amount")),
      );
      return;
    }

    if (amount != moneyLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Amount must be exactly $moneyLimit")),
      );
      return;
    }

    setState(() {
      members.add({"name": name, "amount": amount});
      totalCommitteeAmount += amount;
      nameController.clear();
      amountController.clear();
    });
  }

  void startCommittee() {
    if (members.isNotEmpty) {
      List<String> names = members.map((m) => m["name"] as String).toList();
      names.shuffle(Random());
      setState(() {
        committeeOrder = names;
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
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Enter Amount")),
            ElevatedButton(onPressed: addMember, child: Text("Add Member")),
            SizedBox(height: 20),
            Text("Members List", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text("${members[index]['name']} - ${members[index]['amount']}"),
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
