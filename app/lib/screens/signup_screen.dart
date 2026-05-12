import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_api.dart';
import '../services/auth_session.dart';
import '../widgets/auth/drivepal_auth.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/drivepal_pill_toggle.dart';
import '../widgets/drivepal_soft_frame.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _api = AuthApi();
  int _step = 1;
  bool _loading = false;
  String _loadingMessage = '';
  String? _error;
  String? _info;
  String? _signupEmailMasked;

  String _signupAs = 'customer';

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();

  final _focusFirstName = FocusNode();
  final _focusLastName = FocusNode();
  final _focusEmail = FocusNode();
  final _focusPhone = FocusNode();
  final _focusPassword = FocusNode();
  final _focusOtp = FocusNode();

  @override
  void dispose() {
    _focusFirstName.dispose();
    _focusLastName.dispose();
    _focusEmail.dispose();
    _focusPhone.dispose();
    _focusPassword.dispose();
    _focusOtp.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final pwd = _password.text;
    if (pwd.length < 8 || pwd.length > 128) {
      setState(() => _error = 'Password must be 8–128 characters.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
      _loadingMessage = 'Sending code…';
    });
    try {
      final res = await _api.post('/signup/start', {
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': pwd,
        'signupAs': _signupAs,
      });
      setState(() {
        _signupEmailMasked = res['emailMasked'] as String?;
        _info = res['message'] as String? ?? 'Code sent — check your email.';
        _step = 2;
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

  Future<void> _verify() async {
    setState(() {
      _error = null;
      _loading = true;
      _loadingMessage = 'Creating your account…';
    });
    try {
      final res = await _api.post('/signup/verify', {
        'email': _email.text.trim(),
        'otp': _otp.text.trim(),
      });
      final role = res['signupAs'] as String? ?? 'customer';
      if (!mounted) return;
      await context.read<AuthSession>().signInFromAuthResponse(res, role);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMessage = '';
      });
      context.go(context.read<AuthSession>().homeLocation);
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
          pageTitle: DrivepalAuthCopy.signupPageTitle,
          pageSubtitle: DrivepalAuthCopy.signupPageSubtitle,
          outerPadding: DrivepalAuthTokens.pageOuterAuth,
          footer: DrivepalAuthMutedFooter(
            padding: EdgeInsets.zero,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                const Text(DrivepalAuthCopy.signupFooterHasAccountPrompt),
                TextButton(
                  onPressed: () => context.push('/login'),
                  child: const Text(DrivepalAuthCopy.footerSignInCta),
                ),
              ],
            ),
          ),
          bottomAction:
              _step == 1
                  ? DrivepalAsyncFilledButton(
                    loading: _loading,
                    label: 'Send code',
                    loadingLabel: 'Sending…',
                    icon: const Icon(Icons.send_rounded, size: 20),
                    onPressed: _sendCode,
                  )
                  : DrivepalAsyncFilledButton(
                    loading: _loading,
                    label: 'Verify & create account',
                    loadingLabel: 'Verifying…',
                    icon: const Icon(Icons.verified_rounded, size: 20),
                    onPressed: _verify,
                  ),
          child: DrivepalAuthCard(
            contentPadding: DrivepalAuthTokens.authCardFormPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) DrivepalAuthBanner.error(text: _error!),
                if (_info != null && _error == null && _step == 1)
                  DrivepalAuthBanner.info(text: _info!),
                if (_step == 1) ...[
                  SizedBox(height: _info != null || _error != null ? 8 : 16),
                  DrivepalPillToggle<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'customer',
                        label: Text('Rider'),
                        icon: Icon(Icons.person_rounded, size: 22),
                      ),
                      ButtonSegment<String>(
                        value: 'driver',
                        label: Text('Driver'),
                        icon: Icon(Icons.local_taxi_rounded, size: 22),
                      ),
                    ],
                    selected: {_signupAs},
                    onSelectionChanged: (s) {
                      setState(() => _signupAs = s.first);
                    },
                  ),
                  SizedBox(height: DrivepalAuthTokens.formGap),
                  DrivepalSoftFrame(
                    focusNode: _focusFirstName,
                    child: TextField(
                      controller: _firstName,
                      focusNode: _focusFirstName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        prefixIcon: Icon(
                          Icons.person_rounded,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: DrivepalAuthTokens.formGap),
                  DrivepalSoftFrame(
                    focusNode: _focusLastName,
                    child: TextField(
                      controller: _lastName,
                      focusNode: _focusLastName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        prefixIcon: Icon(
                          Icons.person_rounded,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: DrivepalAuthTokens.formGap),
                  DrivepalSoftFrame(
                    focusNode: _focusEmail,
                    child: TextField(
                      controller: _email,
                      focusNode: _focusEmail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(
                          Icons.alternate_email_rounded,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: DrivepalAuthTokens.formGap),
                  DrivepalSoftFrame(
                    focusNode: _focusPhone,
                    child: TextField(
                      controller: _phone,
                      focusNode: _focusPhone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Mobile (UK)',
                        hintText: '+44…',
                        prefixIcon: Icon(
                          Icons.smartphone_rounded,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: DrivepalAuthTokens.formGap),
                  DrivepalSoftFrame(
                    focusNode: _focusPassword,
                    child: TextField(
                      controller: _password,
                      focusNode: _focusPassword,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _sendCode(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        helperText: 'At least 8 characters.',
                        prefixIcon: Icon(
                          Icons.lock_rounded,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(height: _error != null ? 8 : 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.mark_email_read_rounded,
                        size: 20,
                        color: DrivepalTokens.accentIcon,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _signupEmailMasked != null
                              ? 'Check your inbox — code sent to $_signupEmailMasked'
                              : 'Check your inbox — code sent to ${_email.text.trim()}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: DrivepalTokens.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: DrivepalAuthTokens.formGap),
                  DrivepalSoftFrame(
                    focusNode: _focusOtp,
                    child: TextField(
                      controller: _otp,
                      focusNode: _focusOtp,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _verify(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        letterSpacing: 6,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Code from email',
                        counterText: '',
                        prefixIcon: Icon(
                          Icons.pin_rounded,
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
