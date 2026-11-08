import 'package:flutter/material.dart';

/// A store department. Each one has its own colour and icon, like an aisle sign.
class Department {
  final String name;
  final IconData icon;
  final Color color;

  const Department(this.name, this.icon, this.color);
}

const Department otherDepartment = Department('Other', Icons.category, Color(0xFF5F6B76));

const List<Department> departments = [
  Department('Plumbing', Icons.plumbing, Color(0xFF0B6FB8)),
  Department('Electrical', Icons.electrical_services, Color(0xFFA86400)),
  Department('Tools', Icons.handyman, Color(0xFF374F9E)),
  Department('Fasteners', Icons.hardware, Color(0xFF4F5D69)),
  Department('Paint & Solvents', Icons.format_paint, Color(0xFF7A3E9D)),
  Department('Building', Icons.construction, Color(0xFF8A5A33)),
  Department('Locks', Icons.lock, Color(0xFF0F766E)),
  Department('Safety', Icons.health_and_safety, Color(0xFFC2410C)),
  Department('Garden', Icons.yard, Color(0xFF15803D)),
  otherDepartment,
];

const Set<String> _legacyPaintCategories = {'Thinners', 'Oils', 'Spirits'};

/// Maps a stored category to a current department name. Products and past
/// sales saved before departments existed use the old paint-only categories.
String normalizeCategory(String? raw) {
  if (_legacyPaintCategories.contains(raw)) return 'Paint & Solvents';
  return departments.any((d) => d.name == raw) ? raw! : otherDepartment.name;
}

Department departmentFor(String name) =>
    departments.firstWhere((d) => d.name == name, orElse: () => otherDepartment);

const List<String> productUnits = ['each', 'm', 'kg', 'L', 'box', 'pack', 'roll', 'bag'];

/// Units that can be sold in part-quantities, such as 2.5 m of cable.
bool isMeasuredUnit(String unit) => const {'m', 'kg', 'L'}.contains(unit);

String formatQty(double qty) {
  final fixed = qty.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String money(double value) => 'R ${value.toStringAsFixed(2)}';

/// Parses a number typed with either a decimal point or a decimal comma.
double? parseNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));
