import 'package:ad_ranking_prototype/data/models/post.dart';

abstract class PostRepository {
  Future<List<Post>> getAll();
}
