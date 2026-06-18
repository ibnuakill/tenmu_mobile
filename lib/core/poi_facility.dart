import 'package:flutter/material.dart';

class PoiFacility {
  final String id;
  final String label;
  final IconData icon;

  const PoiFacility(this.id, this.label, this.icon);

  static const List<PoiFacility> all = [
    PoiFacility('wc', 'WC', Icons.wc_outlined),
    PoiFacility('wifi', 'WiFi', Icons.wifi_outlined),
    PoiFacility('mushola', 'Mushola', Icons.mosque_outlined),
    PoiFacility('parkir', 'Parkir', Icons.local_parking_outlined),
    PoiFacility('smoking', 'Smoking Area', Icons.smoking_rooms_outlined),
    PoiFacility('ac', 'AC', Icons.ac_unit_outlined),
  ];

  static IconData iconFor(String id) {
    return all.firstWhere(
      (f) => f.id == id,
      orElse: () => PoiFacility(id, id, Icons.check_circle_outline),
    ).icon;
  }

  static String labelFor(String id) {
    return all.firstWhere(
      (f) => f.id == id,
      orElse: () => PoiFacility(id, id, Icons.check_circle_outline),
    ).label;
  }

  static List<PoiFacility> fromList(List<dynamic>? ids) {
    if (ids == null) return [];
    return ids
        .map((id) => all.firstWhere(
              (f) => f.id == id,
              orElse: () => PoiFacility(id.toString(), id.toString(), Icons.check_circle_outline),
            ))
        .toList();
  }
}
