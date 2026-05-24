import 'package:ad_ranking_prototype/core/theme.dart';
import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:ad_ranking_prototype/data/models/ad_event_adapter.dart';
import 'package:ad_ranking_prototype/data/models/post_like.dart';
import 'package:ad_ranking_prototype/data/models/post_like_adapter.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/hive_event_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/hive_reaction_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/location_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/mock_ad_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/mock_post_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/post_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/reaction_repository.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_engine.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_bloc.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_bloc.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/shell/root_shell.dart';
import 'package:ad_ranking_prototype/presentation/interest/cubit/interest_cubit.dart';
import 'package:ad_ranking_prototype/presentation/location/cubit/location_cubit.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_bloc.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_event.dart';
import 'package:ad_ranking_prototype/presentation/reactions/cubit/reaction_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(AdEventAdapter());
  Hive.registerAdapter(PostLikeAdapter());
  final adEventBox = await Hive.openBox<AdEvent>(
    HiveEventRepository.adEventBoxName,
  );
  final postEventBox = await Hive.openBox<AdEvent>(
    HiveEventRepository.postEventBoxName,
  );
  final reactionBox =
      await Hive.openBox<PostLike>(HiveReactionRepository.boxName);

  final adRepository = MockAdRepository();
  final eventRepository = HiveEventRepository(
    adEventBox: adEventBox,
    postEventBox: postEventBox,
  );
  const locationRepository = LocationRepository();
  final postRepository = MockPostRepository();
  final reactionRepository = HiveReactionRepository(reactionBox);

  runApp(AdRankingApp(
    adRepository: adRepository,
    eventRepository: eventRepository,
    locationRepository: locationRepository,
    postRepository: postRepository,
    reactionRepository: reactionRepository,
  ));
}

class AdRankingApp extends StatelessWidget {
  const AdRankingApp({
    super.key,
    required this.adRepository,
    required this.eventRepository,
    required this.locationRepository,
    required this.postRepository,
    required this.reactionRepository,
  });

  final AdRepository adRepository;
  final EventRepository eventRepository;
  final LocationRepository locationRepository;
  final PostRepository postRepository;
  final ReactionRepository reactionRepository;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LocationCubit(locationRepository),
        ),
        BlocProvider(
          create: (_) => PostBloc(postRepository)..add(const PostRequested()),
        ),
        BlocProvider(
          create: (_) => ReactionCubit(reactionRepository),
        ),
        BlocProvider(
          create: (context) => InterestCubit(
            reactionCubit: context.read<ReactionCubit>(),
            postBloc: context.read<PostBloc>(),
            reactionRepository: reactionRepository,
          ),
        ),
        BlocProvider(
          create: (context) => FeedBloc(
            adRepository: adRepository,
            eventRepository: eventRepository,
            rankingEngine: const RankingEngine(),
            initialLocation: locationRepository.defaultLocation,
            interestCubit: context.read<InterestCubit>(),
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
        home: const RootShell(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
