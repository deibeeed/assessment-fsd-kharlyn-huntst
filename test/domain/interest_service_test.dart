import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/models/post_like.dart';
import 'package:ad_ranking_prototype/domain/interest/interest_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Post post(String id, List<Category> cats) => Post(
        id: id,
        authorName: id,
        authorHandle: '@$id',
        caption: '',
        imageUrl: '',
        categories: cats,
        latitude: 0,
        longitude: 0,
        timestamp: DateTime(2026, 5, 24),
      );

  final ts = DateTime(2026, 5, 24, 12);
  PostLike like(String postId) => PostLike(postId: postId, likedAt: ts);

  const service = InterestService();

  group('InterestService.computeProfile', () {
    test('empty likes → empty profile', () {
      expect(
        service.computeProfile(likes: const [], postsCatalog: const []),
        isEmpty,
      );
    });

    test('single category single like → 1.0 for that category', () {
      final profile = service.computeProfile(
        likes: [like('p1')],
        postsCatalog: [post('p1', [Category.coffee])],
      );
      expect(profile, {Category.coffee: 1.0});
    });

    test('multi-category post counts in each category', () {
      final profile = service.computeProfile(
        likes: [like('p1')],
        postsCatalog: [post('p1', [Category.food, Category.coffee])],
      );
      expect(profile, {Category.food: 0.5, Category.coffee: 0.5});
    });

    test('normalization sums to 1.0', () {
      final profile = service.computeProfile(
        likes: [like('p1'), like('p2'), like('p3'), like('p4'), like('p5')],
        postsCatalog: [
          post('p1', [Category.food]),
          post('p2', [Category.coffee, Category.food]),
          post('p3', [Category.coffee]),
          post('p4', [Category.food]),
          post('p5', [Category.food]),
        ],
      );
      final sum = profile.values.fold<double>(0, (acc, v) => acc + v);
      expect(sum, closeTo(1.0, 1e-9));
      expect(profile[Category.food], closeTo(4 / 6, 1e-9));
      expect(profile[Category.coffee], closeTo(2 / 6, 1e-9));
    });

    test('liked post no longer in catalog is skipped silently', () {
      final profile = service.computeProfile(
        likes: [like('p-missing'), like('p1')],
        postsCatalog: [post('p1', [Category.fitness])],
      );
      expect(profile, {Category.fitness: 1.0});
    });
  });
}
