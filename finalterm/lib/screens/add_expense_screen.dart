import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final List<Map<String, dynamic>> members;
  final DocumentSnapshot? expenseDoc;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.members,
    this.expenseDoc,
  });

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _paidByMemberId;
  Set<String> _selectedMemberIds = {};
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    if (widget.expenseDoc != null) {
      final data = widget.expenseDoc!.data() as Map<String, dynamic>;
      _titleController.text = data['title'];
      _amountController.text = (data['amount'] as num).toString();
      _notesController.text = data['notes'] ?? '';
      _selectedDate = (data['date'] as Timestamp).toDate();
      _paidByMemberId = data['paidBy'] as String;
      _selectedMemberIds = widget.members.map((m) => m['id'] as String).toSet();
    } else {
      if (widget.members.isNotEmpty) {
        _paidByMemberId = _auth.currentUser?.uid;
      }
      _selectedMemberIds = widget.members.map((m) => m['id'] as String).toSet();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text.trim();
      final amount = double.tryParse(_amountController.text.trim());
      final notes = _notesController.text.trim();
      
      if (amount == null || _paidByMemberId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid amount or payer selected.')),
          );
        }
        return;
      }

      final selectedMembers = widget.members.where((m) => _selectedMemberIds.contains(m['id'])).toList();
      final totalMembers = selectedMembers.length;
      if (totalMembers == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one member to split with.')),
          );
        }
        return;
      }
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final groupDoc = await transaction.get(groupRef);
        if (!groupDoc.exists) {
          throw Exception("Group does not exist!");
        }
        
        final Map<String, dynamic> balances = Map<String, dynamic>.from(groupDoc.data()!['balances'] ?? {});

        if (widget.expenseDoc != null) {
          final oldData = widget.expenseDoc!.data() as Map<String, dynamic>;
          final oldAmount = (oldData['amount'] as num).toDouble();
          final oldPaidBy = oldData['paidBy'] as String;
          final oldSplitMembers = widget.members.map((m) => m['id'] as String).toList();
          final oldSplitAmount = oldAmount / oldSplitMembers.length;
          for (var memberId in oldSplitMembers) {
            final currentBalance = (balances[memberId] as num? ?? 0.0).toDouble();
            if (memberId == oldPaidBy) {
              balances[memberId] = currentBalance - (oldAmount - oldSplitAmount);
            } else {
              balances[memberId] = currentBalance + oldSplitAmount;
            }
          }
        }
        
        final newSplitAmount = amount / totalMembers;
        for (var member in selectedMembers) {
          final memberId = member['id'];
          final currentBalance = (balances[memberId] as num? ?? 0.0).toDouble();
          if (memberId == _paidByMemberId) {
            balances[memberId] = currentBalance + (amount - newSplitAmount);
          } else {
            balances[memberId] = currentBalance - newSplitAmount;
          }
        }
        
        transaction.update(groupRef, {'balances': balances});

        final expenseData = {
          'title': title,
          'amount': amount,
          'paidBy': _paidByMemberId,
          'paidByName': widget.members.firstWhere((m) => m['id'] == _paidByMemberId)['name'],
          'date': Timestamp.fromDate(_selectedDate),
          'notes': notes,
          'createdAt': widget.expenseDoc != null ? (widget.expenseDoc!.data() as Map<String,dynamic>)['createdAt'] : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'splitWith': _selectedMemberIds.toList(),
        };

        if (widget.expenseDoc != null) {
          transaction.update(widget.expenseDoc!.reference, expenseData);
        } else {
          transaction.set(groupRef.collection('expenses').doc(), expenseData);
        }
      });

      // Send notifications to other group members
      final currentUser = _auth.currentUser!;
      final currentUserName = widget.members.firstWhere((m) => m['id'] == currentUser.uid)['name'] ?? 'Someone';
      final groupDocData = await groupRef.get();
      final groupName = groupDocData.data()?['name'] ?? 'the group';
      final notificationMessage =
          "$currentUserName ${widget.expenseDoc != null ? 'updated an' : 'added a new'} expense '$title' for ${amount.toStringAsFixed(2)} in $groupName.";
      final batch = FirebaseFirestore.instance.batch();

      for (var member in widget.members) {
        if (member['id'] != currentUser.uid) {
          final notificationRef =
              FirebaseFirestore.instance.collection('notifications').doc();
          batch.set(notificationRef, {
            'recipientUid': member['id'],
            'message': notificationMessage,
            'groupId': widget.groupId,
            'groupName': groupName,
            'type': 'expense_${widget.expenseDoc != null ? 'updated' : 'added'}',
            'status': 'unread',
            'createdAt': FieldValue.serverTimestamp(),
            'senderUid': currentUser.uid,
          });
        }
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Expense ${widget.expenseDoc != null ? 'updated' : 'added'} successfully!')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF181818), Color(0xFF232526), Color(0xFF434343)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.expenseDoc == null ? 'Add Expense' : 'Edit Expense'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveExpense,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return 'Please enter an amount';
                    if (double.tryParse(value) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _paidByMemberId,
                  onChanged: (String? newValue) {
                    setState(() {
                      _paidByMemberId = newValue!;
                    });
                  },
                  items: widget.members.map<DropdownMenuItem<String>>((member) {
                    return DropdownMenuItem<String>(
                      value: member['id'],
                      child: Text(member['name'] ?? 'Unknown'),
                    );
                  }).toList(),
                  decoration: const InputDecoration(
                    labelText: 'Paid by',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF23272F),
                   style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Date: ${DateFormat.yMMMd().format(_selectedDate)}',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _selectDate(context),
                      child: const Text('Select Date'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Split with:', style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                Column(
                  children: widget.members.map((member) {
                    final memberId = member['id'];
                    return CheckboxListTile(
                      value: _selectedMemberIds.contains(memberId),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedMemberIds.add(memberId);
                          } else {
                            _selectedMemberIds.remove(memberId);
                          }
                        });
                      },
                      title: Text(
                        member['name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.green,
                      checkColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 