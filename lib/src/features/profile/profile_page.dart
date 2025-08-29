import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:students_reminder/src/features/auth/login_page.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/user_service.dart';
import 'package:students_reminder/src/shared/misc.dart';

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
        displaySnackBar(context, 'Error logging out: $e');
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
        displaySnackBar(context, 'Profile updated!');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  //Upload/Select image
  Future<void> _onPickPhoto() async {
    setState(() => _busy = true);
    try {
      // Request permissions
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (mounted) {
          displaySnackBar(context, 'Photo permission is required to select images');
        }
        setState(() => _busy = false);
        return;
      }

      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (file == null) {
        setState(() => _busy = false);
        return;
      }

      // Load image data for cropping
      final imageBytes = await file.readAsBytes();
      setState(() {
        _imageData = imageBytes;
        _busy = false;
      });

      // Show cropping dialog
      _showCropDialog();
    } catch (e) {
     
      if (mounted) {
        displaySnackBar(context, 'Error picking image: $e');
      }
      setState(() => _busy = false);
    }
  }

  void _showCropDialog() {
    if (_imageData == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Container(
          height: 400,
          width: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Crop Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Crop(
                  image: _imageData!,
                  controller: _cropController,
                  onCropped: (croppedData) {
                    Navigator.of(context).pop();
                    _uploadCroppedImage(croppedData);
                  },
                  aspectRatio: 1.0, // Square aspect ratio
                  baseColor: Colors.blue.shade50,
                  maskColor: Colors.black.withOpacity(0.5),
                  radius: 0,
                  interactive: true,
                  fixCropRect: false,
                  cornerDotBuilder: (size, edgeAlignment) => const DotControl(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() => _imageData = null);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => _cropController.crop(),
                    child: const Text('Crop'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadCroppedImage(dynamic croppedData) async {
    setState(() => _busy = true);
    try {
      Uint8List imageBytes;
      if (croppedData is Uint8List) {
        imageBytes = croppedData;
      } else {
        // In crop_your_image 2.0.0, the correct property is 'croppedImage'
        try {
          final dynamic cropResult = croppedData;

          // Try the correct property name for crop_your_image v2.0.0
          try {
            imageBytes = cropResult.croppedImage as Uint8List;
          } catch (e1) {
            // Fallback: try other possible property names
            try {
              imageBytes = cropResult.bytes as Uint8List;
            } catch (e2) {
              try {
                imageBytes = cropResult.data as Uint8List;
              } catch (e3) {
                // Try direct casting as last resort
                try {
                  imageBytes = cropResult as Uint8List;
                } catch (castError) {
                  throw Exception(
                    'Could not extract image bytes from CropSuccess object. Tried: croppedImage, bytes, data, direct casting',
                  );
                }
              }
            }
          }
        } catch (extractionError) {
          rethrow;
        }
      }

      // Create a temporary file from the cropped data
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/cropped_profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(imageBytes);

      final uid = AuthService.instance.currentUser!.uid;
      await UserService.instance.uploadProfilePhoto(uid: uid, file: tempFile);

      // Clean up the temporary file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (mounted) {
        displaySnackBar(context, 'Profile photo updated!');
      }

      setState(() => _imageData = null);
    } catch (e) {
      displaySnackBar(context, 'Error uploading cropped image: $e');
      if (mounted) {
        displaySnackBar(context, 'Error updating photo: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  final _bio = TextEditingController();
  final _phone = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  String? _photoUrl;
  bool _busy = false;

  // Cropping state variables
  Uint8List? _imageData;
  final _cropController = CropController();

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
          // Circular profile image with proper aspect ratio
          Center(
            child: Container(
              width: 160,
              height: 160,
              child: AspectRatio(
                aspectRatio: 1.0, // Square aspect ratio for circular display
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _busy
                        ? Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _photoUrl != null
                        ? Image.network(
                            _photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: Icon(Icons.camera_alt),
            onPressed: _busy ? null : _onPickPhoto,
            label: Text(_busy ? 'Uploading...' : 'Change Image'),
          ),
          SizedBox(height: 12),
          Text('Name: ${_firstName.text} ${_lastName.text} '),
          Text('Email: ${user.email}'),
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
                displaySnackBar(context, 'Password reset email sent!');
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
