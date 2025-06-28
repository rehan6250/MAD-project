import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'manage_expenses_page.dart';

class ChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  const ChatPage({Key? key, required this.groupId, required this.groupName}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _messageController.text.trim().isEmpty) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final username = userDoc.data()?['username'] ?? user.email ?? 'Unknown';
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add({
      'text': _messageController.text.trim(),
      'senderUid': user.uid,
      'senderUsername': username,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _messageController.clear();
  }

  void _showGroupDetails() async {
    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
    final groupData = groupDoc.data() ?? {};
    final creatorUid = groupData['uid'];
    final description = groupData['description'] ?? 'No description provided.';
    final createdAt = groupData['createdAt'] != null && groupData['createdAt'] is Timestamp
        ? (groupData['createdAt'] as Timestamp).toDate()
        : null;
    // Get all member UIDs (admin + members array)
    final List<dynamic> membersArray = groupData['members'] ?? [];
    final Set<String> allUids = {creatorUid, ...membersArray.cast<String>()};
    // Fetch usernames for all UIDs
    final List<Map<String, dynamic>> members = [];
    for (final uid in allUids) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data();
      final username = (userData != null && userData['username'] is String && (userData['username'] as String).isNotEmpty)
          ? userData['username']
          : (userData != null && userData['email'] != null ? userData['email'] : 'Unknown');
      members.add({
        'uid': uid,
        'username': username,
        'isAdmin': uid == creatorUid,
      });
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                margin: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.deepPurple,
                        child: const Icon(Icons.group, size: 56, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        groupData['name'] ?? widget.groupName,
                        style: const TextStyle(fontSize: 28, color: Colors.black, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${members.length} members',
                        style: const TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Description', style: TextStyle(fontSize: 18, color: Colors.deepPurple, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(description, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                            if (createdAt != null) ...[
                              const SizedBox(height: 12),
                              Text('Created: ${createdAt.toLocal().toString().split(".")[0]}', style: const TextStyle(fontSize: 14, color: Colors.black45)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageExpensesPage(
                              groupId: widget.groupId,
                              groupName: groupData['name'] ?? widget.groupName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Manage Expenses'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _inviteUserByUsername(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Invite User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Members', style: TextStyle(fontSize: 20, color: Colors.deepPurple, fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.deepPurple, thickness: 1),
              ...members.map((member) => Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: member['isAdmin'] ? Colors.deepPurple : Colors.deepPurple.shade100,
                        child: member['isAdmin']
                            ? const Icon(Icons.verified, color: Colors.white)
                            : Text(
                                member['username'].toString().isNotEmpty ? member['username'][0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                              ),
                      ),
                      title: Text(member['username'], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                      trailing: member['isAdmin']
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.verified, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Admin', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            )
                          : null,
                    ),
                  )),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Leave Group'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _inviteUserByUsername(BuildContext context) async {
    final usernameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite User by Username'),
        content: TextField(
          controller: usernameController,
          decoration: const InputDecoration(hintText: 'Enter username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = usernameController.text.trim();
              if (username.isEmpty) return;
              // Find user by username
              final userQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('username', isEqualTo: username)
                  .limit(1)
                  .get();
              if (userQuery.docs.isEmpty) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User not found.')),
                );
                print('DEBUG: User not found for username: $username');
                return;
              }
              final invitedUser = userQuery.docs.first;
              final invitedUid = invitedUser.id;
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) {
                print('DEBUG: currentUser is null');
                return;
              }
              // Fetch group data to get the group name
              final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
              final groupData = groupDoc.data() ?? {};
              // Get current user's username for the notification
              final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
              final currentUsername = currentUserDoc.data()?['username'] ?? currentUser.email ?? 'Unknown';
              try {
                // Create invite in invited user's pendingInvites
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(invitedUid)
                    .collection('pendingInvites')
                    .add({
                  'groupId': widget.groupId,
                  'groupName': groupData['name'] ?? widget.groupName,
                  'invitedByUid': currentUser.uid,
                  'invitedByUsername': currentUsername,
                  'status': 'pending',
                  'timestamp': FieldValue.serverTimestamp(),
                });
                print('DEBUG: Invite created for $username ($invitedUid)');
              } catch (e) {
                print('ERROR: Failed to create invite: $e');
              }
              try {
                // Send notification to the invited user
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(invitedUid)
                    .collection('notifications')
                    .add({
                  'title': 'Group Invitation',
                  'message': '$currentUsername invited you to join "${groupData['name'] ?? widget.groupName}"',
                  'type': 'group_invite',
                  'groupId': widget.groupId,
                  'groupName': groupData['name'] ?? widget.groupName,
                  'createdByUid': currentUser.uid,
                  'createdByUsername': currentUsername,
                  'timestamp': FieldValue.serverTimestamp(),
                  'read': false,
                });
                print('DEBUG: Notification created for $username ($invitedUid)');
              } catch (e) {
                print('ERROR: Failed to create notification: $e');
              }
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invite sent to $username!')),
              );
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showGroupDetails,
            tooltip: 'Group Details',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data?.docs ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return ListTile(
                      leading: const Icon(Icons.account_circle, color: Colors.deepPurple),
                      title: Text(msg['senderUsername'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(msg['text'] ?? ''),
                      trailing: msg['senderUid'] == FirebaseAuth.instance.currentUser?.uid
                          ? const Icon(Icons.check, color: Colors.green, size: 16)
                          : null,
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
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _sending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 