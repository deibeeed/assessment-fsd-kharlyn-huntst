import 'package:ad_ranking_prototype/core/distance.dart';
import 'package:ad_ranking_prototype/core/theme.dart';
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AdCard extends StatelessWidget {
  const AdCard({
    super.key,
    required this.ad,
    required this.userLocation,
    required this.onTap,
  });

  final Ad ad;
  final UserLocation userLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceKm = haversineKm(
      userLocation.latitude,
      userLocation.longitude,
      ad.latitude,
      ad.longitude,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ad.imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: ad.imageUrl,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tierColor(ad.tier),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tierLabel(ad.tier),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ad.advertiserName,
                          style: theme.textTheme.labelMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Sponsored',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${distanceKm.toStringAsFixed(1)} km',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(ad.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    ad.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
