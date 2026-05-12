import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_api.dart';
import '../services/auth_session.dart';
import '../widgets/auth/drivepal_auth.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/drivepal_pill_toggle.dart';
import '../widgets/drivepal_soft_frame.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = AuthApi();
  int _step = 1;
  bool _loading = false;
  String _loadingMessage = '';
  String? _error;
  String? _info;
  String? _loginEmailMasked;
  String _challengeId = '';
  String _loginAs = 'customer';

  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();

  final _focusIdentifier = FocusNode();
  final _focusPassword = FocusNode();
  final _focusOtp = FocusNode();

  @override
  void dispose() {
    _focusIdentifier.dispose();
    _focusPassword.dispose();
    _focusOtp.dispose();
    _identifier.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _otpStep() async {
    setState(() {
      _error = null;
      _loading = true;
      _loadingMessage = 'Signing you in…';
    });
    try {
      final res = await _api.post('/login/verify', {
        'challengeId': _challengeId,
        'otp': _otp.text.trim(),
      });
      final ar = res['activeRole'] as String?;
      if (!mounted) return;
      await context.read<AuthSession>().signInFromAuthResponse(
        res,
        ar ?? 'customer',
      );
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

  Future<void> _passwordStep() async {
    final pwd = _password.text;
    if (pwd.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
      _loadingMessage = 'Sending verification code…';
    });
    try {
      final res = await _api.post('/login', {
        'identifier': _identifier.text.trim(),
        'password': pwd,
        'loginAs': _loginAs,
      });
      _challengeId = res['challengeId'] as String? ?? '';
      setState(() {
        _loginEmailMasked = res['emailMasked'] as String?;
        _info = null;
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
          pageTitle: DrivepalAuthCopy.loginPageTitle,
          pageSubtitle: DrivepalAuthCopy.loginPageSubtitle,
          outerPadding: DrivepalAuthTokens.pageOuterAuth,
          footer: DrivepalAuthMutedFooter(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    const Text(DrivepalAuthCopy.loginFooterNewAccountPrompt),
                    TextButton(
                      onPressed: () => context.push('/signup'),
                      child: const Text(DrivepalAuthCopy.footerSignUpCta),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text(DrivepalAuthCopy.loginFooterForgotLabel),
                ),
              ],
            ),
          ),
          bottomAction: _step == 1
              ? DrivepalAsyncFilledButton(
                  loading: _loading,
                  label: 'Continue',
                  loadingLabel: 'Sending…',
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  onPressed: _passwordStep,
                )
              : DrivepalAsyncFilledButton(
                  loading: _loading,
                  label: 'Verify & sign in',
                  loadingLabel: 'Signing in…',
                  icon: const Icon(Icons.verified_rounded, size: 20),
                  onPressed: _otpStep,
                ),
          child: DrivepalAuthCard(
            contentPadding: DrivepalAuthTokens.authCardFormPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) DrivepalAuthBanner.error(text: _error!),
                if (_info != null && _error == null)
                  DrivepalAuthBanner.info(text: _info!),
                if (_step == 1) ...[
                  SizedBox(height: _error != null || _info != null ? 8 : 16),
                  Text(
                    DrivepalAuthCopy.loginRolePickerLabel,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: DrivepalTokens.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  SizedBox(height: DrivepalAuthTokens.sectionGapSm),
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
                    selected: {_loginAs},
                    onSelectionChanged: (s) {
                      setState(() => _loginAs = s.first);
                    },
                  ),
                  SizedBox(height: DrivepalAuthTokens.formGap),
                  DrivepalSoftFrame(
                    focusNode: _focusIdentifier,
                    child: TextField(
                      controller: _identifier,
                      focusNode: _focusIdentifier,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email or mobile',
                        hintText: 'you@example.com or +44…',
                        prefixIcon: Icon(
                          Icons.contact_mail_rounded,
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
                      onSubmitted: (_) => _passwordStep(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(
                          Icons.lock_rounded,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(height: _error != null ? 8 : 16),
                  if (_loginEmailMasked != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: DrivepalAuthTokens.formGap),
                      child: Row(
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
                              'Code sent to $_loginEmailMasked',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: DrivepalTokens.textMuted,
                                    height: 1.45,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  DrivepalSoftFrame(
                    focusNode: _focusOtp,
                    child: TextField(
                      controller: _otp,
                      focusNode: _focusOtp,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _otpStep(),
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
