import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_bloc.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_state.dart';
import 'package:ad_ranking_prototype/presentation/feed/view/mixed_feed_view.dart';
import 'package:ad_ranking_prototype/presentation/location/cubit/location_cubit.dart';
import 'package:ad_ranking_prototype/presentation/location/view/location_picker.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_bloc.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationCubit, UserLocation>(
      listener: (context, loc) {
        context.read<FeedBloc>().add(FeedLocationChanged(loc));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Social Feed'),
          actions: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LocationPicker(),
            ),
          ],
        ),
        body: BlocBuilder<PostBloc, PostState>(
          builder: (context, postState) {
            return BlocBuilder<FeedBloc, FeedState>(
              builder: (context, feedState) {
                if (postState is PostLoading || postState is PostInitial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (postState is PostError) {
                  return Center(child: Text('Error: ${postState.message}'));
                }
                if (feedState is FeedError) {
                  return Center(child: Text('Error: ${feedState.message}'));
                }
                final posts =
                    postState is PostLoaded ? postState.posts : const <dynamic>[];
                final rankedAds =
                    feedState is FeedLoaded ? feedState.ads : const <dynamic>[];
                final userLocation = context.watch<LocationCubit>().state;
                return MixedFeedView(
                  posts: List.castFrom(posts),
                  rankedAds: List.castFrom(rankedAds),
                  userLocation: userLocation,
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Re-rank',
          onPressed: () =>
              context.read<FeedBloc>().add(const FeedRequested()),
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
