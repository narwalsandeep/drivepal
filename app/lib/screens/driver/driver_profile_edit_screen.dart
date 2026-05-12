import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../theme/drivepal_tokens.dart';
import '../../utils/profile_image_codec.dart';
import '../../widgets/drivepal_tab_page_chrome.dart';

class DriverProfileEditScreen extends StatefulWidget {
  const DriverProfileEditScreen({super.key});

  @override
  State<DriverProfileEditScreen> createState() => _DriverProfileEditScreenState();
}

class _DriverProfileEditScreenState extends State<DriverProfileEditScreen> {
  static const int _maxDriverDocumentBytes = 8 * 1024 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _visaCtrl;
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
    _addressCtrl = TextEditingController(
      text: (user?['driverAddress'] as String? ?? '').trim(),
    );
    _locationCtrl = TextEditingController(
      text: (user?['driverLocationText'] as String? ?? '').trim(),
    );
    _ageCtrl = TextEditingController(
      text: ((user?['driverAge'] as num?)?.toInt() ?? 0).toString(),
    );
    if (_ageCtrl.text == '0') {
      _ageCtrl.clear();
    }
    _visaCtrl = TextEditingController(
      text: (user?['driverVisaStatus'] as String? ?? '').trim(),
    );
    final existingGender = (user?['driverGender'] as String?)?.trim();
    if (existingGender != null &&
        const {'male', 'female', 'other', 'prefer_not_to_say'}.contains(
          existingGender,
        )) {
      _gender = existingGender;
    }
    _profilePhotoBase64 = user?['driverProfilePhotoBase64'] as String?;
    _dlPhotoBase64 = user?['driverDlImageBase64'] as String?;
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
      maxWidth: 4096,
      maxHeight: 4096,
      imageQuality: 95,
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
          content: Text('Profile photo and driving licence image are required.'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver profile updated. Documents are pending approval.'),
        ),
      );
      context.pop();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return DrivepalTokens.locationDropoff;
      case 'rejected':
        return DrivepalTokens.textDanger;
      default:
        return DrivepalTokens.bgPrimaryHover;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().user;
    final status = (user?['driverDocumentStatus'] as String?) ?? 'pending';
    final statusColor = _statusColor(status);

    return Scaffold(
      appBar: AppBar(title: const Text('Driver profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            DrivepalElevatedPanel(
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Document verification: ${_statusLabel(status)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _UploadTile(
              title: 'Driver profile photo',
              hasValue: _profilePhotoBase64 != null,
              subtitle: 'Image up to 8 GB, any image type.',
              onTap: () => _pickImage(forDl: false),
            ),
            const SizedBox(height: 10),
            _UploadTile(
              title: 'Driving licence image',
              hasValue: _dlPhotoBase64 != null,
              subtitle: 'Image up to 8 GB, any image type.',
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
              child: Text(_saving ? 'Saving...' : 'Save profile'),
            ),
          ],
        ),
      ),
      backgroundColor: DrivepalTokens.bgScaffold,
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.title,
    required this.subtitle,
    required this.hasValue,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
      subtitle: Text(hasValue ? 'Uploaded • $subtitle' : subtitle),
      trailing: Icon(
        hasValue ? Icons.check_circle_rounded : Icons.upload_file_rounded,
        color: hasValue ? DrivepalTokens.locationDropoff : null,
      ),
      onTap: onTap,
    );
  }
}
