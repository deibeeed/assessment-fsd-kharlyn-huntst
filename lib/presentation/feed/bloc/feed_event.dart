import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:equatable/equatable.dart';

sealed class FeedEvent extends Equatable {
  const FeedEvent();
  @override
  List<Object?> get props => const [];
}

class FeedRequested extends FeedEvent {
  const FeedRequested();
}

class FeedLocationChanged extends FeedEvent {
  const FeedLocationChanged(this.location);
  final UserLocation location;
  @override
  List<Object?> get props => [location];
}
