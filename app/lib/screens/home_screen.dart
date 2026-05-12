import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/auth/drivepal_auth.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DrivepalLandingShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DrivepalBrandMark(),
          SizedBox(height: DrivepalAuthTokens.sectionGapMd),
          const DrivepalLandingRoleIconRow(),
          SizedBox(height: DrivepalAuthTokens.sectionGapSm),
          const DrivepalLandingHeadline(DrivepalAuthCopy.landingHeadline),
          SizedBox(height: DrivepalAuthTokens.sectionGapSm),
          const DrivepalLandingLead(DrivepalAuthCopy.landingLead),
          SizedBox(height: DrivepalAuthTokens.sectionGapLg),
          DrivepalLandingAuthActions(
            onSignUp: () => context.push('/signup'),
            onSignIn: () => context.push('/login'),
            onForgotPassword: () => context.push('/forgot-password'),
          ),
        ],
      ),
    );
  }
}
