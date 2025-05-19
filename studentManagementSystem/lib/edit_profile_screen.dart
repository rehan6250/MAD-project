import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  final int userId;
  const EditProfileScreen({super.key, required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String email = '';
  bool isLoading = true;
  String? errorMsg;
  String? profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final db = await DBHelper().db;
    final res = await db.query('users', where: 'id = ?', whereArgs: [widget.userId]);
    if (res.isNotEmpty) {
      setState(() {
        name = res.first['name']?.toString() ?? '';
        email = res.first['email']?.toString() ?? '';
        profileImagePath = res.first['profile_image']?.toString();
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
        errorMsg = 'User not found';
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        profileImagePath = pickedFile.path;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final db = await DBHelper().db;
    try {
      await db.update(
        'users',
        {'name': name, 'email': email, 'profile_image': profileImagePath},
        where: 'id = ?',
        whereArgs: [widget.userId],
      );
      if (mounted) {
        Navigator.pop(context, {'name': name, 'email': email, 'profile_image': profileImagePath});
      }
    } catch (e) {
      setState(() => errorMsg = 'Email already exists');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundImage: (profileImagePath != null && profileImagePath!.isNotEmpty)
                                ? FileImage(File(profileImagePath!))
                                : null,
                            child: (profileImagePath == null || profileImagePath!.isEmpty)
                                ? const Icon(Icons.person, size: 48)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      initialValue: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      onChanged: (v) => name = v,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      onChanged: (v) => email = v,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    if (errorMsg != null)
                      Text(errorMsg!, style: const TextStyle(color: Colors.red)),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 