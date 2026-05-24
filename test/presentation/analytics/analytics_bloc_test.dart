import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_bloc.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_event.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockEventRepository extends Mock implements EventRepository {}

void main() {
  late _MockEventRepository repo;

  setUp(() {
    repo = _MockEventRepository();
    when(() => repo.recordImpression(any())).thenAnswer((_) async {});
    when(() => repo.recordClick(any())).thenAnswer((_) async {});
  });

  blocTest<AnalyticsBloc, AnalyticsState>(
    'calls recordImpression and increments counter',
    build: () => AnalyticsBloc(repo),
    act: (b) => b.add(const ImpressionRecorded('ad-1')),
    verify: (_) {
      verify(() => repo.recordImpression('ad-1')).called(1);
    },
    expect: () => [
      const AnalyticsState(impressionsByAd: {'ad-1': 1}),
    ],
  );

  blocTest<AnalyticsBloc, AnalyticsState>(
    'calls recordClick and increments counter',
    build: () => AnalyticsBloc(repo),
    act: (b) => b.add(const ClickRecorded('ad-2')),
    verify: (_) {
      verify(() => repo.recordClick('ad-2')).called(1);
    },
    expect: () => [
      const AnalyticsState(clicksByAd: {'ad-2': 1}),
    ],
  );

  blocTest<AnalyticsBloc, AnalyticsState>(
    'increments per ad across multiple impressions',
    build: () => AnalyticsBloc(repo),
    act: (b) {
      b.add(const ImpressionRecorded('ad-1'));
      b.add(const ImpressionRecorded('ad-1'));
      b.add(const ImpressionRecorded('ad-2'));
    },
    expect: () => [
      const AnalyticsState(impressionsByAd: {'ad-1': 1}),
      const AnalyticsState(impressionsByAd: {'ad-1': 2}),
      const AnalyticsState(impressionsByAd: {'ad-1': 2, 'ad-2': 1}),
    ],
  );
}
