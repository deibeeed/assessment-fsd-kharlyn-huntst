import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_bloc.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_bloc.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_state.dart';
import 'package:ad_ranking_prototype/presentation/feed/view/ad_card.dart';
import 'package:ad_ranking_prototype/presentation/location/cubit/location_cubit.dart';
import 'package:ad_ranking_prototype/presentation/location/view/location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
          title: const Text('Ad Feed'),
          actions: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LocationPicker(),
            ),
          ],
        ),
        body: BlocBuilder<FeedBloc, FeedState>(
          builder: (context, state) {
            return switch (state) {
              FeedInitial() ||
              FeedLoading() =>
                const Center(child: CircularProgressIndicator()),
              FeedError(message: final msg) =>
                Center(child: Text('Error: $msg')),
              FeedLoaded(ads: final ads) => _FeedList(ads: ads),
            };
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

class _FeedList extends StatelessWidget {
  const _FeedList({required this.ads});
  final List<Ad> ads;

  @override
  Widget build(BuildContext context) {
    final userLocation = context.watch<LocationCubit>().state;
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<FeedBloc>().add(const FeedRequested()),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: ads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final ad = ads[index];
          return VisibilityDetector(
            key: Key('ad-${ad.id}'),
            onVisibilityChanged: (info) {
              if (info.visibleFraction > 0.5) {
                context
                    .read<AnalyticsBloc>()
                    .add(ImpressionRecorded(ad.id));
              }
            },
            child: AdCard(
              ad: ad,
              userLocation: userLocation,
              onTap: () {
                context.read<AnalyticsBloc>().add(ClickRecorded(ad.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Clicked: ${ad.title}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
