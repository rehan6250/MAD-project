import 'package:finalterm/screens/add_expense_screen.dart';
import 'package:finalterm/screens/group_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _markAsRead();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _markAsRead() {
    if (_auth.currentUser == null) return;
    _firestore.collection('groups').doc(widget.groupId).update({
      'lastRead.${_auth.currentUser!.uid}': FieldValue.serverTimestamp(),
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _auth.currentUser == null) return;

    final user = _auth.currentUser!;
    final message = _messageController.text.trim();
    _messageController.clear();

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final username = userDoc.data()?['username'] ?? user.email ?? 'Anonymous';

    final messageData = {
      'text': message,
      'senderId': user.uid,
      'senderName': username,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add(messageData);

    await _firestore.collection('groups').doc(widget.groupId).update({
      'lastMessage': message,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': user.uid,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailsScreen(groupId: widget.groupId),
              ),
            );
          },
          child: Text(widget.groupName),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chat'),
            Tab(text: 'Details'),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF181A20),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatSection(),
          _buildDetailsSection(),
        ],
      ),
    );
  }

  Widget _buildChatSection() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('groups')
                .doc(widget.groupId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No messages yet.', style: TextStyle(color: Colors.white54)));
              }
              final messages = snapshot.data!.docs;
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index].data() as Map<String, dynamic>;
                  final isMe = message['senderId'] == _auth.currentUser!.uid;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.green.shade700 : Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          _buildSenderName(message['senderId']),
                          const SizedBox(height: 4),
                          Text(
                            message['text'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                mini: true,
                onPressed: _sendMessage,
                backgroundColor: Colors.green,
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final groupData = snapshot.data!.data() as Map<String, dynamic>;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummarySection(groupData),
              const SizedBox(height: 24),
              const Text(
                'Balances',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Divider(color: Colors.white24),
              _buildBalancesList(groupData),
              const SizedBox(height: 24),
              const Text(
                'Expenses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Divider(color: Colors.white24),
              _buildExpensesList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummarySection(Map<String, dynamic> groupData) {
    return FutureBuilder<QuerySnapshot>(
      future: _firestore.collection('groups').doc(widget.groupId).collection('expenses').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        double totalExpenses = 0;
        for (var doc in snapshot.data!.docs) {
          totalExpenses += (doc.data() as Map<String, dynamic>)['amount'] as num;
        }
        
        final userBalance = (groupData['balances'] as Map<String, dynamic>?)?[_auth.currentUser!.uid] as num? ?? 0.0;
        final totalMembers = (groupData['members'] as List<dynamic>?)?.length ?? 1;
        final yourShare = totalMembers > 0 ? totalExpenses / totalMembers : 0.0;

        return Card(
          color: Colors.grey[800],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSummaryRow('Total Group Expenses:', totalExpenses.toStringAsFixed(2)),
                const Divider(color: Colors.white24),
                _buildSummaryRow('Your Total Share:', yourShare.toStringAsFixed(2)),
                const Divider(color: Colors.white24),
                _buildSummaryRow('Your Final Balance:', userBalance.toStringAsFixed(2), isPositive: userBalance >= 0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String title, String value, {bool? isPositive}) {
    Color valueColor = Colors.white;
    if (isPositive != null) {
      valueColor = isPositive ? Colors.green : Colors.red;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSenderName(String senderId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(senderId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final username = userData?['username'] ?? userData?['email'] ?? 'User';
          return Text(
            username,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              fontSize: 12,
            ),
          );
        }
        return const SizedBox(
          height: 14,
          width: 60,
          child: LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildBalancesList(Map<String, dynamic> groupData) {
    final balances = (groupData['balances'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, (value as num).toDouble())) ??
        {};
    final members = List<String>.from(groupData['members'] ?? []);

    if (members.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text('No members to show balances for.',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: members.isNotEmpty ? members : ['dummy'])
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final memberDocs = snapshot.data!.docs;
        final memberNames = {
          for (var doc in memberDocs)
            doc.id: (doc.data() as Map<String, dynamic>)['username'] ?? 'User'
        };

        final transactions = _calculateSettlements(balances);

        if (transactions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Text('All settled up!',
                  style: TextStyle(color: Colors.green, fontSize: 16)),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final trans = transactions[index];
            final fromName = memberNames[trans.from] ?? 'Someone';
            final toName = memberNames[trans.to] ?? 'Someone';

            return ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.white70),
              title: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  children: [
                    TextSpan(
                        text: fromName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const TextSpan(text: ' owes '),
                    TextSpan(
                        text: toName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  ],
                ),
              ),
              trailing: Text(
                '${trans.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            );
          },
        );
      },
    );
  }

  List<_Transaction> _calculateSettlements(Map<String, double> balances) {
    var debtors = <String, double>{};
    var creditors = <String, double>{};

    balances.forEach((key, value) {
      if (value > 0) {
        creditors[key] = value;
      } else if (value < 0) {
        debtors[key] = value.abs();
      }
    });

    final transactions = <_Transaction>[];

    var sortedDebtors = debtors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var sortedCreditors = creditors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int debtorIndex = 0;
    int creditorIndex = 0;

    while (debtorIndex < sortedDebtors.length && creditorIndex < sortedCreditors.length) {
      final debtor = sortedDebtors[debtorIndex];
      final creditor = sortedCreditors[creditorIndex];

      final amount = debtor.value < creditor.value ? debtor.value : creditor.value;

      if (amount > 0.01) { // Threshold to avoid tiny transactions
        transactions.add(_Transaction(debtor.key, creditor.key, amount));

        sortedDebtors[debtorIndex] = MapEntry(debtor.key, debtor.value - amount);
        sortedCreditors[creditorIndex] = MapEntry(creditor.key, creditor.value - amount);
      }

      if (sortedDebtors[debtorIndex].value < 0.01) {
        debtorIndex++;
      }
      if (sortedCreditors[creditorIndex].value < 0.01) {
        creditorIndex++;
      }
    }
    return transactions;
  }

  void _editExpense(DocumentSnapshot expenseDoc, List<Map<String, dynamic>> members) {
    // Navigate to AddExpenseScreen with existing data
  }

  Future<void> _deleteExpense(DocumentSnapshot expenseDoc) async {
    // Show confirmation and delete logic
  }

  Widget _buildExpensesList() {
    return StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, groupSnapshot) {
          if (!groupSnapshot.hasData) return const SizedBox.shrink();
          final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
          final adminUid = groupData['createdBy'] as String?;
          final currentUserId = _auth.currentUser?.uid;

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('groups')
                .doc(widget.groupId)
                .collection('expenses')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text('No expenses recorded yet.',
                        style: TextStyle(color: Colors.white54)),
                  ),
                );
              }
              final expenseDocs = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: expenseDocs.length,
                itemBuilder: (context, index) {
                  final expenseDoc = expenseDocs[index];
                  final expenseData = expenseDoc.data() as Map<String, dynamic>;
                  final amount = (expenseData['amount'] as num).toDouble();
                  final date = (expenseData['date'] as Timestamp).toDate();
                  final addedBy = expenseData['paidBy'] as String?;

                  final canModify = currentUserId == adminUid || currentUserId == addedBy;

                  return ListTile(
                    title: Text(expenseData['title'] ?? 'Expense',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Paid by ${expenseData['paidByName'] ?? 'Someone'} on ${DateFormat.yMMMd().format(date)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        if (canModify)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            onSelected: (value) {
                              if (value == 'edit') {
                                // _editExpense(expenseDoc, groupData['members']);
                              } else if (value == 'delete') {
                                _deleteExpense(expenseDoc);
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        });
  }
}

class _Transaction {
  final String from;
  final String to;
  final double amount;

  _Transaction(this.from, this.to, this.amount);
} 