import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../theme/drivepal_tokens.dart';
import '../../utils/profile_image_codec.dart';

class DriverOnboardingScreen extends StatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  static const int _maxDriverDocumentBytes = 8 * 1024 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  final _addressCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _visaCtrl = TextEditingController();
  String _gender = 'prefer_not_to_say';
  String? _profilePhotoBase64;
  String? _dlPhotoBase64;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthSession>().user;
    _firstNameCtrl = TextEditingController(
      text: (user?['firstName'] as String? ?? '').trim(),
    );
    _lastNameCtrl = TextEditingController(
      text: (user?['lastName'] as String? ?? '').trim(),
    );
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _locationCtrl.dispose();
    _ageCtrl.dispose();
    _visaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool forDl}) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;
    final raw = await x.readAsBytes();
    if (!mounted) return;
    if (raw.lengthInBytes > _maxDriverDocumentBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image is too large. Maximum allowed size is 8 GB.'),
        ),
      );
      return;
    }
    final b64 = encodeRawImageToBase64(raw);
    setState(() {
      if (forDl) {
        _dlPhotoBase64 = b64;
      } else {
        _profilePhotoBase64 = b64;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profilePhotoBase64 == null || _dlPhotoBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload both profile and licence photos.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final session = context.read<AuthSession>();
      final user = session.user;
      final email = (user?['email'] as String? ?? '').trim();
      if (email.isNotEmpty) {
        await session.updateProfile(
          firstName: _firstNameCtrl.text,
          lastName: _lastNameCtrl.text,
          email: email,
        );
      }
      await session.updateDriverProfile(
        driverProfilePhotoBase64: _profilePhotoBase64!,
        driverAddress: _addressCtrl.text,
        driverLocationText: _locationCtrl.text,
        driverAge: int.parse(_ageCtrl.text.trim()),
        driverGender: _gender,
        driverVisaStatus: _visaCtrl.text,
        driverDlImageBase64: _dlPhotoBase64!,
      );
      if (!mounted) return;
      context.go('/driver/new');
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver profile wizard')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Complete your driver profile to start accepting rides.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: DrivepalTokens.textMuted),
            ),
            const SizedBox(height: 16),
            _UploadTile(
              title: 'Profile photo',
              hasValue: _profilePhotoBase64 != null,
              onTap: () => _pickImage(forDl: false),
            ),
            const SizedBox(height: 10),
            _UploadTile(
              title: 'Driving licence photo',
              hasValue: _dlPhotoBase64 != null,
              onTap: () => _pickImage(forDl: true),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _firstNameCtrl,
              decoration: const InputDecoration(labelText: 'First name'),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'First name is required'
                          : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _lastNameCtrl,
              decoration: const InputDecoration(labelText: 'Last name'),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Last name is required'
                          : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Address is required'
                          : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location / city',
                hintText: 'Example: London, UK',
              ),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Location is required'
                          : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
              validator: (v) {
                final age = int.tryParse((v ?? '').trim());
                if (age == null) return 'Enter valid age';
                if (age < 18 || age > 90) return 'Age must be 18-90';
                return null;
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
                DropdownMenuItem(
                  value: 'prefer_not_to_say',
                  child: Text('Prefer not to say'),
                ),
              ],
              onChanged: (v) => setState(() => _gender = v ?? _gender),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _visaCtrl,
              decoration: const InputDecoration(
                labelText: 'Visa status',
                hintText: 'Citizen / Work permit / ILR ...',
              ),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Visa status is required'
                          : null,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving...' : 'Complete profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.title,
    required this.hasValue,
    required this.onTap,
  });

  final String title;
  final bool hasValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
      ),
      title: Text(title),
      subtitle: Text(hasValue ? 'Uploaded' : 'Tap to upload'),
      trailing: Icon(
        hasValue ? Icons.check_circle_rounded : Icons.upload_file_rounded,
        color: hasValue ? Colors.green : null,
      ),
      onTap: onTap,
    );
  }
}
