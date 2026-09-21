import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';

/// Server may return numeric fields as JSON numbers (raw-dict endpoints) or
/// strings (pydantic endpoints) — normalize both to String.
String _s(dynamic v) => '$v';

class MeterRound {
  final int id;
  final String month;
  final String status;
  final List<Reading> readings;

  MeterRound.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        month = j['month'],
        status = j['status'],
        readings =
            (j['readings'] as List?)?.map((e) => Reading.fromJson(e)).toList() ??
                [];

  bool get isOpen => status == 'open';
}

class Reading {
  final int id;
  final int unitId;
  final String previousValue;
  final String currentValue;
  final String consumption;
  final String cost;
  final String? photoPath;
  final String? billPhotoPath;

  Reading.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        unitId = j['unit_id'],
        previousValue = _s(j['previous_value']),
        currentValue = _s(j['current_value']),
        consumption = _s(j['consumption']),
        cost = _s(j['cost']),
        photoPath = j['photo_path'],
        billPhotoPath = j['bill_photo_path'];
}

/// One row of a resident's own water-meter history.
class MyReading {
  final String month;
  final String previousValue;
  final String currentValue;
  final String consumption;
  final String cost;
  final String? photoPath;
  final String? billPhotoPath;

  MyReading.fromJson(Map<String, dynamic> j)
      : month = _s(j['month']),
        previousValue = _s(j['previous_value']),
        currentValue = _s(j['current_value']),
        consumption = _s(j['consumption']),
        cost = _s(j['cost']),
        photoPath = j['photo_path'],
        billPhotoPath = j['bill_photo_path'];
}

/// A shared building meter (public electricity) with its readings.
class PublicMeter {
  final int id;
  final String name;
  final String meterType;
  final String unitPrice;
  final List<PublicReading> readings;

  PublicMeter.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        meterType = j['meter_type'],
        unitPrice = _s(j['unit_price']),
        readings = (j['readings'] as List?)
                ?.map((e) => PublicReading.fromJson(e))
                .toList() ??
            [];
}

class PublicReading {
  final int id;
  final String month;
  final String previousValue;
  final String currentValue;
  final String consumption;
  final String cost;
  final String? photoPath;
  final String? billPhotoPath;

  PublicReading.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        month = _s(j['month']),
        previousValue = _s(j['previous_value']),
        currentValue = _s(j['current_value']),
        consumption = _s(j['consumption']),
        cost = _s(j['cost']),
        photoPath = j['photo_path'],
        billPhotoPath = j['bill_photo_path'];
}

final meterRoundsProvider = FutureProvider<List<MeterRound>>((ref) async {
  final bid = ref.watch(currentBuildingIdProvider);
  if (bid == null) return [];
  final res = await ref.read(apiClientProvider).get('/buildings/$bid/meter-rounds');
  return (res.data as List).map((e) => MeterRound.fromJson(e)).toList();
});

final myReadingsProvider = FutureProvider<List<MyReading>>((ref) async {
  final auth = ref.watch(authProvider).value;
  if (auth?.unitId == null) return [];
  final res = await ref
      .read(apiClientProvider)
      .get('/units/${auth!.unitId}/meter-readings');
  return (res.data as List).map((e) => MyReading.fromJson(e)).toList();
});

final publicMetersProvider = FutureProvider<List<PublicMeter>>((ref) async {
  final bid = ref.watch(currentBuildingIdProvider);
  if (bid == null) return [];
  final res = await ref.read(apiClientProvider).get('/buildings/$bid/public-meters');
  return (res.data as List).map((e) => PublicMeter.fromJson(e)).toList();
});
