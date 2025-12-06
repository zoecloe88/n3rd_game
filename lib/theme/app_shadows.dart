import 'package:flutter/material.dart';

class AppShadows {
  static List<BoxShadow> light = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      offset: const Offset(0, 1),
      blurRadius: 3,
    ),
  ];

  static List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      offset: const Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  static List<BoxShadow> large = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];
}
