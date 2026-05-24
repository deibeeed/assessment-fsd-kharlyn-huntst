import 'dart:async';

import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/repositories/reaction_repository.dart';
import 'package:ad_ranking_prototype/domain/interest/interest_service.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_bloc.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_state.dart';
import 'package:ad_ranking_prototype/presentation/reactions/cubit/reaction_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InterestCubit extends Cubit<Map<Category, double>> {
  InterestCubit({
    required ReactionCubit reactionCubit,
    required PostBloc postBloc,
    required ReactionRepository reactionRepository,
    InterestService service = const InterestService(),
  })  : _reactionRepository = reactionRepository,
        _service = service,
        super(const {}) {
    final initialPostState = postBloc.state;
    if (initialPostState is PostLoaded) {
      _currentPosts = initialPostState.posts;
    }
    _reactionSub = reactionCubit.stream.listen(_onReactionsChanged);
    _postSub = postBloc.stream.listen(_onPostStateChanged);
  }

  final ReactionRepository _reactionRepository;
  final InterestService _service;
  List<Post> _currentPosts = const [];
  StreamSubscription<Set<String>>? _reactionSub;
  StreamSubscription<PostState>? _postSub;

  Future<void> _onReactionsChanged(Set<String> _) async {
    await _recompute();
  }

  Future<void> _onPostStateChanged(PostState state) async {
    if (state is PostLoaded) {
      _currentPosts = state.posts;
      await _recompute();
    }
  }

  Future<void> _recompute() async {
    if (_currentPosts.isEmpty) {
      emit(const {});
      return;
    }
    final likes = await _reactionRepository.getAllLikes();
    if (likes.isEmpty) {
      emit(const {});
      return;
    }
    emit(_service.computeProfile(
      likes: likes,
      postsCatalog: _currentPosts,
    ));
  }

  @override
  Future<void> close() async {
    await _reactionSub?.cancel();
    await _postSub?.cancel();
    return super.close();
  }
}
