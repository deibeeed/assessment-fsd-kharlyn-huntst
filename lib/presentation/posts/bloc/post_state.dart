import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:equatable/equatable.dart';

sealed class PostState extends Equatable {
  const PostState();
  @override
  List<Object?> get props => const [];
}

class PostInitial extends PostState {
  const PostInitial();
}

class PostLoading extends PostState {
  const PostLoading();
}

class PostLoaded extends PostState {
  const PostLoaded(this.posts);
  final List<Post> posts;
  @override
  List<Object?> get props => [posts];
}

class PostError extends PostState {
  const PostError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
