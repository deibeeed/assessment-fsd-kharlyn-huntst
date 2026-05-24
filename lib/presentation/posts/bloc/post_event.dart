import 'package:equatable/equatable.dart';

sealed class PostEvent extends Equatable {
  const PostEvent();
  @override
  List<Object?> get props => const [];
}

class PostRequested extends PostEvent {
  const PostRequested();
}
