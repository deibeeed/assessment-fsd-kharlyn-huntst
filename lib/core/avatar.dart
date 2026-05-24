import 'package:flutter/material.dart';

const List<Color> _palette = [
  Color(0xFFD32F2F),
  Color(0xFF7B1FA2),
  Color(0xFF512DA8),
  Color(0xFF303F9F),
  Color(0xFF0288D1),
  Color(0xFF00796B),
  Color(0xFF388E3C),
  Color(0xFFAFB42B),
  Color(0xFFFFA000),
  Color(0xFF5D4037),
];

Color avatarColor(String name) {
  if (name.isEmpty) return _palette.first;
  return _palette[name.codeUnitAt(0) % _palette.length];
}

String avatarInitial(String name) {
  if (name.isEmpty) return '?';
  return name.trim()[0].toUpperCase();
}
