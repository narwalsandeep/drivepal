export type BookingCarOptionConfig = {
  readonly id: string;
  readonly title: string;
  readonly subtitle: string;
  readonly seats: number;
  readonly pricePerKmGbp: number;
};

export const BOOKING_CAR_OPTIONS_CURRENCY_CODE = 'GBP';

export const BOOKING_CAR_OPTIONS: readonly BookingCarOptionConfig[] = [
  {
    id: 'sedan4',
    title: 'City Sedan',
    subtitle: 'Comfort ride for everyday trips',
    seats: 4,
    pricePerKmGbp: 1.45,
  },
  {
    id: 'mpv5',
    title: 'Family Plus',
    subtitle: 'Extra room for bags',
    seats: 5,
    pricePerKmGbp: 1.7,
  },
  {
    id: 'suv6',
    title: 'SUV Comfort',
    subtitle: 'Spacious and smooth',
    seats: 6,
    pricePerKmGbp: 2,
  },
  {
    id: 'van7',
    title: 'Executive Van',
    subtitle: 'Great for group travel',
    seats: 7,
    pricePerKmGbp: 2.35,
  },
  {
    id: 'van8',
    title: 'Maxi Van',
    subtitle: 'Highest seating capacity',
    seats: 8,
    pricePerKmGbp: 2.75,
  },
] as const;
