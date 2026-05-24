import 'dart:async';

import 'package:ad_ranking_prototype/core/constants.dart';
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_engine.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_state.dart';
import 'package:ad_ranking_prototype/presentation/interest/cubit/interest_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({
    required AdRepository adRepository,
    required EventRepository eventRepository,
    required RankingEngine rankingEngine,
    required UserLocation initialLocation,
    required InterestCubit interestCubit,
  })  : _adRepository = adRepository,
        _eventRepository = eventRepository,
        _rankingEngine = rankingEngine,
        _interestCubit = interestCubit,
        _currentLocation = initialLocation,
        super(const FeedInitial()) {
    on<FeedRequested>(_onRequested);
    on<FeedLocationChanged>(_onLocationChanged);
    _interestSub = interestCubit.stream.listen(_onInterestChanged);
  }

  final AdRepository _adRepository;
  final EventRepository _eventRepository;
  final RankingEngine _rankingEngine;
  final InterestCubit _interestCubit;
  UserLocation _currentLocation;
  StreamSubscription<Map<Category, double>>? _interestSub;

  void _onInterestChanged(Map<Category, double> _) {
    add(const FeedRequested());
  }

  Future<void> _onRequested(FeedRequested event, Emitter<FeedState> emit) async {
    emit(const FeedLoading());
    try {
      final now = DateTime.now();
      final ads = await _adRepository.getAll();
      final events = await _eventRepository.getEventsSince(
        now.subtract(kImpressionDecayWindow),
      );
      final ranked = _rankingEngine.rank(
        ads: ads,
        userLocation: _currentLocation,
        events: events,
        now: now,
        interestProfile: _interestCubit.state,
        limit: kFeedSize,
      );
      emit(FeedLoaded(ranked));
    } catch (e) {
      emit(FeedError(e.toString()));
    }
  }

  Future<void> _onLocationChanged(
    FeedLocationChanged event,
    Emitter<FeedState> emit,
  ) async {
    _currentLocation = event.location;
    add(const FeedRequested());
  }

  @override
  Future<void> close() async {
    await _interestSub?.cancel();
    return super.close();
  }
}
