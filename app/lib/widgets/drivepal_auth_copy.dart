/// User-facing strings for auth / marketing flows — single source (no inline copy in screens).
abstract final class DrivepalAuthCopy {
  // ——— Landing ———
  static const landingHeadline = 'Mobile shell';
  static const landingLead =
      'One app for riders and drivers (UK). Sign up as a rider or driver — OTP is always emailed. You can add the other role later with the same email.';

  // ——— Signup shell ———
  static const signupPageTitle = 'Create account';
  static const signupPageSubtitle =
      'Sign up as a rider or driver.';

  // ——— Sign in ———
  static const loginPageTitle = 'Sign in';
  static const loginPageSubtitle =
      'Use the email or UK mobile you signed up with—we’ll email you a code to finish signing in.';
  static const loginRolePickerLabel = 'Open the app as';

  // ——— Forgot password ———
  static const forgotPageTitle = 'Forgot password';
  static const forgotPageSubtitle =
      'We’ll email you a link to reset your password. SMS isn’t used for resets.';

  // ——— Reset password (deep link) ———
  static const resetPageTitle = 'New password';
  static const resetPageSubtitle =
      'Choose a strong password you haven’t used elsewhere.';
  static const resetInvalidLinkMessage =
      'Open this screen from the link in your reset email.';

  // ——— Auth footers (muted links under forms) ———
  static const signupFooterHasAccountPrompt = 'Already have an account?';
  static const loginFooterNewAccountPrompt = "Don't have an account?";
  static const loginFooterForgotLabel = 'Forgot password?';
  static const forgotFooterBackToSignInPrompt = 'Remember your password?';
  static const resetFooterSignInPrompt = 'Want to sign in instead?';
  static const footerSignInCta = 'Sign in';
  static const footerSignUpCta = 'Sign up';
}
