import 'package:ad_ranking_prototype/core/avatar.dart';
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.isLiked,
    required this.onToggleLike,
  });

  final Post post;
  final bool isLiked;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseLikes = (post.id.hashCode.abs() % 500) + 10;
    final displayedLikes = baseLikes + (isLiked ? 1 : 0);
    final timeAgo = _relativeTime(post.timestamp);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: avatarColor(post.authorName),
                  child: Text(
                    avatarInitial(post.authorName),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName, style: theme.textTheme.titleSmall),
                      Text(
                        '${post.authorHandle} · $timeAgo',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final c in post.categories)
                      _CategoryChip(category: c),
                  ],
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: CachedNetworkImage(
              imageUrl: post.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, _) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (context, _, __) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.image_not_supported_outlined,
                    color: theme.colorScheme.outline),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnimatedHeart(isLiked: isLiked, onTap: onToggleLike),
                const SizedBox(height: 6),
                Text(
                  '$displayedLikes likes',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${_handleWithoutAt(post.authorHandle)} ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: post.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _handleWithoutAt(String h) =>
      h.startsWith('@') ? h.substring(1) : h;

  static String _relativeTime(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        category.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _AnimatedHeart extends StatelessWidget {
  const _AnimatedHeart({required this.isLiked, required this.onTap});
  final bool isLiked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          isLiked ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(isLiked),
          color: isLiked ? Colors.red : Theme.of(context).colorScheme.outline,
          size: 28,
        ),
      ),
    );
  }
}
