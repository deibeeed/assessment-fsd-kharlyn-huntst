import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_event.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnalyticsState extends Equatable {
  const AnalyticsState({
    this.impressionsByAd = const {},
    this.clicksByAd = const {},
  });

  final Map<String, int> impressionsByAd;
  final Map<String, int> clicksByAd;

  AnalyticsState copyWith({
    Map<String, int>? impressionsByAd,
    Map<String, int>? clicksByAd,
  }) {
    return AnalyticsState(
      impressionsByAd: impressionsByAd ?? this.impressionsByAd,
      clicksByAd: clicksByAd ?? this.clicksByAd,
    );
  }

  @override
  List<Object?> get props => [impressionsByAd, clicksByAd];
}

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  AnalyticsBloc(this._repository) : super(const AnalyticsState()) {
    on<ImpressionRecorded>(_onImpression);
    on<ClickRecorded>(_onClick);
  }

  final EventRepository _repository;

  Future<void> _onImpression(
    ImpressionRecorded event,
    Emitter<AnalyticsState> emit,
  ) async {
    await _repository.recordImpression(event.adId);
    final next = Map<String, int>.from(state.impressionsByAd);
    next.update(event.adId, (v) => v + 1, ifAbsent: () => 1);
    emit(state.copyWith(impressionsByAd: next));
  }

  Future<void> _onClick(
    ClickRecorded event,
    Emitter<AnalyticsState> emit,
  ) async {
    await _repository.recordClick(event.adId);
    final next = Map<String, int>.from(state.clicksByAd);
    next.update(event.adId, (v) => v + 1, ifAbsent: () => 1);
    emit(state.copyWith(clicksByAd: next));
  }
}
