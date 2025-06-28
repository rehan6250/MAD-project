import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_expense_page.dart';

class ManageExpensesPage extends StatelessWidget {
  final String groupId;
  final String groupName;
  const ManageExpensesPage({Key? key, required this.groupId, required this.groupName}) : super(key: key);

  void _showExpenseDetails(BuildContext context, Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(expense['title'] ?? 'Expense Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ₹${expense['amount'] ?? ''}'),
            const SizedBox(height: 8),
            Text('Paid by: ${expense['paidByUsername'] ?? ''}'),
            const SizedBox(height: 8),
            if (expense['date'] != null && expense['date'] is Timestamp)
              Text('Date: ${(expense['date'] as Timestamp).toDate().toLocal().toString().split(" ")[0]}'),
            const SizedBox(height: 8),
            Text('Split with: ${(expense['splitWithUsernames'] as List<dynamic>?)?.join(", ") ?? ''}'),
            const SizedBox(height: 8),
            if ((expense['notes'] ?? '').toString().isNotEmpty)
              Text('Notes: ${expense['notes']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Map<String, double> _calculateBalances(List<QueryDocumentSnapshot> expenses) {
    // Map of uid to balance
    final Map<String, double> balances = {};
    for (var doc in expenses) {
      final data = doc.data() as Map<String, dynamic>;
      final double amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final String paidByUid = data['paidByUid'] ?? '';
      final List splitWithUids = data['splitWithUids'] ?? [];
      final double perMember = amount / (splitWithUids.length == 0 ? 1 : splitWithUids.length);
      // Add to payer
      balances[paidByUid] = (balances[paidByUid] ?? 0) + amount - perMember;
      // Subtract from each member (except payer)
      for (var uid in splitWithUids) {
        if (uid == paidByUid) continue;
        balances[uid] = (balances[uid] ?? 0) - perMember;
      }
    }
    return balances;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses - $groupName'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('expenses')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final expenses = snapshot.data?.docs ?? [];
          double total = 0;
          for (var doc in expenses) {
            final amt = double.tryParse(doc['amount']?.toString() ?? '0') ?? 0;
            total += amt;
          }

          // Calculate balances
          final balances = _calculateBalances(expenses);

          // Get all members from expenses
          final Set<String> allUids = {};
          final Map<String, String> uidToName = {};
          for (var doc in expenses) {
            final data = doc.data() as Map<String, dynamic>;
            final List splitWithUids = data['splitWithUids'] ?? [];
            final List splitWithUsernames = data['splitWithUsernames'] ?? [];
            for (int i = 0; i < splitWithUids.length; i++) {
              allUids.add(splitWithUids[i]);
              if (i < splitWithUsernames.length && (splitWithUsernames[i] as String).isNotEmpty) {
                uidToName[splitWithUids[i]] = splitWithUsernames[i];
              }
            }
            final paidByUid = data['paidByUid'];
            final paidByUsername = data['paidByUsername'];
            final paidByEmail = data['paidByEmail'];
            if (paidByUid != null) {
              if (paidByUsername != null && (paidByUsername as String).isNotEmpty) {
                uidToName[paidByUid] = paidByUsername;
              } else if (paidByEmail != null) {
                uidToName[paidByUid] = paidByEmail;
              }
              allUids.add(paidByUid);
            }
          }

          // Individual share (total / members)
          final individualShare = allUids.isNotEmpty ? total / allUids.length : 0;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Spent:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Flexible(
                          child: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Individual Share:', style: TextStyle(fontSize: 16)),
                        Flexible(
                          child: Text('₹${individualShare.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Balances:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ...allUids.map((uid) {
                      final name = uidToName[uid] ?? uid;
                      final bal = balances[uid] ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text(name, style: const TextStyle(fontSize: 15))),
                          Flexible(
                            child: Text(
                              bal > 0
                                  ? 'Gets ₹${bal.toStringAsFixed(2)}'
                                  : bal < 0
                                      ? 'Owes ₹${(-bal).toStringAsFixed(2)}'
                                      : 'Settled',
                              style: TextStyle(
                                color: bal > 0
                                    ? Colors.green
                                    : bal < 0
                                        ? Colors.red
                                        : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.visible,
                              softWrap: true,
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
                    const Text('Borrows:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ..._buildBorrows(balances, uidToName),
                    const SizedBox(height: 16),
                    if (_hasBorrows(balances))
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Settle Up'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _showSettleUpDialog(context, balances, uidToName),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Expense History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Expanded(
                child: expenses.isEmpty
                    ? const Center(child: Text('No expenses yet.'))
                    : ListView.builder(
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final exp = expenses[index].data() as Map<String, dynamic>;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text(exp['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Amount: ₹${exp['amount'] ?? ''}'),
                                  Text('Paid by: ${exp['paidByUsername'] ?? ''}'),
                                  if (exp['date'] != null && exp['date'] is Timestamp)
                                    Text('Date: ${(exp['date'] as Timestamp).toDate().toLocal().toString().split(" ")[0]}'),
                                  Text('Split with: ${(exp['splitWithUsernames'] as List<dynamic>?)?.join(", ") ?? ''}'),
                                ],
                              ),
                              onTap: () => _showExpenseDetails(context, exp),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpensePage(
                groupId: groupId,
                groupName: groupName,
              ),
            ),
          );
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
        tooltip: 'Add Expense',
      ),
    );
  }

  List<Widget> _buildBorrows(Map<String, double> balances, Map<String, String> uidToName) {
    // Simple greedy algorithm for debts
    final List<MapEntry<String, double>> owes = balances.entries.where((e) => e.value < 0).toList();
    final List<MapEntry<String, double>> gets = balances.entries.where((e) => e.value > 0).toList();
    final List<Widget> borrows = [];
    int i = 0, j = 0;
    while (i < owes.length && j < gets.length) {
      final owe = owes[i];
      final get = gets[j];
      final amount = owe.value.abs() < get.value ? owe.value.abs() : get.value;
      borrows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '${uidToName[owe.key] ?? owe.key} has to pay ₹${amount.toStringAsFixed(2)} to ${uidToName[get.key] ?? get.key}',
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ),
        ],
      ));
      owes[i] = MapEntry(owe.key, owe.value + amount);
      gets[j] = MapEntry(get.key, get.value - amount);
      if (owes[i].value.abs() < 0.01) i++;
      if (gets[j].value < 0.01) j++;
    }
    if (borrows.isEmpty) {
      borrows.add(const Text('All settled!', style: TextStyle(color: Colors.green)));
    }
    return borrows;
  }

  bool _hasBorrows(Map<String, double> balances) {
    return balances.values.any((v) => v.abs() > 0.01);
  }

  void _showSettleUpDialog(BuildContext context, Map<String, double> balances, Map<String, String> uidToName) {
    final owes = balances.entries.where((e) => e.value < -0.01).toList();
    final gets = balances.entries.where((e) => e.value > 0.01).toList();
    if (owes.isEmpty || gets.isEmpty) return;

    String payer = owes.first.key;
    String receiver = gets.first.key;
    String settleType = 'full'; // default to full
    double maxAmount = 0;
    double halfAmount = 0;

    double getMaxAmount(String payer, String receiver) {
      final oweEntry = owes.firstWhere((e) => e.key == payer, orElse: () => owes.first);
      final getEntry = gets.firstWhere((e) => e.key == receiver, orElse: () => gets.first);
      return oweEntry.value.abs() < getEntry.value ? oweEntry.value.abs() : getEntry.value;
    }

    final amountController = TextEditingController();

    void updateAmounts() {
      maxAmount = getMaxAmount(payer, receiver);
      halfAmount = maxAmount / 2;
      amountController.text = settleType == 'full'
          ? maxAmount.toStringAsFixed(2)
          : halfAmount.toStringAsFixed(2);
    }

    updateAmounts(); // initialize

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('Settle Up', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Payer', style: TextStyle(fontWeight: FontWeight.w600))),
                DropdownButtonFormField<String>(
                  value: payer,
                  items: owes.map((e) {
                    final name = uidToName[e.key] ?? e.key;
                    return DropdownMenuItem(value: e.key, child: Text(name));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        payer = v;
                        updateAmounts();
                      });
                    }
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Receiver', style: TextStyle(fontWeight: FontWeight.w600))),
                DropdownButtonFormField<String>(
                  value: receiver,
                  items: gets.map((e) {
                    final name = uidToName[e.key] ?? e.key;
                    return DropdownMenuItem(value: e.key, child: Text(name));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        receiver = v;
                        updateAmounts();
                      });
                    }
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 20),
                RadioListTile<String>(
                  value: 'full',
                  groupValue: settleType,
                  title: const Text('Full Amount'),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        settleType = v;
                        updateAmounts();
                      });
                    }
                  },
                ),
                RadioListTile<String>(
                  value: 'half',
                  groupValue: settleType,
                  title: const Text('Half Amount'),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        settleType = v;
                        updateAmounts();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Amount to Settle', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                TextFormField(
                  controller: amountController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final double amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) return;

                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .collection('expenses')
                    .add({
                  'title': 'Settlement',
                  'amount': amount,
                  'paidByUid': payer,
                  'paidByUsername': uidToName[payer] ?? payer,
                  'date': Timestamp.now(),
                  'notes':
                      'Settlement between ${uidToName[payer] ?? payer} and ${uidToName[receiver] ?? receiver}',
                  'splitWithUids': [payer, receiver],
                  'splitWithUsernames': [uidToName[payer] ?? payer, uidToName[receiver] ?? receiver],
                  'perMemberShare': amount / 2,
                  'createdAt': FieldValue.serverTimestamp(),
                  'type': 'settlement',
                });

                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: const Text('Settle'),
            ),
          ],
        ),
      ),
    );
  }
} 