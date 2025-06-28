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
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildChatSection(),
            _buildDetailsSection(),
          ],
        ),
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
              _buildExpenseHistoryTable(),
              const SizedBox(height: 24),
              _buildSettleUpSection(groupData),
              const SizedBox(height: 24),
              _buildSettleUpHistorySection(),
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
          Flexible(
            flex: 2,
            child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.visible),
            ),
          ),
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

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final trans = transactions[index];
            final fromName = memberNames[trans.from] ?? 'Someone';
            final toName = memberNames[trans.to] ?? 'Someone';

            return Card(
              color: Colors.grey[900]?.withOpacity(0.85),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_circle, color: Colors.redAccent, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        fromName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text('will give', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Text(
                        trans.amount.toStringAsFixed(2),
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text('to', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      const Icon(Icons.account_circle, color: Colors.greenAccent, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        toName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 16),
                      ),
                    ],
                  ),
                ),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          groupId: widget.groupId,
          members: members,
          expenseDoc: expenseDoc,
        ),
      ),
    );
  }

  Future<void> _deleteExpense(DocumentSnapshot expenseDoc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // --- Update balances before deleting expense ---
      final expenseData = expenseDoc.data() as Map<String, dynamic>;
      final groupRef = _firestore.collection('groups').doc(widget.groupId);
      final groupSnapshot = await groupRef.get();
      final groupData = groupSnapshot.data() as Map<String, dynamic>;
      final balances = Map<String, dynamic>.from(groupData['balances'] ?? {});
      final members = List<String>.from(groupData['members'] ?? []);
      final totalMembers = members.length;

      final amount = (expenseData['amount'] as num).toDouble();
      final paidBy = expenseData['paidBy'] as String;
      final isSplit = expenseData['isSplit'] ?? true;
      final oldSplitAmount = isSplit ? (amount / totalMembers) : 0.0;

      // Reverse the effect of this expense on balances
      for (var memberId in members) {
        final currentBalance = (balances[memberId] as num? ?? 0.0).toDouble();
        if (memberId == paidBy) {
          balances[memberId] = currentBalance - (amount - oldSplitAmount);
        } else {
          balances[memberId] = currentBalance + oldSplitAmount;
        }
      }
      await groupRef.update({'balances': balances});
      // --- End update balances ---

      // --- Send delete notification to all group members ---
      final currentUser = _auth.currentUser!;
      final currentUserName = groupData['membersData'] != null && groupData['membersData'][currentUser.uid] != null
          ? groupData['membersData'][currentUser.uid]['username'] ?? 'Someone'
          : currentUser.email ?? 'Someone';
      final groupName = groupData['name'] ?? 'the group';
      final notificationMessage = "$currentUserName deleted expense '${expenseData['title'] ?? 'Expense'}' in $groupName.";
      final batch = _firestore.batch();
      for (var memberId in members) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'recipientUid': memberId,
          'message': notificationMessage,
          'groupId': widget.groupId,
          'groupName': groupName,
          'type': 'expense_deleted',
          'status': 'unread',
          'createdAt': FieldValue.serverTimestamp(),
          'senderUid': currentUser.uid,
        });
      }
      await batch.commit();
      // --- End notification ---

      await expenseDoc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully!')),
        );
      }
    }
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
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: expenseDocs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final expenseDoc = expenseDocs[index];
                  final expenseData = expenseDoc.data() as Map<String, dynamic>;
                  final amount = (expenseData['amount'] as num).toDouble();
                  final date = (expenseData['date'] as Timestamp).toDate();
                  final addedBy = expenseData['paidBy'] as String?;

                  final canModify = currentUserId == adminUid || currentUserId == addedBy;

                  return Card(
                    color: Colors.grey[900]?.withOpacity(0.85),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.receipt_long, color: Colors.amber, size: 28),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    expenseData['title'] ?? 'Expense',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Paid by ${expenseData['paidByName'] ?? 'Someone'}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                Text(
                                  DateFormat.yMMMd().format(date),
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  '${amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (canModify) ...[
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    final membersUids = List<String>.from(groupData['members'] ?? []);
                                    final membersSnapshot = await _firestore.collection('users').where(FieldPath.documentId, whereIn: membersUids).get();
                                    final membersData = membersSnapshot.docs.map((doc) {
                                      final data = doc.data();
                                      return {'id': doc.id, 'name': data['username'] ?? data['email'] ?? 'Unknown'};
                                    }).toList();
                                    _editExpense(expenseDoc, membersData);
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
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        });
  }

  Widget _buildExpenseHistoryTable() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
      builder: (context, groupSnapshot) {
        if (!groupSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
        final members = List<String>.from(groupData['members'] ?? []);
        return FutureBuilder<QuerySnapshot>(
          future: _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: members.isNotEmpty ? members : ['dummy'])
              .get(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            final memberDocs = userSnapshot.data!.docs;
            final memberNames = {
              for (var doc in memberDocs)
                doc.id: (doc.data() as Map<String, dynamic>)['username'] ?? 'User'
            };
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('expenses')
                  .orderBy('date', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: Text('No expense history yet.', style: TextStyle(color: Colors.white54))),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text('Expense History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const Divider(color: Colors.white24),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.grey[850]),
                        dataRowColor: MaterialStateProperty.all(Colors.grey[900]?.withOpacity(0.85)),
                        columnSpacing: 18,
                        columns: const [
                          DataColumn(label: Text('Title', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Paid By', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Split With', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ],
                        rows: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final title = data['title'] ?? 'Expense';
                          final amount = (data['amount'] as num?)?.toStringAsFixed(2) ?? '-';
                          final paidBy = data['paidByName'] ?? 'Someone';
                          final date = (data['date'] as Timestamp?)?.toDate();
                          final splitWith = (data['splitWith'] as List?)?.cast<String>() ?? [];
                          final splitAmount = (data['amount'] as num?) != null && splitWith.isNotEmpty
                              ? (data['amount'] as num) / splitWith.length
                              : null;
                          final splitWithDisplay = splitWith.isNotEmpty
                              ? splitWith.map((id) =>
                                  '${memberNames[id] ?? id} (${splitAmount != null ? splitAmount.toStringAsFixed(2) : '-'})'
                                ).join(', ')
                              : 'All members';
                          return DataRow(
                            cells: [
                              DataCell(Text(title, style: const TextStyle(color: Colors.white))),
                              DataCell(Text(amount, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                              DataCell(Text(paidBy, style: const TextStyle(color: Colors.white70))),
                              DataCell(Text(
                                date != null ?
                                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' :
                                  '-',
                                style: const TextStyle(color: Colors.white38),
                              )),
                              DataCell(
                                Text(
                                  splitWithDisplay,
                                  style: const TextStyle(color: Colors.white60),
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSettleUpSection(Map<String, dynamic> groupData) {
    final balances = (groupData['balances'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, (value as num).toDouble())) ??
        {};
    final members = List<String>.from(groupData['members'] ?? []);
    final currentUserId = _auth.currentUser?.uid;
    if (members.isEmpty || currentUserId == null) return const SizedBox.shrink();

    final transactions = _calculateSettlements(balances);
    final myDebts = transactions.where((t) => t.from == currentUserId).toList();
    if (myDebts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Settle Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const Divider(color: Colors.white24),
        ...myDebts.map((t) => Card(
              color: Colors.green[900]?.withOpacity(0.85),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'You owe ${t.amount.toStringAsFixed(2)} to ${t.to}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        // Settle up: update balances
                        final balances = Map<String, dynamic>.from(groupData['balances'] ?? {});
                        balances[t.from] = (balances[t.from] as num? ?? 0.0) + t.amount;
                        balances[t.to] = (balances[t.to] as num? ?? 0.0) - t.amount;
                        await _firestore.collection('groups').doc(widget.groupId).update({'balances': balances});
                        // Record settlement in Firestore
                        await _firestore.collection('groups').doc(widget.groupId).collection('settlements').add({
                          'from': t.from,
                          'to': t.to,
                          'amount': t.amount,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settlement recorded!')),
                          );
                        }
                      },
                      child: const Text('Settle Up', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildSettleUpHistorySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('settlements')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final settlements = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settle Up History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(color: Colors.white24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey[850]),
                dataRowColor: MaterialStateProperty.all(Colors.grey[900]?.withOpacity(0.85)),
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('From', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('To', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
                rows: settlements.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final from = data['from'] ?? '';
                  final to = data['to'] ?? '';
                  final amount = (data['amount'] as num?)?.toStringAsFixed(2) ?? '-';
                  final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                  return DataRow(cells: [
                    DataCell(Text(from, style: const TextStyle(color: Colors.white))),
                    DataCell(Text(to, style: const TextStyle(color: Colors.white))),
                    DataCell(Text(amount, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                    DataCell(Text(
                      timestamp != null ?
                        '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}' :
                        '-',
                      style: const TextStyle(color: Colors.white38),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Transaction {
  final String from;
  final String to;
  final double amount;

  _Transaction(this.from, this.to, this.amount);
} 