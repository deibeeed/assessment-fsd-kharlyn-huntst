import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/models/post_like.dart';

class InterestService {
  const InterestService();

  Map<Category, double> computeProfile({
    required List<PostLike> likes,
    required List<Post> postsCatalog,
  }) {
    if (likes.isEmpty) return const {};

    final postById = {for (final p in postsCatalog) p.id: p};
    final counts = <Category, int>{};

    for (final like in likes) {
      final post = postById[like.postId];
      if (post == null) continue;
      for (final cat in post.categories) {
        counts.update(cat, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    final total = counts.values.fold<int>(0, (acc, v) => acc + v);
    if (total == 0) return const {};

    return {for (final entry in counts.entries) entry.key: entry.value / total};
  }
}
