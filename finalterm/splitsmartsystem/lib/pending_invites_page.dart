import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingInvitesPage extends StatelessWidget {
  const PendingInvitesPage({Key? key}) : super(key: key);

  Future<void> _acceptInvite(BuildContext context, String inviteId, Map<String, dynamic> invite) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Add user to group members (for now, add to a 'members' array in group doc)
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(invite['groupId']);
    await groupRef.set({
      'members': FieldValue.arrayUnion([user.uid])
    }, SetOptions(merge: true));
    
    // Mark invite as accepted (or delete)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('pendingInvites')
        .doc(inviteId)
        .delete();
    
    // Send notifications to existing group members
    await _notifyGroupMembers(
      invite['groupId'],
      'New Member Joined',
      '${user.displayName ?? user.email ?? 'Unknown'} joined ${invite['groupName'] ?? 'the group'}',
      'member_joined',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined group!')));
  }

  Future<void> _rejectInvite(BuildContext context, String inviteId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('pendingInvites')
        .doc(inviteId)
        .delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite rejected.')));
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
            'groupName': groupData['name'] ?? 'Group',
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Invites')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('pendingInvites')
            .where('status', isEqualTo: 'pending')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final invites = snapshot.data?.docs ?? [];
          if (invites.isEmpty) {
            return const Center(child: Text('No pending invites.'));
          }
          return ListView.builder(
            itemCount: invites.length,
            itemBuilder: (context, index) {
              final invite = invites[index].data() as Map<String, dynamic>;
              final inviteId = invites[index].id;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(invite['groupName'] ?? 'Group', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Invited by: ${invite['invitedByUsername'] ?? 'Unknown'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        tooltip: 'Accept',
                        onPressed: () => _acceptInvite(context, inviteId, invite),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Reject',
                        onPressed: () => _rejectInvite(context, inviteId),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 