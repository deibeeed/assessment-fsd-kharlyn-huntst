import 'package:flutter/material.dart';

enum Category {
  food,
  coffee,
  fashion,
  travel,
  fitness,
  tech,
  beauty,
  books;

  String get displayName => switch (this) {
        Category.food => 'Food',
        Category.coffee => 'Coffee',
        Category.fashion => 'Fashion',
        Category.travel => 'Travel',
        Category.fitness => 'Fitness',
        Category.tech => 'Tech',
        Category.beauty => 'Beauty',
        Category.books => 'Books',
      };

  IconData get icon => switch (this) {
        Category.food => Icons.restaurant_outlined,
        Category.coffee => Icons.local_cafe_outlined,
        Category.fashion => Icons.checkroom_outlined,
        Category.travel => Icons.flight_outlined,
        Category.fitness => Icons.fitness_center_outlined,
        Category.tech => Icons.devices_outlined,
        Category.beauty => Icons.spa_outlined,
        Category.books => Icons.menu_book_outlined,
      };
}
