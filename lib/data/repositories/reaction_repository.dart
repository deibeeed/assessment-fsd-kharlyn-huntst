import 'package:ad_ranking_prototype/data/models/post_like.dart';

abstract class ReactionRepository {
  Future<void> like(String postId);
  Future<void> unlike(String postId);
  Future<List<PostLike>> getAllLikes();
  Stream<Set<String>> likedPostIds();
}
