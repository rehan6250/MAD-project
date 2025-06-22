import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:finalterm/screens/notifications_screen.dart';
import 'package:finalterm/screens/group_chat_screen.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final depositController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            TextField(
              controller: depositController,
              decoration: const InputDecoration(labelText: 'Initial Deposit (Optional)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final groupName = nameController.text.trim();
              if (groupName.isNotEmpty) {
                Navigator.of(context).pop({
                  'name': groupName,
                  'deposit': depositController.text.trim(),
                });
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      final groupName = result['name']!;
      final depositString = result['deposit']!;
      final initialDeposit = double.tryParse(depositString) ?? 0.0;
      final currentUserId = _auth.currentUser!.uid;

      final groupRef = _firestore.collection('groups').doc();
      final groupData = {
        'name': groupName,
        'createdBy': currentUserId,
        'admin': currentUserId,
        'createdAt': Timestamp.now(),
        'members': [currentUserId],
        'balances': {
          currentUserId: initialDeposit,
        }
      };
      
      await groupRef.set(groupData);

      final userRef = _firestore.collection('users').doc(currentUserId);
      await userRef.update({
        'groups': FieldValue.arrayUnion([groupRef.id])
      });

      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$groupName" created!')),
        );
      }
    }
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    final uid = _auth.currentUser!.uid;
    final ref = FirebaseStorage.instance.ref().child('profile_pics/$uid.jpg');
    await ref.putData(await picked.readAsBytes());
    final url = await ref.getDownloadURL();
    await _firestore.collection('users').doc(uid).update({'picUrl': url});
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
    }
  }

  void _showProfileScreen() async {
    final userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
    final user = userDoc.data();
    final username = user != null ? user['username'] as String? ?? '' : '';
    final about = user != null ? user['about'] as String? ?? '' : '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181A20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Text('Profile', style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.white),
                      title: const Text('Name', style: TextStyle(color: Colors.white70)),
                      subtitle: Text(username, style: const TextStyle(color: Colors.white, fontSize: 18)),
                      trailing: TextButton(
                        onPressed: () async {
                          final controller = TextEditingController(text: username);
                          final result = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Change Username'),
                              content: TextField(
                                controller: controller,
                                decoration: const InputDecoration(labelText: 'New Username'),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Change')),
                              ],
                            ),
                          );
                          if (result != null && result.isNotEmpty) {
                            await _firestore.collection('users').doc(_auth.currentUser!.uid).update({'username': result});
                            setState(() {});
                            Navigator.pop(context);
                            _showProfileScreen();
                          }
                        },
                        child: const Text('Edit', style: TextStyle(color: Colors.green)),
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.white),
                      title: const Text('About', style: TextStyle(color: Colors.white70)),
                      subtitle: Text(about, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      trailing: TextButton(
                        onPressed: () async {
                          final controller = TextEditingController(text: about);
                          final result = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Change About'),
                              content: TextField(
                                controller: controller,
                                decoration: const InputDecoration(labelText: 'About'),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Change')),
                              ],
                            ),
                          );
                          if (result != null) {
                            await _firestore.collection('users').doc(_auth.currentUser!.uid).update({'about': result});
                            setState(() {});
                            Navigator.pop(context);
                            _showProfileScreen();
                          }
                        },
                        child: const Text('Edit', style: TextStyle(color: Colors.green)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.white),
                      title: const Text('Logout', style: TextStyle(color: Colors.white)),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _auth.signOut();
                          Navigator.pop(context);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Account'),
                            content: const Text('Are you sure you want to delete your account? This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final uid = _auth.currentUser!.uid;
                          await _firestore.collection('users').doc(uid).delete();
                          await _auth.currentUser!.delete();
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showGroupDetailsDialog(Map<String, dynamic> group) async {
    final groupId = group['id'];
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    final groupData = groupDoc.data() ?? {};
    final members = List<String>.from(groupData['members'] ?? []);
    final admin = groupData['admin'] ?? '';
    final usersSnap = await _firestore.collection('users').where(FieldPath.documentId, whereIn: members.isEmpty ? ['dummy'] : members).get();
    final users = {for (var doc in usersSnap.docs) doc.id: doc.data()};
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(groupData['name'] ?? groupId),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Members:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...members.map((uid) => ListTile(
                leading: Icon(uid == admin ? Icons.admin_panel_settings : Icons.person),
                title: Text(users[uid]?['username'] ?? users[uid]?['email'] ?? uid),
                subtitle: uid == admin ? const Text('Admin') : null,
              )),
              if (_auth.currentUser!.uid == admin)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Invite User'),
                    onPressed: () async {
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
                        // Find user by username or email
                        final userQuery = await _firestore.collection('users')
                          .where('username', isEqualTo: result)
                          .get();
                        var userId;
                        if (userQuery.docs.isNotEmpty) {
                          userId = userQuery.docs.first.id;
                        } else {
                          final emailQuery = await _firestore.collection('users')
                            .where('email', isEqualTo: result)
                            .get();
                          if (emailQuery.docs.isNotEmpty) {
                            userId = emailQuery.docs.first.id;
                          }
                        }
                        if (userId != null) {
                          await _firestore.collection('groups').doc(groupId).update({
                            'members': FieldValue.arrayUnion([userId])
                          });
                          await _firestore.collection('users').doc(userId).set({
                            'groups': FieldValue.arrayUnion([groupId])
                          }, SetOptions(merge: true));
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User invited!')));
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found.')));
                          }
                        }
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Stream<int> _unreadNotificationsCountStream() {
    late StreamController<int> controller;
    StreamSubscription? sub1;
    StreamSubscription? sub2;

    int invitesCount = 0;
    int notifsCount = 0;

    void update() {
      controller.add(invitesCount + notifsCount);
    }

    controller = StreamController<int>(
      onListen: () {
        sub1 = _firestore
            .collection('invitations')
            .where('targetUid', isEqualTo: _auth.currentUser!.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen((snapshot) {
          invitesCount = snapshot.docs.length;
          update();
        });

        sub2 = _firestore
            .collection('notifications')
            .where('recipientUid', isEqualTo: _auth.currentUser!.uid)
            .where('status', isEqualTo: 'unread')
            .snapshots()
            .listen((snapshot) {
          notifsCount = snapshot.docs.length;
          update();
        });
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
      },
    );

    return controller.stream;
  }

  Widget _buildGroupList(List<QueryDocumentSnapshot> groupDocs) {
    final filteredGroups = groupDocs.where((doc) {
      final groupName = (doc.data() as Map<String, dynamic>)['name']?.toString().toLowerCase() ?? '';
      return groupName.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredGroups.isEmpty) {
      return const Center(child: Text('No groups found.', style: TextStyle(color: Colors.white)));
    }

    return ListView.builder(
      itemCount: filteredGroups.length,
      itemBuilder: (context, index) {
        final group = filteredGroups[index];
        final groupData = group.data() as Map<String, dynamic>;
        final groupName = groupData['name'] ?? 'No Name';
        final groupProfilePic = groupData['groupProfilePic'] as String?;

        final lastMessageAt = groupData['lastMessageAt'] as Timestamp?;
        final lastMessageSenderId = groupData['lastMessageSenderId'] as String?;
        final lastReadData = groupData['lastRead'] as Map<String, dynamic>?;
        final lastReadForUser = lastReadData?[_auth.currentUser!.uid] as Timestamp?;

        bool isUnread = false;
        if (lastMessageAt != null &&
            lastMessageSenderId != null &&
            lastMessageSenderId != _auth.currentUser!.uid) {
          if (lastReadForUser == null || lastMessageAt.compareTo(lastReadForUser) > 0) {
            isUnread = true;
          }
        }

        return ListTile(
          leading: CircleAvatar(
            radius: 25,
            backgroundImage: groupProfilePic != null && groupProfilePic.isNotEmpty ? NetworkImage(groupProfilePic) : null,
            child: groupProfilePic == null || groupProfilePic.isEmpty ? const Icon(Icons.group, color: Colors.white) : null,
            backgroundColor: Colors.grey[700],
          ),
          title: Text(groupName, style: const TextStyle(color: Colors.white)),
          trailing: isUnread
              ? const Text(
                  'Unread msg',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                )
              : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupChatScreen(groupId: group.id, groupName: groupName),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        title: const Text('splittsmart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showProfileScreen,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('groups').where('members', arrayContains: _auth.currentUser?.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No groups yet. Create one!', style: TextStyle(color: Colors.white)));
                }
                return _buildGroupList(snapshot.data!.docs);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'notifications',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                );
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              heroTag: 'add_group',
              onPressed: () => _showCreateGroupDialog(context),
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
} 