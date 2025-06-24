import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _invitationsStream() {
    return _firestore
        .collection('invitations')
        .where('targetUid', isEqualTo: _auth.currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot> _notificationsStream() {
    return _firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: _auth.currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _markAllAsRead() async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: _auth.currentUser!.uid)
        .where('status', isEqualTo: 'unread')
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'read'});
    }
    await batch.commit();
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
          title: const Text('All Notifications'),
          backgroundColor: const Color(0xFF181A20),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInvitationsSection(),
              _buildOtherNotificationsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _invitationsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final invitations = snapshot.data!.docs;
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pending Invitations', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invitations.length,
                itemBuilder: (context, index) {
                  final doc = invitations[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final invitedBy = data['invitedByUsername'] ?? 'Someone';
                  final groupName = data['groupName'] ?? 'a group';
                  return Card(
                    color: Colors.grey[800],
                    child: ListTile(
                      title: Text('$invitedBy invited you to join $groupName', style: const TextStyle(color: Colors.white)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final groupId = data['groupId'] as String;
                              final groupName = data['groupName'] as String;
                              final currentUser = _auth.currentUser!;

                              final groupRef = _firestore.collection('groups').doc(groupId);
                              final groupDoc = await groupRef.get();
                              final existingMembers = List<String>.from(groupDoc.data()?['members'] ?? []);

                              await groupRef.update({
                                'members': FieldValue.arrayUnion([currentUser.uid])
                              });
                              await _firestore.collection('users').doc(currentUser.uid).set({
                                'groups': FieldValue.arrayUnion([groupId])
                              }, SetOptions(merge: true));
                              await _firestore.collection('invitations').doc(doc.id).update({'status': 'accepted'});
                              
                              final currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
                              final newMemberName = currentUserDoc.data()?['username'] ?? currentUser.email ?? 'A new user';
                              final notificationMessage = "$newMemberName has joined the group '$groupName'.";
                              
                              final batch = _firestore.batch();
                              for (final memberId in existingMembers) {
                                if (memberId != currentUser.uid) {
                                  final notificationRef = _firestore.collection('notifications').doc();
                                  batch.set(notificationRef, {
                                    'recipientUid': memberId,
                                    'message': notificationMessage,
                                    'groupId': groupId,
                                    'groupName': groupName,
                                    'type': 'user_joined',
                                    'status': 'unread',
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'senderUid': currentUser.uid,
                                  });
                                }
                              }
                              await batch.commit();
                            },
                            child: const Text('Join', style: TextStyle(color: Colors.green)),
                          ),
                          TextButton(
                            onPressed: () async {
                              await _firestore.collection('invitations').doc(doc.id).update({'status': 'declined'});
                            },
                            child: const Text('Decline', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOtherNotificationsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _notificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No notifications yet.', style: TextStyle(color: Colors.white70))),
          );
        }
        final notifications = snapshot.data!.docs;
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Other Notifications', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: const Text('Mark all as read', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final doc = notifications[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isUnread = data['status'] == 'unread';
                  String typeLabel = '';
                  switch (data['type']) {
                    case 'expense_added':
                    case 'expense_add':
                      typeLabel = 'Expense Added';
                      break;
                    case 'expense_updated':
                      typeLabel = 'Expense Updated';
                      break;
                    case 'expense_deleted':
                    case 'expense_remove':
                      typeLabel = 'Expense Deleted';
                      break;
                    case 'user_invited':
                    case 'invite':
                      typeLabel = 'Invitation';
                      break;
                    case 'user_joined':
                      typeLabel = 'User Joined';
                      break;
                    default:
                      typeLabel = 'Notification';
                  }
                  return ListTile(
                    tileColor: isUnread ? Colors.blueGrey.withOpacity(0.2) : null,
                    leading: Icon(isUnread ? Icons.notifications_active : Icons.notifications_none, color: Colors.white),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(typeLabel, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(data['message'] ?? 'No message content', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    subtitle: Text(
                      (data['createdAt'] as Timestamp).toDate().toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    trailing: isUnread
                        ? IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              await _firestore.collection('notifications').doc(doc.id).update({'status': 'read'});
                            },
                          )
                        : null,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
} 