import 'package:flutter/foundation.dart';

abstract final class DriverTabIndex {
  static const int newRequests = 0;
  static const int trips = 1;
  static const int alerts = 2;
  static const int account = 3;
  static const int chat = 4;
}

/// Emits lightweight refresh ticks per driver tab when user taps bottom nav.
class DriverTabRefreshNotifier extends ChangeNotifier {
  final Map<int, int> _tabVersions = <int, int>{};

  int versionFor(int tabIndex) => _tabVersions[tabIndex] ?? 0;

  void markTabSelected(int tabIndex) {
    _tabVersions[tabIndex] = (_tabVersions[tabIndex] ?? 0) + 1;
    notifyListeners();
  }
}
