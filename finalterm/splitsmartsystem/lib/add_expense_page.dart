import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddExpensePage extends StatefulWidget {
  final String groupId;
  final String groupName;
  const AddExpensePage({Key? key, required this.groupId, required this.groupName}) : super(key: key);

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _paidByUid;
  List<Map<String, dynamic>> _members = [];
  List<String> _selectedSplitUids = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
    final creatorUid = groupDoc.data()?['uid'];
    final List<dynamic> membersArray = groupDoc.data()?['members'] ?? [];
    final Set<String> allUids = {creatorUid, ...membersArray.cast<String>()};
    final List<Map<String, dynamic>> members = [];
    for (final uid in allUids) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data();
      final username = (userData != null && userData['username'] is String && (userData['username'] as String).isNotEmpty)
          ? userData['username']
          : (userData != null && userData['email'] != null ? userData['email'] : 'Unknown');
      members.add({'uid': uid, 'username': username});
    }
    setState(() {
      _members = members;
      _paidByUid = creatorUid;
      _selectedSplitUids = allUids.toList(); // By default, all selected
    });
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate() || _paidByUid == null || _selectedSplitUids.isEmpty) return;
    setState(() => _saving = true);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final perMember = amount / _selectedSplitUids.length;
    final paidByUsername = _members.firstWhere((m) => m['uid'] == _paidByUid)['username'];
    final splitWithUids = _selectedSplitUids;
    final splitWithUsernames = _members
        .where((m) => splitWithUids.contains(m['uid']))
        .map((m) => m['username'])
        .toList();
    // Save the expense
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .add({
      'title': _titleController.text.trim(),
      'amount': amount,
      'paidByUid': _paidByUid,
      'paidByUsername': paidByUsername,
      'date': Timestamp.fromDate(_selectedDate),
      'notes': _notesController.text.trim(),
      'splitWithUids': splitWithUids,
      'splitWithUsernames': splitWithUsernames,
      'perMemberShare': perMember,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Send notifications to all group members
    await _notifyGroupMembers(
      widget.groupId,
      'New Expense Added',
      '${paidByUsername} added "${_titleController.text.trim()}" for \$${amount.toStringAsFixed(2)}',
      'expense_added',
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _notifyGroupMembers(String groupId, String title, String message, String type) async {
    try {
      // Get all group members
      final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
      final groupData = groupDoc.data() ?? {};
      final creatorUid = groupData['uid'];
      final members = groupData['members'] as List<dynamic>? ?? [];
      
      // Add creator to members list if not already included
      final allMemberUids = <String>{creatorUid, ...members.cast<String>()};
      
      // Get current user info for the notification
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).get();
      final currentUsername = currentUserDoc.data()?['username'] ?? currentUser?.email ?? 'Unknown';

      // Create notifications for all members (except the current user)
      final batch = FirebaseFirestore.instance.batch();
      for (final memberUid in allMemberUids) {
        if (memberUid != currentUser?.uid) {
          final notificationRef = FirebaseFirestore.instance
              .collection('users')
              .doc(memberUid)
              .collection('notifications')
              .doc();
          
          batch.set(notificationRef, {
            'title': title,
            'message': message,
            'type': type,
            'groupId': groupId,
            'groupName': widget.groupName,
            'createdByUid': currentUser?.uid,
            'createdByUsername': currentUsername,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }
      await batch.commit();
    } catch (e) {
      print('Error sending notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saving ? null : _saveExpense,
          ),
        ],
      ),
      body: _members.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (v) => v == null || v.isEmpty ? 'Enter a title' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? 'Enter an amount' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _paidByUid,
                      items: _members
                          .map<DropdownMenuItem<String>>((m) => DropdownMenuItem<String>(
                                value: m['uid'] as String,
                                child: Text(m['username']),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _paidByUid = v),
                      decoration: const InputDecoration(labelText: 'Paid by'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Date: ${_selectedDate.toLocal().toString().split(" ")[0]}'),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _selectedDate = picked);
                          },
                          child: const Text('Select Date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    const Text('Split with:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._members.map((m) => CheckboxListTile(
                          value: _selectedSplitUids.contains(m['uid']),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedSplitUids.add(m['uid']);
                              } else {
                                _selectedSplitUids.remove(m['uid']);
                              }
                            });
                          },
                          title: Text(m['username']),
                        )),
                  ],
                ),
              ),
            ),
    );
  }
} 