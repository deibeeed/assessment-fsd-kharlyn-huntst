import 'dart:math' as math;

import 'package:ad_ranking_prototype/core/constants.dart';
import 'package:ad_ranking_prototype/core/distance.dart';
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_weights.dart';

class RankingEngine {
  const RankingEngine({this.weights = RankingWeights.defaultWeights});

  final RankingWeights weights;

  List<Ad> rank({
    required List<Ad> ads,
    required UserLocation userLocation,
    required List<AdEvent> events,
    required DateTime now,
    Map<Category, double> interestProfile = const {},
    int? limit,
  }) {
    if (ads.isEmpty) return const [];

    final decayCutoff = now.subtract(kImpressionDecayWindow);
    final starvationCutoff = now.subtract(kStarvationWindow);

    final recentImpressionsByAd = <String, int>{};
    final lastShownByAd = <String, DateTime>{};
    for (final e in events) {
      if (e.type == EventType.impression) {
        if (!e.timestamp.isBefore(decayCutoff)) {
          recentImpressionsByAd.update(
            e.adId,
            (n) => n + 1,
            ifAbsent: () => 1,
          );
        }
        final prev = lastShownByAd[e.adId];
        if (prev == null || e.timestamp.isAfter(prev)) {
          lastShownByAd[e.adId] = e.timestamp;
        }
      }
    }

    final scored = ads.map((ad) {
      final distance = haversineKm(
        userLocation.latitude,
        userLocation.longitude,
        ad.latitude,
        ad.longitude,
      );
      final proximityScore =
          math.max(0.0, 1.0 - distance / kMaxProximityKm);
      final recentImpressions = recentImpressionsByAd[ad.id] ?? 0;
      final lastShown = lastShownByAd[ad.id];
      final isStarved =
          lastShown == null || lastShown.isBefore(starvationCutoff);

      final interestSum = ad.categories.fold<double>(
        0.0,
        (acc, cat) => acc + (interestProfile[cat] ?? 0.0),
      );
      final interestMatch = math.min(1.0, interestSum);

      final score = weights.tier * ad.tier.weight +
          weights.proximity * proximityScore +
          weights.interest * interestMatch -
          weights.decay * recentImpressions +
          (isStarved ? weights.starvation : 0.0);

      return _ScoredAd(ad: ad, score: score);
    }).toList();

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.ad.id.compareTo(b.ad.id);
    });

    final ranked = scored.map((s) => s.ad).toList();
    if (limit != null && ranked.length > limit) {
      return ranked.sublist(0, limit);
    }
    return ranked;
  }
}

class _ScoredAd {
  const _ScoredAd({required this.ad, required this.score});
  final Ad ad;
  final double score;
}
