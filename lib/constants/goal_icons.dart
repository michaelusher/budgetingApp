import 'package:flutter/material.dart';

const List<IconData> kGoalIcons = [
  Icons.savings_rounded,
  Icons.flight_rounded,
  Icons.home_rounded,
  Icons.directions_car_rounded,
  Icons.school_rounded,
  Icons.laptop_rounded,
  Icons.celebration_rounded,
  Icons.medical_services_rounded,
];

int goalIconIndex(IconData icon) {
  final i = kGoalIcons.indexWhere((g) => g.codePoint == icon.codePoint);
  return i < 0 ? 0 : i;
}

IconData goalIconAt(int index) {
  if (index < 0 || index >= kGoalIcons.length) return kGoalIcons[0];
  return kGoalIcons[index];
}
