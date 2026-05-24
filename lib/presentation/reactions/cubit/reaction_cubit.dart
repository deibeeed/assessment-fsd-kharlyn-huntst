import 'dart:async';

import 'package:ad_ranking_prototype/data/repositories/reaction_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReactionCubit extends Cubit<Set<String>> {
  ReactionCubit(this._repository) : super(const {}) {
    _init();
  }

  final ReactionRepository _repository;
  StreamSubscription<Set<String>>? _sub;

  Future<void> _init() async {
    final initial = await _repository.getAllLikes();
    final ids = initial.map((l) => l.postId).toSet();
    if (ids.isNotEmpty) emit(ids);
    _sub = _repository.likedPostIds().listen(emit);
  }

  Future<void> toggle(String postId) async {
    if (state.contains(postId)) {
      await _repository.unlike(postId);
    } else {
      await _repository.like(postId);
    }
  }

  bool isLiked(String postId) => state.contains(postId);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
