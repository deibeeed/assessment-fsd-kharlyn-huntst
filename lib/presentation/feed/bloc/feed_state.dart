import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:equatable/equatable.dart';

sealed class FeedState extends Equatable {
  const FeedState();
  @override
  List<Object?> get props => const [];
}

class FeedInitial extends FeedState {
  const FeedInitial();
}

class FeedLoading extends FeedState {
  const FeedLoading();
}

class FeedLoaded extends FeedState {
  const FeedLoaded(this.ads);
  final List<Ad> ads;
  @override
  List<Object?> get props => [ads];
}

class FeedError extends FeedState {
  const FeedError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
