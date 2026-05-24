import 'package:ad_ranking_prototype/core/theme.dart';
import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/hive_event_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/location_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/mock_ad_repository.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_engine.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_bloc.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_bloc.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/view/feed_page.dart';
import 'package:ad_ranking_prototype/presentation/location/cubit/location_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(AdEventAdapter());
  final eventBox =
      await Hive.openBox<AdEvent>(HiveEventRepository.boxName);

  final adRepository = MockAdRepository();
  final eventRepository = HiveEventRepository(eventBox);
  const locationRepository = LocationRepository();

  runApp(AdRankingApp(
    adRepository: adRepository,
    eventRepository: eventRepository,
    locationRepository: locationRepository,
  ));
}

class AdRankingApp extends StatelessWidget {
  const AdRankingApp({
    super.key,
    required this.adRepository,
    required this.eventRepository,
    required this.locationRepository,
  });

  final AdRepository adRepository;
  final EventRepository eventRepository;
  final LocationRepository locationRepository;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LocationCubit(locationRepository),
        ),
        BlocProvider(
          create: (context) => FeedBloc(
            adRepository: adRepository,
            eventRepository: eventRepository,
            rankingEngine: const RankingEngine(),
            initialLocation: locationRepository.defaultLocation,
          )..add(const FeedRequested()),
        ),
        BlocProvider(
          create: (_) => AnalyticsBloc(eventRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Ad Ranking Prototype',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const FeedPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
