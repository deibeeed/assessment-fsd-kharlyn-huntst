import 'package:equatable/equatable.dart';

class PostLike extends Equatable {
  const PostLike({required this.postId, required this.likedAt});

  final String postId;
  final DateTime likedAt;

  @override
  List<Object?> get props => [postId, likedAt];
}
