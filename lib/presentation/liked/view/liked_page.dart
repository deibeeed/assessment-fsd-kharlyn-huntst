import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/presentation/feed/view/post_card.dart';
import 'package:ad_ranking_prototype/presentation/interest/cubit/interest_cubit.dart';
import 'package:ad_ranking_prototype/presentation/location/view/location_picker.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_bloc.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_state.dart';
import 'package:ad_ranking_prototype/presentation/reactions/cubit/reaction_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LikedPage extends StatelessWidget {
  const LikedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final likedIds = context.watch<ReactionCubit>().state;
    final profile = context.watch<InterestCubit>().state;
    final postState = context.watch<PostBloc>().state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liked'),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LocationPicker(),
          ),
        ],
      ),
      body: switch (postState) {
        PostInitial() ||
        PostLoading() =>
          const Center(child: CircularProgressIndicator()),
        PostError(message: final m) =>
          Center(child: Text('Error: $m')),
        PostLoaded(posts: final all) => _LikedBody(
            allPosts: all,
            likedIds: likedIds,
            profile: profile,
          ),
      },
    );
  }
}

class _LikedBody extends StatelessWidget {
  const _LikedBody({
    required this.allPosts,
    required this.likedIds,
    required this.profile,
  });

  final List<Post> allPosts;
  final Set<String> likedIds;
  final Map<Category, double> profile;

  @override
  Widget build(BuildContext context) {
    if (likedIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_outline,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Tap hearts on the Home tab to start training the ad ranker.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    final liked = allPosts.where((p) => likedIds.contains(p.id)).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: liked.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return _InterestChipStrip(profile: profile);
        final post = liked[index - 1];
        return PostCard(
          post: post,
          isLiked: true,
          onToggleLike: () => context.read<ReactionCubit>().toggle(post.id),
        );
      },
    );
  }
}

class _InterestChipStrip extends StatelessWidget {
  const _InterestChipStrip({required this.profile});
  final Map<Category, double> profile;

  @override
  Widget build(BuildContext context) {
    if (profile.isEmpty) return const SizedBox.shrink();

    final entries = profile.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your interest profile',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        e.key.icon,
                        size: 16,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${e.key.displayName} · ${(e.value * 100).round()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
