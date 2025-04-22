import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CommitteeApp());
}

class CommitteeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Committee App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
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

  late Database _database;
  List<String> members = [];
  List<String> committeeOrder = [];
  double? moneyLimit = 0;
  double totalCommitteeAmount = 0;

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'committee.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT
          );
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          );
        ''');
      },
    );

    _loadData();
  }

  Future<void> _loadData() async {
    final memberList = await _database.query('members');
    final settingList = await _database.query('settings', where: "key = 'moneyLimit'");

    setState(() {
      members = memberList.map((e) => e['name'].toString()).toList();
      if (settingList.isNotEmpty) {
        moneyLimit = double.tryParse(settingList.first['value'].toString()) ?? 0;
        totalCommitteeAmount = members.length * (moneyLimit ?? 0);
        limitController.text = moneyLimit.toString();
      }
    });
  }

  Future<void> _setMoneyLimit() async {
    final limit = double.tryParse(limitController.text.trim());
    if (limit != null && limit > 0) {
      await _database.insert(
        'settings',
        {'key': 'moneyLimit', 'value': limit.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      setState(() {
        moneyLimit = limit;
        totalCommitteeAmount = members.length * moneyLimit!;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Money limit set to $moneyLimit")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid money limit")),
      );
    }
  }

  Future<void> _addMember() async {
    final name = nameController.text.trim();
    if (moneyLimit == null || moneyLimit! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please set the money limit first")),
      );
      return;
    }

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid member name")),
      );
      return;
    }

    await _database.insert('members', {'name': name});
    nameController.clear();
    _loadData();
  }

  void _startCommittee() {
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No members added")),
      );
      return;
    }

    final shuffled = List<String>.from(members)..shuffle(Random());
    setState(() {
      committeeOrder = shuffled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Committee Management")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Set Money Limit"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _setMoneyLimit,
              child: Text("Set Limit"),
            ),
            Divider(height: 30),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Enter Member Name"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addMember,
              child: Text("Add Member"),
            ),
            Divider(height: 30),
            Text("Members (${members.length})", style: TextStyle(fontWeight: FontWeight.bold)),
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
            SizedBox(height: 10),
            Text("Total Committee Amount: Rs. $totalCommitteeAmount",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startCommittee,
              child: Text("Start Committee"),
            ),
            SizedBox(height: 10),
            if (committeeOrder.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Committee Order", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ...committeeOrder.asMap().entries.map((entry) {
                    int index = entry.key + 1;
                    return Text("$index. ${entry.value} receives the committee");
                  }).toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
