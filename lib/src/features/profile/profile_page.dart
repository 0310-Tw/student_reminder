import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:students_reminder/src/features/auth/login_page.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/user_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _onLogout(BuildContext context) async {
    try {
      //Confirm first
      final safeToLogout = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Yes'),
            ),
          ],
        ),
      );
      if (safeToLogout != true) return;
      await AuthService.instance.logout();
      MaterialPageRoute(builder: (_) => const LoginPage());
      // if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login Failed: $e')));
      }
    }
  }

  //Update Profile
  Future<void> _updateProfile() async {
    setState(() => _busy = true);
    try {
      final uid = AuthService.instance.currentUser!.uid;
      await UserService.instance.updateMyProfile(
        uid,
        phone: _phone.text.trim(),
        bio: _bio.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Profile updated!')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  //Upload/Select image
  Future<void> _onPickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final uid = AuthService.instance.currentUser!.uid;
    await UserService.instance.uploadProfilePhoto(
      uid: uid,
      file: File(file.path),
    );
  }

  final _bio = TextEditingController();
  final _phone = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  String? _photoUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser!.uid;
    UserService.instance.getUser(uid).listen((doc) {
      final data = doc.data();
      if (data != null && mounted) {
        _firstName.text = (data['firstName'] ?? '') as String;
        _lastName.text = (data['lastName'] ?? '') as String;
        _bio.text = (data['bio'] ?? '') as String;
        _phone.text = (data['phone'] ?? '') as String;
        setState(() => _photoUrl = data['photoUrl'] as String?);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile'),
        actions: [
          IconButton(
            onPressed: () => _onLogout(context),
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: _photoUrl != null
                ? NetworkImage(_photoUrl!)
                : null,
            child: _photoUrl == null ? Icon(Icons.person, size: 30) : null,
          ),
          TextButton.icon(
            icon: Icon(Icons.camera_alt),
            onPressed: _onPickPhoto,
            label: Text('Change Image'),
          ),
          SizedBox(height: 12),
          Text('Name: ${_firstName.text} ${_lastName.text} (set on register)'),
          Text('Name: ${user.email}'),
          SizedBox(height: 12),
          TextField(
            controller: _phone,
            decoration: InputDecoration(labelText: 'Phone #'),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _bio,
            decoration: InputDecoration(labelText: 'Bio'),
          ),
          SizedBox(height: 14),
          ElevatedButton(
            onPressed: _busy ? null : _updateProfile,
            child: _busy ? CircularProgressIndicator() : Text('Save/Update'),
          ),
          SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              await AuthService.instance.sendPasswordReset(user.email!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password reset email sent!')),
                );
              }
            },
            child: Text('Send Password reset email'),
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              await AuthService.instance.logout();
            },
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}
