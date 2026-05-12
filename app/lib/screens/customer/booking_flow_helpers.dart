/// Pure validation for booking address fields (used by [BookRideScreen] and tests).
bool drivepalBookingCanSubmitAddresses(String pickup, String dropoff) =>
    pickup.trim().isNotEmpty && dropoff.trim().isNotEmpty;
