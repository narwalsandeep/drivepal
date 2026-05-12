import 'package:flutter/foundation.dart';

abstract final class CustomerTabIndex {
  static const int ride = 0;
  static const int trips = 1;
  static const int alerts = 2;
  static const int account = 3;
  static const int chat = 4;
  static const int payment = 99;
}

/// Emits lightweight refresh ticks per customer tab when user taps bottom nav.
class CustomerTabRefreshNotifier extends ChangeNotifier {
  final Map<int, int> _tabVersions = <int, int>{};

  int versionFor(int tabIndex) => _tabVersions[tabIndex] ?? 0;

  void markTabSelected(int tabIndex) {
    _tabVersions[tabIndex] = (_tabVersions[tabIndex] ?? 0) + 1;
    notifyListeners();
  }
}
