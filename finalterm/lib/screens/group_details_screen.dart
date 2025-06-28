import 'package:finalterm/screens/add_expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  _GroupDetailsScreenState createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _navigateToAddExpense(BuildContext context, List<String> memberUids) async {
    if (memberUids.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot add expense without members.'))
        );
      }
      return;
    }
    final membersSnapshot = await _firestore.collection('users').where(FieldPath.documentId, whereIn: memberUids).get();
    final membersData = membersSnapshot.docs.map((doc) {
      final data = doc.data();
      return {'id': doc.id, 'name': data['username'] ?? data['email'] ?? 'Unknown'};
    }).toList();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddExpenseScreen(groupId: widget.groupId, members: membersData),
        ),
      );
    }
  }

  Future<void> _inviteUser(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite User'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Username or Email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Invite')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Searching for user...')));
      
      QuerySnapshot userQuery;
      if (result.contains('@')) {
        userQuery = await _firestore.collection('users').where('email', isEqualTo: result).get();
      } else {
        userQuery = await _firestore.collection('users').where('username', isEqualTo: result).get();
      }

      if (userQuery.docs.isNotEmpty) {
        final targetUserDoc = userQuery.docs.first;
        final inviterDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
        final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();

        await _firestore.collection('invitations').add({
          'type': 'group_invite',
          'groupId': widget.groupId,
          'groupName': groupDoc.data()?['name'] ?? 'a group',
          'targetUid': targetUserDoc.id,
          'senderUid': _auth.currentUser!.uid,
          'invitedByUsername': inviterDoc.data()?['username'] ?? _auth.currentUser!.email,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation sent!')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found.')));
        }
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
          title: const Text('Group Info'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final groupData = snapshot.data!.data() as Map<String, dynamic>;
            final groupName = groupData['name'] ?? 'Group';
            final groupDescription = groupData['description'] ?? 'No description provided.';
            final members = List<String>.from(groupData['members'] ?? []);
            final adminUid = groupData['createdBy'] ?? '';
            final isAdmin = adminUid == _auth.currentUser?.uid;
            final isMember = members.contains(_auth.currentUser?.uid);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: groupData['groupProfilePic'] != null ? NetworkImage(groupData['groupProfilePic']) : null,
                      child: groupData['groupProfilePic'] == null ? const Icon(Icons.group, size: 50) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      groupName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${members.length} members',
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Description', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    groupDescription,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: (isAdmin || isMember) ? () => _navigateToAddExpense(context, members) : null,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Manage Expenses'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _inviteUser(context),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Invite User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Members',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Divider(color: Colors.white24),
                  _buildMembersList(members, adminUid),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _leaveGroup(context),
                    icon: const Icon(Icons.exit_to_app, color: Colors.white),
                    label: const Text('Leave Group'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _leaveGroup(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF23272F),
        title: const Text('Leave Group', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to leave this group?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final String currentUserId = _auth.currentUser!.uid;

      await _firestore.collection('groups').doc(widget.groupId).update({
        'members': FieldValue.arrayRemove([currentUserId])
      });

      // Also remove the group from the user's own list for data consistency
      await _firestore.collection('users').doc(currentUserId).update({
        'groups': FieldValue.arrayRemove([widget.groupId])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the group')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Widget _buildMembersList(List<String> memberUids, String adminUid) {
    if (memberUids.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('No members found.', style: TextStyle(color: Colors.white54)),
      );
    }
    
    return FutureBuilder<QuerySnapshot>(
      future: _firestore.collection('users').where(FieldPath.documentId, whereIn: memberUids).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final memberDocs = snapshot.data!.docs;
        // Sort so that admin is first
        memberDocs.sort((a, b) {
          if (a.id == adminUid) return -1;
          if (b.id == adminUid) return 1;
          return 0;
        });
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: memberDocs.length,
          itemBuilder: (context, index) {
            final memberData = memberDocs[index].data() as Map<String, dynamic>;
            final memberUid = memberDocs[index].id;
            final memberName = memberData['username'] ?? memberData['email'] ?? 'Unknown User';
            final bool isAdmin = memberUid == adminUid;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: memberData['picUrl'] != null ? NetworkImage(memberData['picUrl']) : null,
                child: memberData['picUrl'] == null ? const Icon(Icons.person) : null,
              ),
              title: Text(memberName, style: const TextStyle(color: Colors.white)),
              trailing: isAdmin
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
} 