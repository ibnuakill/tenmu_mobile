import 'package:flutter/material.dart';

class UmkmFacility {
  final String id;
  final String label;
  final IconData icon;

  const UmkmFacility(this.id, this.label, this.icon);

  static const List<UmkmFacility> all = [
    UmkmFacility('wc', 'WC', Icons.wc_outlined),
    UmkmFacility('wifi', 'WiFi', Icons.wifi_outlined),
    UmkmFacility('mushola', 'Mushola', Icons.mosque_outlined),
    UmkmFacility('parkir', 'Parkir', Icons.local_parking_outlined),
    UmkmFacility('smoking', 'Smoking Area', Icons.smoking_rooms_outlined),
    UmkmFacility('ac', 'AC', Icons.ac_unit_outlined),
  ];

  static IconData iconFor(String id) {
    return all.firstWhere(
      (f) => f.id == id,
      orElse: () => UmkmFacility(id, id, Icons.check_circle_outline),
    ).icon;
  }

  static String labelFor(String id) {
    return all.firstWhere(
      (f) => f.id == id,
      orElse: () => UmkmFacility(id, id, Icons.check_circle_outline),
    ).label;
  }

  static List<UmkmFacility> fromList(List<dynamic>? ids) {
    if (ids == null) return [];
    return ids
        .map((id) => all.firstWhere(
              (f) => f.id == id,
              orElse: () => UmkmFacility(id.toString(), id.toString(), Icons.check_circle_outline),
            ))
        .toList();
  }
}
