import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_api.dart';
import '../widgets/auth/drivepal_auth.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/drivepal_soft_frame.dart';

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});

  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _api = AuthApi();
  final _email = TextEditingController();
  final _focusEmail = FocusNode();
  bool _loading = false;
  String _loadingMessage = '';
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _focusEmail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
      _loadingMessage = 'Sending reset link…';
    });
    try {
      final res = await _api.post('/forgot-password', {
        'email': _email.text.trim(),
      });
      setState(() {
        _info =
            res['message']?.toString() ??
            'If an account exists, check your email.';
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AuthLoadingOverlay(
        visible: _loading,
        message: _loadingMessage.isEmpty ? 'Please wait…' : _loadingMessage,
        child: DrivepalAuthPage(
          showBackBrandLabel: false,
          pageTitle: DrivepalAuthCopy.forgotPageTitle,
          pageSubtitle: DrivepalAuthCopy.forgotPageSubtitle,
          outerPadding: DrivepalAuthTokens.pageOuterAuth,
          footer: DrivepalAuthMutedFooter(
            padding: EdgeInsets.zero,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                const Text(DrivepalAuthCopy.forgotFooterBackToSignInPrompt),
                TextButton(
                  onPressed: () => context.push('/login'),
                  child: const Text(DrivepalAuthCopy.footerSignInCta),
                ),
              ],
            ),
          ),
          bottomAction: DrivepalAsyncFilledButton(
            loading: _loading,
            label: 'Send link',
            loadingLabel: 'Sending…',
            icon: const Icon(Icons.send_rounded, size: 20),
            onPressed: _submit,
          ),
          child: DrivepalAuthCard(
            contentPadding: DrivepalAuthTokens.authCardFormPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) DrivepalAuthBanner.error(text: _error!),
                if (_info != null && _error == null)
                  DrivepalAuthBanner.info(text: _info!),
                SizedBox(height: _error != null || _info != null ? 8 : 16),
                DrivepalSoftFrame(
                  focusNode: _focusEmail,
                  child: TextField(
                    controller: _email,
                    focusNode: _focusEmail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(
                        Icons.alternate_email_rounded,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
