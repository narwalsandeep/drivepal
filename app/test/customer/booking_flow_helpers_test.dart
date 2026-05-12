import 'package:flutter_test/flutter_test.dart';

import 'package:drivepal_app/screens/customer/booking_flow_helpers.dart';

void main() {
  group('drivepalBookingCanSubmitAddresses', () {
    test('false when either side empty', () {
      expect(drivepalBookingCanSubmitAddresses('', ''), false);
      expect(drivepalBookingCanSubmitAddresses('a', ''), false);
      expect(drivepalBookingCanSubmitAddresses('', 'b'), false);
    });

    test('false when whitespace only', () {
      expect(drivepalBookingCanSubmitAddresses('   ', 'Tokyo'), false);
      expect(drivepalBookingCanSubmitAddresses('Pickup', '\t  \n '), false);
    });

    test('true when both have non-whitespace characters', () {
      expect(drivepalBookingCanSubmitAddresses('A', 'B'), true);
      expect(
        drivepalBookingCanSubmitAddresses('  Warehouse  ', 'Airport gate 12'),
        true,
      );
    });

    test('unicode and long strings acceptable', () {
      expect(drivepalBookingCanSubmitAddresses('東京都', '大阪府'), true);
      expect(
        drivepalBookingCanSubmitAddresses(
          '${'x' * 500}',
          '${'y' * 500}',
        ),
        true,
      );
    });
  });
}
