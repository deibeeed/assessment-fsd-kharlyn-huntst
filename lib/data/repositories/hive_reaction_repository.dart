import 'dart:async';

import 'package:ad_ranking_prototype/data/models/post_like.dart';
import 'package:ad_ranking_prototype/data/repositories/reaction_repository.dart';
import 'package:hive/hive.dart';

class HiveReactionRepository implements ReactionRepository {
  HiveReactionRepository(this._box) {
    _controller = StreamController<Set<String>>.broadcast(
      onListen: _emitCurrent,
    );
  }

  static const String boxName = 'post_likes';

  final Box<PostLike> _box;
  late final StreamController<Set<String>> _controller;

  void _emitCurrent() {
    _controller.add(_box.keys.cast<String>().toSet());
  }

  @override
  Future<void> like(String postId) async {
    await _box.put(
      postId,
      PostLike(postId: postId, likedAt: DateTime.now()),
    );
    _emitCurrent();
  }

  @override
  Future<void> unlike(String postId) async {
    await _box.delete(postId);
    _emitCurrent();
  }

  @override
  Future<List<PostLike>> getAllLikes() async => _box.values.toList();

  @override
  Stream<Set<String>> likedPostIds() => _controller.stream;
}
