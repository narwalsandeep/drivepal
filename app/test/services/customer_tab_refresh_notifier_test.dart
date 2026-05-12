import 'package:flutter_test/flutter_test.dart';
import 'package:drivepal_app/services/customer_tab_refresh_notifier.dart';

void main() {
  test('increments tab version for each selection', () {
    final notifier = CustomerTabRefreshNotifier();

    expect(notifier.versionFor(CustomerTabIndex.alerts), 0);
    notifier.markTabSelected(CustomerTabIndex.alerts);
    expect(notifier.versionFor(CustomerTabIndex.alerts), 1);
    notifier.markTabSelected(CustomerTabIndex.alerts);
    expect(notifier.versionFor(CustomerTabIndex.alerts), 2);
    expect(notifier.versionFor(CustomerTabIndex.payment), 0);
  });
}
