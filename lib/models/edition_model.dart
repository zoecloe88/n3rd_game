import 'package:flutter/material.dart';

class EditionModel {
  final String id;
  final String name;
  final String emoji;
  final String category;
  final String categoryCount;
  final bool isPremium;
  final List<Color> gradientColors;

  const EditionModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.categoryCount,
    required this.isPremium,
    required this.gradientColors,
  });
}
