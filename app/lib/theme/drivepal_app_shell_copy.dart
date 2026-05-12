/// Rider / driver shell UI copy — single source for tab & profile chrome.
abstract final class DrivepalAppShellCopy {
  // ——— Shared profile ———
  static const riderRoleLabel = 'Rider';
  static const driverRoleLabel = 'Driver';

  static const profileSectionProfile = 'Profile';
  static const profileSectionSettings = 'Settings';

  static const profileEditTitle = 'Edit profile';
  static const profileEditSubtitle = 'Name, email & photo';

  static const profileChangePasswordTitle = 'Change password';
  static const profileChangePasswordSubtitle =
      'Update your account password securely';

  static const profileNotificationsTitle = 'Notifications';
  static const profileNotificationsSubtitle = 'Trip and promo alerts';

  static const profileHelpTitle = 'Help & support';

  static const actionLogout = 'Log out';

  // ——— Rider ——— trips
  static const riderTripsIntroTitle = 'Your trips';
  static const riderTripsIntroSubtitle =
      'Review past rides, fares, and routes. Receipts and trip detail sheets will live here.';

  static const riderTripsSectionHistory = 'History';
  static const riderTripsEmptyTitle = 'No trips yet';
  static const riderTripsEmptyBody =
      'When you book rides, your history will appear here with fare and route details.';

  // ——— Rider ——— wallet
  static const riderWalletIntroTitle = 'Wallet & payments';
  static const riderWalletIntroSubtitle =
      'Saved cards will power one-tap checkout. Integration uses Stripe with PCI-friendly flows.';
  static const riderWalletBadgeReady = 'Stripe';

  static const riderWalletSectionAddMethod = 'Add method';
  static const riderWalletAddCardCta = 'Add payment method';

  static const riderWalletSectionSavedCards = 'Saved cards';
  static const riderWalletNoCardsTitle = 'No cards on file';
  static const riderWalletNoCardsBody =
      'Cards you add will be listed here with last four digits and brand.';

  // ——— Rider ——— alerts
  static const riderAlertsIntroTitle = 'Alerts & updates';
  static const riderAlertsIntroSubtitle =
      'Track payment updates, driver actions, and booking events in one place.';
  static const riderAlertsSectionAll = 'All alerts';
  static const riderAlertsSectionUnread = 'Unread alerts';
  static const riderAlertsEmptyTitle = 'No alerts yet';
  static const riderAlertsEmptyBody =
      'Booking and payment updates will appear here as soon as they happen.';
  static const riderAlertsFilterAll = 'All';
  static const riderAlertsFilterUnread = 'Unread';

  // ——— Rider ——— book
  /// Same explanatory cadence as wallet/trips intros (how the step works / privacy).
  static const riderBookMapContextRibbonBody =
      'Pick your pickup and destination to see routing, fare estimates, and ETA on the map. '
      'We only share your stops after you confirm a ride—until then they stay local to this flow.';

  static const riderBookPickupSemantic = 'Pickup address';
  static const riderBookPickupHint = 'Pickup location';
  static const riderBookPickupCurrentLocationLabel = 'Use current location';
  static const riderBookPickupCurrentLocationSubtitle =
      'Auto-detect your live pickup point';
  static const riderBookPickupCurrentLocationApplied =
      'Pickup is set to your current location.';
  static const riderBookPickupCurrentLocationServiceDisabled =
      'Location services are off. Turn them on and try again.';
  static const riderBookPickupCurrentLocationPermissionDenied =
      'Location permission is required to use current location.';
  static const riderBookPickupCurrentLocationPermissionBlocked =
      'Location permission is blocked. Enable it in app settings.';
  static const riderBookPickupCurrentLocationFailed =
      'Unable to read your current location right now. Please try again.';
  static const riderBookPickupCurrentLocationUnavailable =
      'Current location is not available on this device/browser.';
  static const riderBookPickupCurrentLocationImprecise =
      'Your current location looks too approximate. Enable precise location and try again.';

  static const riderBookDestinationSemantic = 'Destination address';
  static const riderBookDestinationHint = 'Where to?';

  static const riderBookNextButtonLabel = 'Next';
  static const riderBookNextSemanticsPickup = 'Next, continue to drop-off';
  static const riderBookNextSemanticsDropoff = 'Next, review ride';
  static const riderBookNextHintDisabled = 'Finish this step first';
  static const riderBookFindingLocation = 'Finding location on map…';
  static const riderBookWizardGeocodePrompt =
      'The map pans to each address shortly after you stop typing.';
  static const riderBookPickupLookupNotFound =
      'We could not verify this pickup address. Add street + area/city.';
  static const riderBookDropoffLookupNotFound =
      'We could not verify this destination yet. Add more address detail.';
  static const riderBookLookupApproximatePin =
      'We could not verify an exact match, so we pinned the closest area. You can still adjust it.';

  static const riderBookSummaryPickupChip = 'Pickup';
  static const riderBookSummaryDropoffChip = 'Drop-off';
  static const riderBookEditLocationHint = 'Change';

  static const riderBookRequestRideLabel = 'Request ride';
  static const riderBookRequestRideSemantics = 'Request ride, confirm booking';
  static const riderBookRouteCalculating = 'Calculating best route...';
  static const riderBookRouteTrafficLabel = 'Traffic now';

  /// Legacy single-step CTA (wizard uses [riderBookNextButtonLabel]).
  static const riderBookGoButtonLabel = 'Go';
  static const riderBookGoSemanticsLabel = 'Go, request ride';
  static const riderBookGoSemanticsHintReady = 'Starts booking flow';
  static const riderBookGoSemanticsHintIncomplete =
      'Enter pickup and destination';
  static const riderBookGoCaptionReady =
      'You can adjust stops anytime before confirming.';
  static const riderBookGoCaptionIncomplete =
      'Add both pickup and destination to continue.';

  // ——— Driver ——— profile
  static const driverProfileSectionVerification = 'Verification';
  static const driverDocumentsTitle = 'Driver documents';
  static const driverDocumentsSubtitle =
      'Licence & vehicle checks — coming soon';

  // ——— Driver ——— trips ledger
  static const driverTripsIntroTitle = 'Trip history';
  static const driverTripsIntroSubtitle =
      'Completed rides, earnings, and payout-ready trips will show in this ledger.';
  static const driverTripsSectionCompleted = 'Completed';
  static const driverTripsEmptyTitle = 'No completed trips';
  static const driverTripsEmptyBody =
      'Past rides and payouts will list here once you start accepting trips.';
}
