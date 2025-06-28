import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  Future<void> _markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final notifications = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
    
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  void _navigateToGroup(BuildContext context, String groupId, String groupName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(groupId: groupId, groupName: groupName),
      ),
    );
  }

  Future<void> _handleGroupInvite(String notificationId, Map<String, dynamic> notification, bool accept, BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final groupId = notification['groupId'];
    final groupName = notification['groupName'];
    final inviterUid = notification['createdByUid'];
    final inviterUsername = notification['createdByUsername'];
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final username = userDoc.data()?['username'] ?? user.email ?? 'Unknown';
    if (accept) {
      // Add user to group members
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      await groupRef.set({
        'members': FieldValue.arrayUnion([user.uid])
      }, SetOptions(merge: true));
      // Send notification to inviter
      if (inviterUid != null && inviterUid != user.uid) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(inviterUid)
            .collection('notifications')
            .add({
          'title': 'Invite Accepted',
          'message': '$username joined your group "$groupName"',
          'type': 'invite_accepted',
          'groupId': groupId,
          'groupName': groupName,
          'createdByUid': user.uid,
          'createdByUsername': username,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You joined the group!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite declined.')));
    }
    // Mark notification as read
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final notifications = snapshot.data?.docs ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              final notificationId = notifications[index].id;
              final isRead = notification['read'] ?? false;
              final timestamp = notification['timestamp'] as Timestamp?;
              final timeAgo = timestamp != null 
                  ? _getTimeAgo(timestamp.toDate())
                  : 'Unknown time';

              final isGroupInvite = notification['type'] == 'group_invite';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: isRead ? Colors.white : (isGroupInvite ? Colors.blue.shade50 : Colors.white),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getNotificationColor(notification['type']),
                    child: Icon(
                      _getNotificationIcon(notification['type']),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    notification['title'] ?? 'Notification',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification['message'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (isGroupInvite && !isRead)
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _handleGroupInvite(notificationId, notification, true, context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Accept'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => _handleGroupInvite(notificationId, notification, false, context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Decline'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  trailing: !isGroupInvite
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'read') {
                              _markAsRead(notificationId);
                            } else if (value == 'group' && notification['groupId'] != null) {
                              _navigateToGroup(
                                context,
                                notification['groupId'],
                                notification['groupName'] ?? 'Group',
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            if (!isRead)
                              const PopupMenuItem(
                                value: 'read',
                                child: Row(
                                  children: [
                                    Icon(Icons.check, size: 16),
                                    SizedBox(width: 8),
                                    Text('Mark as read'),
                                  ],
                                ),
                              ),
                            if (notification['groupId'] != null)
                              const PopupMenuItem(
                                value: 'group',
                                child: Row(
                                  children: [
                                    Icon(Icons.group, size: 16),
                                    SizedBox(width: 8),
                                    Text('Go to group'),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : null,
                  onTap: () {
                    if (!isRead && !isGroupInvite) {
                      _markAsRead(notificationId);
                    }
                    if (notification['groupId'] != null && !isGroupInvite) {
                      _navigateToGroup(
                        context,
                        notification['groupId'],
                        notification['groupName'] ?? 'Group',
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'expense_added':
        return Colors.green;
      case 'member_joined':
        return Colors.blue;
      case 'group_invite':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'expense_added':
        return Icons.receipt;
      case 'member_joined':
        return Icons.person_add;
      case 'group_invite':
        return Icons.group_add;
      default:
        return Icons.notifications;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
} 