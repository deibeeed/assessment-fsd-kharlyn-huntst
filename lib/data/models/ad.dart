import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:equatable/equatable.dart';

enum AdTier {
  gold,
  silver,
  bronze;

  int get weight => switch (this) {
        AdTier.gold => 3,
        AdTier.silver => 2,
        AdTier.bronze => 1,
      };
}

class Ad extends Equatable {
  const Ad({
    required this.id,
    required this.title,
    required this.description,
    required this.advertiserName,
    required this.tier,
    required this.latitude,
    required this.longitude,
    this.imageUrl = '',
    this.categories = const [],
  });

  final String id;
  final String title;
  final String description;
  final String advertiserName;
  final AdTier tier;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final List<Category> categories;

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        advertiserName,
        tier,
        latitude,
        longitude,
        imageUrl,
        categories,
      ];
}
