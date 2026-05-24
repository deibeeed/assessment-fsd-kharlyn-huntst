import 'package:ad_ranking_prototype/data/repositories/post_repository.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_event.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PostBloc extends Bloc<PostEvent, PostState> {
  PostBloc(this._repository) : super(const PostInitial()) {
    on<PostRequested>(_onRequested);
  }

  final PostRepository _repository;

  Future<void> _onRequested(PostRequested event, Emitter<PostState> emit) async {
    emit(const PostLoading());
    try {
      final posts = await _repository.getAll();
      emit(PostLoaded(posts));
    } catch (e) {
      emit(PostError(e.toString()));
    }
  }
}
