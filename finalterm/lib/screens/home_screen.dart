import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:finalterm/screens/notifications_screen.dart';
import 'package:finalterm/screens/group_chat_screen.dart';
import 'dart:async';
import '../../main.dart';

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
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF181A20) : Colors.white,
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
                          icon: Icon(Icons.arrow_back, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text('Profile', style: TextStyle(fontSize: 24, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                        Spacer(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.person, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                      title: Text('Name', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
                      subtitle: Text(username, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 18)),
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
                            // Duplicate username check
                            final existing = await _firestore.collection('users')
                              .where('username', isEqualTo: result)
                              .get();
                            if (existing.docs.isNotEmpty && existing.docs.first.id != _auth.currentUser!.uid) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('This username is already taken. Please choose another.')),
                              );
                            } else {
                              await _firestore.collection('users').doc(_auth.currentUser!.uid).update({'username': result});
                              setState(() {});
                              Navigator.pop(context);
                              _showProfileScreen();
                            }
                          }
                        },
                        child: const Text('Edit', style: TextStyle(color: Colors.green)),
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    ListTile(
                      leading: Icon(Icons.info_outline, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                      title: Text('About', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
                      subtitle: Text(about, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 16)),
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
                      leading: Icon(Icons.logout, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                      title: Text('Logout', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
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

    // Sort by lastMessageAt descending (latest chat on top)
    filteredGroups.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTime = aData['lastMessageAt'] as Timestamp?;
      final bTime = bData['lastMessageAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime); // descending order
    });

    if (filteredGroups.isEmpty) {
      return Center(child: Text('No groups found.', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
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

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return GestureDetector(
          onTap: () async {
            try {
              await _firestore.collection('groups').doc(group.id).update({
                'lastRead.${_auth.currentUser!.uid}': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              // Ignore error, proceed to navigation
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupChatScreen(groupId: group.id, groupName: groupName),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: groupProfilePic != null && groupProfilePic.isNotEmpty ? NetworkImage(groupProfilePic) : null,
                      child: groupProfilePic == null || groupProfilePic.isEmpty ? Icon(Icons.group, color: isDark ? Colors.white : Colors.black, size: 32) : null,
                      backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    ),
                    if (isUnread)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  groupName,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Color(0xFF181818), Color(0xFF232526), Color(0xFF434343)]
              : [Color(0xFFF5F5F5), Color(0xFFE0E0E0), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('splittsmart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.greenAccent)),
          backgroundColor: isDark ? Color(0xFF181A20) : Color(0xFFe0ffe0),
          elevation: 4,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              color: isDark ? Colors.white : Colors.black,
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
                  hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                  prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.black54),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
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
                    return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No groups yet. Create one!', style: TextStyle(color: isDark ? Colors.white : Colors.black)));
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
      ),
    );
  }
} 