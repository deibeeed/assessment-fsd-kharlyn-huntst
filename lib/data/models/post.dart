import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:equatable/equatable.dart';

class Post extends Equatable {
  const Post({
    required this.id,
    required this.authorName,
    required this.authorHandle,
    required this.caption,
    required this.imageUrl,
    required this.categories,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final String id;
  final String authorName;
  final String authorHandle;
  final String caption;
  final String imageUrl;
  final List<Category> categories;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  @override
  List<Object?> get props => [
        id,
        authorName,
        authorHandle,
        caption,
        imageUrl,
        categories,
        latitude,
        longitude,
        timestamp,
      ];
}
