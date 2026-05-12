import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../services/driver_cars_api.dart';
import '../../theme/drivepal_tokens.dart';
import '../../widgets/drivepal_shell_layout.dart';
import '../../widgets/drivepal_tab_page_chrome.dart';

class DriverCarsScreen extends StatefulWidget {
  const DriverCarsScreen({super.key, this.api});

  final DriverCarsApi? api;

  @override
  State<DriverCarsScreen> createState() => _DriverCarsScreenState();
}

class _DriverCarsScreenState extends State<DriverCarsScreen> {
  late final DriverCarsApi _api = widget.api ?? DriverCarsApi();
  bool _loading = true;
  String? _error;
  List<DriverCarItem> _cars = const <DriverCarItem>[];

  static const _makes = <String>[
    'Toyota',
    'Honda',
    'Hyundai',
    'Kia',
    'Nissan',
    'Ford',
    'BMW',
    'Mercedes',
    'Audi',
    'Tesla',
  ];

  static const Map<String, List<String>> _modelsByMake = {
    'Toyota': ['Corolla', 'Camry', 'Prius', 'RAV4'],
    'Honda': ['Civic', 'Accord', 'CR-V', 'Jazz'],
    'Hyundai': ['i20', 'i30', 'Tucson', 'Ioniq'],
    'Kia': ['Rio', 'Ceed', 'Sportage', 'Niro'],
    'Nissan': ['Micra', 'Qashqai', 'Leaf', 'Juke'],
    'Ford': ['Fiesta', 'Focus', 'Mondeo', 'Kuga'],
    'BMW': ['3 Series', '5 Series', 'X3', 'X5'],
    'Mercedes': ['C-Class', 'E-Class', 'GLA', 'GLE'],
    'Audi': ['A3', 'A4', 'Q3', 'Q5'],
    'Tesla': ['Model 3', 'Model Y', 'Model S', 'Model X'],
  };

  static const _colors = <String>[
    'Black',
    'White',
    'Gray',
    'Silver',
    'Blue',
    'Red',
    'Green',
    'Brown',
  ];

  static const _carTypes = <({String id, String title, double pricePerKmGbp})>[
    (id: 'sedan4', title: 'City Sedan', pricePerKmGbp: 1.45),
    (id: 'mpv5', title: 'Family Plus', pricePerKmGbp: 1.70),
    (id: 'suv6', title: 'SUV Comfort', pricePerKmGbp: 2.00),
    (id: 'van7', title: 'Executive Van', pricePerKmGbp: 2.35),
    (id: 'van8', title: 'Maxi Van', pricePerKmGbp: 2.75),
  ];

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  Future<void> _loadCars() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (token == null) {
        setState(() {
          _loading = false;
          _error = 'Sign in again to manage cars.';
        });
        return;
      }
      final cars = await _api.listMine(bearerToken: token);
      if (!mounted) return;
      setState(() {
        _cars = cars;
        _loading = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _openCarForm({DriverCarItem? existing}) async {
    final seed =
        existing?.toInput() ??
        const DriverCarInput(
          displayName: 'Daily Ride',
          manufacturer: 'Toyota',
          model: 'Corolla',
          color: 'Black',
          plateNumber: '',
          seatCapacity: 4,
          carTypeId: 'sedan4',
          transmission: 'automatic',
          isActive: true,
          acceptsPets: false,
          hasAirConditioning: true,
          hasChildSeat: false,
          wheelchairAccessible: false,
        );

    var draft = seed;
    final plateCtrl = TextEditingController(text: seed.plateNumber);
    final saved = await showModalBottomSheet<DriverCarInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setModalState) {
              final models = _modelsByMake[draft.manufacturer] ?? const <String>[];
              if (!models.contains(draft.model) && models.isNotEmpty) {
                draft = draft.copyWith(model: models.first);
              }
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    drivepalModalTopInset(ctx, includeFloatingTopBar: false),
                    12,
                    drivepalModalBottomInset(ctx, includeFloatingNav: false),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DrivepalTokens.bgCard,
                      borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
                      border: Border.all(color: DrivepalTokens.borderCard),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              existing == null ? 'Add car' : 'Edit car',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: DrivepalTokens.textHeading,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: draft.manufacturer,
                              decoration: const InputDecoration(labelText: 'Make'),
                              items:
                                  _makes
                                      .map(
                                        (it) => DropdownMenuItem(
                                          value: it,
                                          child: Text(it),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(() {
                                  draft = draft.copyWith(
                                    manufacturer: value,
                                    model:
                                        (_modelsByMake[value] ?? const ['Generic']).first,
                                  );
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: draft.model,
                              decoration: const InputDecoration(labelText: 'Model'),
                              items:
                                  models
                                      .map(
                                        (it) => DropdownMenuItem(
                                          value: it,
                                          child: Text(it),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(() => draft = draft.copyWith(model: value));
                              },
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: draft.color,
                              decoration: const InputDecoration(labelText: 'Color'),
                              items:
                                  _colors
                                      .map(
                                        (it) => DropdownMenuItem(
                                          value: it,
                                          child: Text(it),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(() => draft = draft.copyWith(color: value));
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: plateCtrl,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Plate number',
                                hintText: 'AB12 CDE',
                              ),
                              onChanged:
                                  (value) => draft = draft.copyWith(
                                    plateNumber: value.trim().toUpperCase(),
                                  ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: draft.carTypeId,
                              decoration: const InputDecoration(labelText: 'Car type'),
                              items:
                                  _carTypes
                                      .map(
                                        (it) => DropdownMenuItem(
                                          value: it.id,
                                          child: Text(it.title),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(
                                  () => draft = draft.copyWith(carTypeId: value),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: draft.transmission,
                              decoration: const InputDecoration(
                                labelText: 'Transmission',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'automatic',
                                  child: Text('Automatic'),
                                ),
                                DropdownMenuItem(
                                  value: 'manual',
                                  child: Text('Manual'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(
                                  () => draft = draft.copyWith(transmission: value),
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Seats: ${draft.seatCapacity}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Slider(
                              value: draft.seatCapacity.toDouble(),
                              min: 2,
                              max: 8,
                              divisions: 6,
                              label: '${draft.seatCapacity}',
                              onChanged: (value) {
                                setModalState(
                                  () => draft = draft.copyWith(
                                    seatCapacity: value.round(),
                                  ),
                                );
                              },
                            ),
                            Text(
                              'Static price per km: GBP ${(_carTypes.firstWhere((it) => it.id == draft.carTypeId, orElse: () => _carTypes.first).pricePerKmGbp).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: DrivepalTokens.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SwitchListTile.adaptive(
                              value: draft.isActive,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Car is active'),
                              subtitle: const Text('Available for trip assignment'),
                              onChanged: (value) {
                                setModalState(() => draft = draft.copyWith(isActive: value));
                              },
                            ),
                            SwitchListTile.adaptive(
                              value: draft.hasAirConditioning,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Air conditioning'),
                              onChanged: (value) {
                                setModalState(
                                  () =>
                                      draft = draft.copyWith(hasAirConditioning: value),
                                );
                              },
                            ),
                            SwitchListTile.adaptive(
                              value: draft.acceptsPets,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Accept pets'),
                              onChanged: (value) {
                                setModalState(() => draft = draft.copyWith(acceptsPets: value));
                              },
                            ),
                            SwitchListTile.adaptive(
                              value: draft.hasChildSeat,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Child seat available'),
                              onChanged: (value) {
                                setModalState(
                                  () => draft = draft.copyWith(hasChildSeat: value),
                                );
                              },
                            ),
                            SwitchListTile.adaptive(
                              value: draft.wheelchairAccessible,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Wheelchair accessible'),
                              onChanged: (value) {
                                setModalState(
                                  () => draft = draft.copyWith(
                                    wheelchairAccessible: value,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: () {
                                if (draft.plateNumber.trim().isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('Plate number is required.'),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(ctx).pop(
                                  draft.copyWith(
                                    plateNumber: draft.plateNumber.trim().toUpperCase(),
                                  ),
                                );
                              },
                              child: Text(existing == null ? 'Add car' : 'Save changes'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
    );
    plateCtrl.dispose();
    if (!mounted || saved == null) return;
    await _submitCar(input: saved, existing: existing);
  }

  Future<void> _submitCar({
    required DriverCarInput input,
    required DriverCarItem? existing,
  }) async {
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted) return;
      if (token == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sign in again to continue.')));
        return;
      }
      if (existing == null) {
        await _api.create(bearerToken: token, input: input);
      } else {
        await _api.update(bearerToken: token, carId: existing.id, input: input);
      }
      if (!mounted) return;
      await _loadCars();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Car added.' : 'Car updated.'),
        ),
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _carCard(DriverCarItem car) {
    final tt = Theme.of(context).textTheme;
    final featureChips = featureChipsSafe(car);
    if (featureChips.isEmpty) {
      featureChips.add('Standard');
    }
    return DrivepalElevatedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  car.displayName,
                  style: tt.titleMedium?.copyWith(
                    color: DrivepalTokens.textHeading,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch.adaptive(
                value: car.isActive,
                onChanged:
                    (value) => _submitCar(
                      input: car.toInput().copyWith(isActive: value),
                      existing: car,
                    ),
              ),
            ],
          ),
          Text(
            '${car.manufacturer} ${car.model} • ${car.color}',
            style: tt.bodyMedium?.copyWith(color: DrivepalTokens.textBody),
          ),
          const SizedBox(height: 6),
          Text(
            'Plate: ${car.plateNumber} • ${car.seatCapacity} seats',
            style: tt.bodySmall?.copyWith(color: DrivepalTokens.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            '${car.carTypeTitle} • GBP ${car.pricePerKmGbp.toStringAsFixed(2)} / km • ${car.transmission}',
            style: tt.bodySmall?.copyWith(
              color: DrivepalTokens.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                featureChips
                    .map(
                      (it) => DecoratedBox(
                        decoration: BoxDecoration(
                          color: DrivepalTokens.bgPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            DrivepalTokens.radiusInput,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            it,
                            style: tt.labelSmall?.copyWith(
                              color: DrivepalTokens.textHeading,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openCarForm(existing: car),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit'),
            ),
          ),
        ],
      ),
    );
  }

  List<String> featureChipsSafe(DriverCarItem car) {
    final chips = <String>[];
    if (car.hasAirConditioning) chips.add('AC');
    if (car.acceptsPets) chips.add('Pets');
    if (car.hasChildSeat) chips.add('Child seat');
    if (car.wheelchairAccessible) chips.add('Accessible');
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Cars')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCarForm(),
        backgroundColor: DrivepalTokens.bgPrimary,
        foregroundColor: DrivepalTokens.textOnPrimary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 38),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCars,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          children: [
            const DrivepalFeatureIntroCard(
              icon: Icons.directions_car_filled_rounded,
              title: 'My Cars',
              subtitle:
                  'Manage your ride-ready cars. Set fare per km, availability, and comfort features.',
            ),
            const SizedBox(height: 10),
            if (_loading)
              const DrivepalElevatedPanel(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              DrivepalElevatedPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _loadCars,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_cars.isEmpty)
              const DrivepalElevatedPanel(
                child: DrivepalEmptyStateBlock(
                  icon: Icons.directions_car_outlined,
                  title: 'No cars yet',
                  body: 'Add your first car to start receiving ride assignments.',
                ),
              )
            else
              ..._cars.map(
                (car) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _carCard(car),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
