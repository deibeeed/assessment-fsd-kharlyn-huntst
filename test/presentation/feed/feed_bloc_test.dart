import 'dart:async';

import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_engine.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_bloc.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_state.dart';
import 'package:ad_ranking_prototype/presentation/interest/cubit/interest_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdRepository extends Mock implements AdRepository {}

class _MockEventRepository extends Mock implements EventRepository {}

class _MockInterestCubit extends Mock implements InterestCubit {}

void main() {
  late _MockAdRepository adRepo;
  late _MockEventRepository eventRepo;
  late _MockInterestCubit interestCubit;
  late StreamController<Map<Category, double>> interestStream;

  const manila = UserLocation(
    name: 'Manila',
    latitude: 14.5995,
    longitude: 120.9842,
  );
  const cebu = UserLocation(
    name: 'Cebu',
    latitude: 10.3157,
    longitude: 123.8854,
  );

  final ads = [
    const Ad(
      id: 'manila-gold',
      title: 'Manila Gold',
      description: '',
      advertiserName: '',
      tier: AdTier.gold,
      latitude: 14.5995,
      longitude: 120.9842,
      categories: [Category.food],
    ),
    const Ad(
      id: 'cebu-gold',
      title: 'Cebu Gold',
      description: '',
      advertiserName: '',
      tier: AdTier.gold,
      latitude: 10.3157,
      longitude: 123.8854,
      categories: [Category.coffee],
    ),
  ];

  setUp(() {
    adRepo = _MockAdRepository();
    eventRepo = _MockEventRepository();
    interestCubit = _MockInterestCubit();
    interestStream = StreamController<Map<Category, double>>.broadcast();
    when(() => adRepo.getAll()).thenAnswer((_) async => ads);
    when(() => eventRepo.getEventsSince(any()))
        .thenAnswer((_) async => <AdEvent>[]);
    when(() => interestCubit.stream).thenAnswer((_) => interestStream.stream);
    when(() => interestCubit.state).thenReturn(const {});
  });

  tearDown(() async {
    await interestStream.close();
  });

  FeedBloc build(UserLocation initial) => FeedBloc(
        adRepository: adRepo,
        eventRepository: eventRepo,
        rankingEngine: const RankingEngine(),
        initialLocation: initial,
        interestCubit: interestCubit,
      );

  blocTest<FeedBloc, FeedState>(
    'emits [Loading, Loaded] on FeedRequested',
    build: () => build(manila),
    act: (b) => b.add(const FeedRequested()),
    expect: () => [
      const FeedLoading(),
      isA<FeedLoaded>().having(
        (s) => s.ads.first.id,
        'first ad',
        'manila-gold',
      ),
    ],
  );

  blocTest<FeedBloc, FeedState>(
    're-ranks when location changes — Cebu user sees cebu-gold first',
    build: () => build(manila),
    act: (b) async {
      b.add(const FeedRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(const FeedLocationChanged(cebu));
    },
    skip: 2,
    expect: () => [
      const FeedLoading(),
      isA<FeedLoaded>().having(
        (s) => s.ads.first.id,
        'first ad after re-rank',
        'cebu-gold',
      ),
    ],
  );

  blocTest<FeedBloc, FeedState>(
    'emits FeedError when AdRepository throws',
    build: () {
      when(() => adRepo.getAll()).thenThrow(Exception('boom'));
      return build(manila);
    },
    act: (b) => b.add(const FeedRequested()),
    expect: () => [
      const FeedLoading(),
      isA<FeedError>(),
    ],
  );

  blocTest<FeedBloc, FeedState>(
    're-ranks when interest profile changes (coffee user sees cebu-gold first in Manila)',
    build: () => build(manila),
    act: (b) async {
      b.add(const FeedRequested());
      await Future<void>.delayed(Duration.zero);
      when(() => interestCubit.state).thenReturn(const {Category.coffee: 1.0});
      interestStream.add(const {Category.coffee: 1.0});
    },
    skip: 2,
    expect: () => [
      const FeedLoading(),
      isA<FeedLoaded>().having(
        (s) => s.ads.first.id,
        'first ad after interest change',
        'cebu-gold',
      ),
    ],
  );
}
