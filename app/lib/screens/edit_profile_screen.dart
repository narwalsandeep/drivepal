import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/auth_api.dart';
import '../services/auth_session.dart';
import '../theme/drivepal_tokens.dart';
import '../utils/profile_image_codec.dart';
import '../widgets/auth/drivepal_auth_tokens.dart';
import '../widgets/drivepal_shell_layout.dart';

/// Full-screen form: name, email, profile photo (API sync for text fields;
/// photo stored as compressed JPEG base64 in local user JSON).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;

  /// Set when the user picks a new image; `null` means “no new pick this session”.
  String? _newPhotoBase64;
  bool _removePhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthSession>().user;
    _firstNameCtrl = TextEditingController(
      text: u?['firstName'] as String? ?? '',
    );
    _lastNameCtrl = TextEditingController(
      text: u?['lastName'] as String? ?? '',
    );
    _emailCtrl = TextEditingController(text: u?['email'] as String? ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _displayPhotoBase64(AuthSession auth) {
    if (_removePhoto) return null;
    if (_newPhotoBase64 != null) return _newPhotoBase64;
    return auth.user?['profilePhotoBase64'] as String?;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;
    final raw = await x.readAsBytes();
    final b64 = compressProfilePhotoToJpegBase64(raw);
    if (!mounted) return;
    if (b64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not use this image — try another.'),
        ),
      );
      return;
    }
    setState(() {
      _newPhotoBase64 = b64;
      _removePhoto = false;
    });
  }

  void _showPhotoSheet(AuthSession auth) {
    final hadPhoto =
        !_removePhoto &&
        (_newPhotoBase64 != null ||
            (auth.user?['profilePhotoBase64'] as String?)?.isNotEmpty == true);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              drivepalModalBottomInset(ctx, extra: 8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.camera);
                  },
                ),
                if (hadPhoto)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: DrivepalTokens.textDanger,
                    ),
                    title: Text(
                      'Remove photo',
                      style: TextStyle(
                        color: DrivepalTokens.textDanger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _newPhotoBase64 = null;
                        _removePhoto = true;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save(AuthSession auth) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await auth.updateProfile(
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        email: _emailCtrl.text,
        clearProfilePhoto: _removePhoto,
        profilePhotoBase64: _newPhotoBase64,
      );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e is AuthApiException ? e.message : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final b64 = _displayPhotoBase64(auth);

    return Scaffold(
      backgroundColor: DrivepalTokens.bgScaffold,
      appBar: AppBar(
        title: const Text('Edit profile'),
        elevation: 0,
        backgroundColor: DrivepalTokens.bgScaffold,
        foregroundColor: DrivepalTokens.textHeading,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            DrivepalAuthTokens.pageGutter,
            8,
            DrivepalAuthTokens.pageGutter,
            32,
          ),
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => _showPhotoSheet(auth),
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            DrivepalTokens.bgPrimary,
                            DrivepalTokens.bgPrimaryHover,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(0, 8),
                            blurRadius: 20,
                            color: DrivepalTokens.bgPrimary.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: _AvatarPreview(
                          base64: b64,
                          fallbackInitials: _initialsFromUser(auth.user),
                          size: 106,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: 4,
                    child: Material(
                      color: DrivepalTokens.bgCard,
                      elevation: 3,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Change photo',
                        onPressed: () => _showPhotoSheet(auth),
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        color: DrivepalTokens.accentLink,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Profile photo is stored on this device with your session.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DrivepalTokens.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _firstNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'First name'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter your first name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Last name'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter your last name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your email';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : () => _save(auth),
              child:
                  _saving
                      ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  String _initialsFromUser(Map<String, dynamic>? u) {
    final first = u?['firstName'] as String? ?? '';
    final last = u?['lastName'] as String? ?? '';
    final email = u?['email'] as String? ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) return first[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({
    required this.base64,
    required this.fallbackInitials,
    required this.size,
  });

  final String? base64;
  final String fallbackInitials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b64 = base64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }
    return Container(
      width: size,
      height: size,
      color: DrivepalTokens.bgCard,
      alignment: Alignment.center,
      child: Text(
        fallbackInitials,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: DrivepalTokens.bgPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
