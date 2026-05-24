import 'package:ad_ranking_prototype/core/constants.dart';
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_bloc.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_bloc.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/view/ad_card.dart';
import 'package:ad_ranking_prototype/presentation/feed/view/post_card.dart';
import 'package:ad_ranking_prototype/presentation/reactions/cubit/reaction_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MixedFeedView extends StatelessWidget {
  const MixedFeedView({
    super.key,
    required this.posts,
    required this.rankedAds,
    required this.userLocation,
  });

  final List<Post> posts;
  final List<Ad> rankedAds;
  final UserLocation userLocation;

  /// Builds a flat list of items in render order. Pure function of inputs.
  /// Pattern: for every kPostsPerAd posts, append one ad (if any remain).
  /// After ads run out, remaining posts continue without empty gaps.
  List<Object> _buildItems() {
    final items = <Object>[];
    var adIndex = 0;
    for (var i = 0; i < posts.length; i++) {
      items.add(posts[i]);
      if ((i + 1) % kPostsPerAd == 0 && adIndex < rankedAds.length) {
        items.add(rankedAds[adIndex]);
        adIndex++;
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final likedIds = context.watch<ReactionCubit>().state;
    final items = _buildItems();
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<FeedBloc>().add(const FeedRequested()),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is Ad) {
            return VisibilityDetector(
              key: Key('ad-${item.id}'),
              onVisibilityChanged: (info) {
                if (info.visibleFraction > 0.5) {
                  context
                      .read<AnalyticsBloc>()
                      .add(ImpressionRecorded(item.id));
                }
              },
              child: AdCard(
                ad: item,
                userLocation: userLocation,
                onTap: () {
                  context.read<AnalyticsBloc>().add(ClickRecorded(item.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Clicked: ${item.title}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            );
          }
          final post = item as Post;
          final isLiked = likedIds.contains(post.id);
          return VisibilityDetector(
            key: Key('post-${post.id}'),
            onVisibilityChanged: (info) {
              if (info.visibleFraction > 0.5) {
                context
                    .read<AnalyticsBloc>()
                    .add(PostImpressionRecorded(post.id));
              }
            },
            child: PostCard(
              post: post,
              isLiked: isLiked,
              onToggleLike: () =>
                  context.read<ReactionCubit>().toggle(post.id),
            ),
          );
        },
      ),
    );
  }
}
