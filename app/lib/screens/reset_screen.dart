import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_api.dart';
import '../widgets/auth/drivepal_auth.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/drivepal_soft_frame.dart';

class ResetScreen extends StatefulWidget {
  const ResetScreen({super.key, required this.kid, required this.code});

  final String kid;
  final String code;

  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  final _api = AuthApi();
  final _password = TextEditingController();
  final _focusPassword = FocusNode();
  bool _loading = false;
  String _loadingMessage = '';
  String? _error;
  String? _info;

  @override
  void dispose() {
    _password.dispose();
    _focusPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.kid.isEmpty || widget.code.isEmpty) return;
    final pwd = _password.text;
    if (pwd.length < 8 || pwd.length > 128) {
      setState(() {
        _error = 'Password must be 8–128 characters.';
      });
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
      _loadingMessage = 'Updating password…';
    });
    try {
      await _api.post('/reset-password', {
        'kid': widget.kid,
        'code': widget.code,
        'newPassword': pwd,
      });
      setState(() {
        _info = 'Password updated. Sign in with your phone.';
        _loading = false;
        _loadingMessage = '';
      });
    } on AuthApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
        _loadingMessage = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final invalid = widget.kid.isEmpty || widget.code.isEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AuthLoadingOverlay(
        visible: _loading,
        message: _loadingMessage.isEmpty ? 'Please wait…' : _loadingMessage,
        child: DrivepalAuthPage(
          showBackBrandLabel: false,
          pageTitle: DrivepalAuthCopy.resetPageTitle,
          pageSubtitle: DrivepalAuthCopy.resetPageSubtitle,
          outerPadding: DrivepalAuthTokens.pageOuterAuth,
          footer: DrivepalAuthMutedFooter(
            padding: EdgeInsets.zero,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                const Text(DrivepalAuthCopy.resetFooterSignInPrompt),
                TextButton(
                  onPressed: () => context.push('/login'),
                  child: const Text(DrivepalAuthCopy.footerSignInCta),
                ),
              ],
            ),
          ),
          bottomAction: invalid
              ? null
              : DrivepalAsyncFilledButton(
                  loading: _loading,
                  label: 'Update password',
                  loadingLabel: 'Saving…',
                  icon: const Icon(Icons.save_rounded, size: 20),
                  onPressed: _submit,
                ),
          child: DrivepalAuthCard(
            contentPadding: DrivepalAuthTokens.authCardFormPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (invalid) ...[
                  DrivepalAuthBanner.error(
                    text: DrivepalAuthCopy.resetInvalidLinkMessage,
                  ),
                ] else ...[
                  if (_error != null) DrivepalAuthBanner.error(text: _error!),
                  if (_info != null && _error == null)
                    DrivepalAuthBanner.info(text: _info!),
                  SizedBox(height: _error != null || _info != null ? 8 : 16),
                  DrivepalSoftFrame(
                    focusNode: _focusPassword,
                    child: TextField(
                      controller: _password,
                      focusNode: _focusPassword,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        helperText: 'At least 8 characters',
                        prefixIcon: Icon(
                          Icons.lock_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
