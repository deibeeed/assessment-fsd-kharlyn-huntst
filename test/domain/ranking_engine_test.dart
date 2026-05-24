import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Manila as the reference user location.
  const userManila = UserLocation(
    name: 'Manila',
    latitude: 14.5995,
    longitude: 120.9842,
  );

  // Three ads at the SAME location as the user (proximity = 1 for all).
  Ad ad(String id, AdTier tier, {double? lat, double? lng}) => Ad(
        id: id,
        title: id,
        description: '',
        advertiserName: id,
        tier: tier,
        latitude: lat ?? userManila.latitude,
        longitude: lng ?? userManila.longitude,
      );

  const engine = RankingEngine();
  final now = DateTime(2026, 5, 24, 12, 0, 0);

  group('RankingEngine.rank', () {
    test('returns empty list for empty input', () {
      final out = engine.rank(
        ads: const [],
        userLocation: userManila,
        events: const [],
        now: now,
      );
      expect(out, isEmpty);
    });

    test('Gold > Silver > Bronze when all else equal (same location, no events)',
        () {
      final out = engine.rank(
        ads: [ad('B', AdTier.bronze), ad('G', AdTier.gold), ad('S', AdTier.silver)],
        userLocation: userManila,
        events: const [],
        now: now,
      );
      expect(out.map((a) => a.id).toList(), ['G', 'S', 'B']);
    });

    test('closer ad of same tier outranks farther ad', () {
      // Cebu is ~570 km from Manila — proximity score ~= 0.
      final out = engine.rank(
        ads: [
          ad('FAR', AdTier.silver, lat: 10.3157, lng: 123.8854),
          ad('NEAR', AdTier.silver),
        ],
        userLocation: userManila,
        events: const [],
        now: now,
      );
      expect(out.map((a) => a.id).toList(), ['NEAR', 'FAR']);
    });

    test('distant Gold with 3 recent impressions loses to fresh nearby Silver',
        () {
      // Gold in Cebu, 3 impressions in last 10 min:
      //   tier 30 + prox ~0 - decay 6 = ~24
      // Silver in Manila, no events:
      //   tier 20 + prox 8 = 28
      final ads = [
        ad('GOLD_FAR', AdTier.gold, lat: 10.3157, lng: 123.8854),
        ad('SILVER_NEAR', AdTier.silver),
      ];
      final events = List.generate(
        3,
        (i) => AdEvent(
          adId: 'GOLD_FAR',
          type: EventType.impression,
          timestamp: now.subtract(Duration(minutes: i + 1)),
        ),
      );
      final out = engine.rank(
        ads: ads,
        userLocation: userManila,
        events: events,
        now: now,
      );
      expect(out.map((a) => a.id).toList(), ['SILVER_NEAR', 'GOLD_FAR']);
    });

    test('Bronze with starvation beats Gold with 8+ recent impressions at same location',
        () {
      // Gold: 30 - (8 * 2) = 14
      // Bronze (unshown 5+ min ago): 10 + 5 = 15
      final ads = [
        ad('GOLD', AdTier.gold),
        ad('BRONZE', AdTier.bronze),
      ];
      final events = List.generate(
        8,
        (i) => AdEvent(
          adId: 'GOLD',
          type: EventType.impression,
          timestamp: now.subtract(Duration(seconds: 10 * (i + 1))),
        ),
      );
      final out = engine.rank(
        ads: ads,
        userLocation: userManila,
        events: events,
        now: now,
      );
      expect(out.map((a) => a.id).toList(), ['BRONZE', 'GOLD']);
    });

    test('all ads outside MAX_KM still rank deterministically by tier', () {
      // All ads in Cebu (~570 km from Manila) — proximity = 0 for all.
      final ads = [
        ad('B', AdTier.bronze, lat: 10.3157, lng: 123.8854),
        ad('G', AdTier.gold, lat: 10.3157, lng: 123.8854),
        ad('S', AdTier.silver, lat: 10.3157, lng: 123.8854),
      ];
      final out = engine.rank(
        ads: ads,
        userLocation: userManila,
        events: const [],
        now: now,
      );
      expect(out.map((a) => a.id).toList(), ['G', 'S', 'B']);
    });

    test('identical scores break ties by ad id ascending', () {
      // Two identical Silver ads at user location with no events.
      final out = engine.rank(
        ads: [ad('Z', AdTier.silver), ad('A', AdTier.silver)],
        userLocation: userManila,
        events: const [],
        now: now,
      );
      expect(out.map((a) => a.id).toList(), ['A', 'Z']);
    });

    test('only impressions inside decay window are counted', () {
      // Two Gold ads at same location. AD1 has 3 impressions OUTSIDE window
      // (should not penalize). AD2 has 3 impressions INSIDE window.
      final ads = [ad('AD1', AdTier.gold), ad('AD2', AdTier.gold)];
      final events = [
        ...List.generate(
          3,
          (i) => AdEvent(
            adId: 'AD1',
            type: EventType.impression,
            timestamp: now.subtract(Duration(minutes: 30 + i)),
          ),
        ),
        ...List.generate(
          3,
          (i) => AdEvent(
            adId: 'AD2',
            type: EventType.impression,
            timestamp: now.subtract(Duration(minutes: i + 1)),
          ),
        ),
      ];
      final out = engine.rank(
        ads: ads,
        userLocation: userManila,
        events: events,
        now: now,
      );
      expect(out.map((a) => a.id).toList(), ['AD1', 'AD2']);
    });

    test('clicks do not contribute to impression decay', () {
      // AD1: 5 clicks (should not penalize)
      // AD2: 3 impressions (should penalize by 6)
      final ads = [ad('AD1', AdTier.gold), ad('AD2', AdTier.gold)];
      final events = [
        ...List.generate(
          5,
          (i) => AdEvent(
            adId: 'AD1',
            type: EventType.click,
            timestamp: now.subtract(Duration(minutes: i + 1)),
          ),
        ),
        ...List.generate(
          3,
          (i) => AdEvent(
            adId: 'AD2',
            type: EventType.impression,
            timestamp: now.subtract(Duration(minutes: i + 1)),
          ),
        ),
      ];
      final out = engine.rank(
        ads: ads,
        userLocation: userManila,
        events: events,
        now: now,
      );
      expect(out.map((a) => a.id).toList(), ['AD1', 'AD2']);
    });

    test('interest_match boosts a matching ad above a higher-tier ad in a distant city', () {
      final ads = [
        Ad(
          id: 'COFFEE_NEAR',
          title: '',
          description: '',
          advertiserName: '',
          tier: AdTier.silver,
          latitude: userManila.latitude,
          longitude: userManila.longitude,
          categories: const [Category.coffee],
        ),
        const Ad(
          id: 'NOCAT_FAR',
          title: '',
          description: '',
          advertiserName: '',
          tier: AdTier.gold,
          latitude: 10.3157,
          longitude: 123.8854,
        ),
      ];
      final out = engine.rank(
        ads: ads,
        userLocation: userManila,
        events: const [],
        now: now,
        interestProfile: const {Category.coffee: 1.0},
      );
      expect(out.map((a) => a.id).toList(), ['COFFEE_NEAR', 'NOCAT_FAR']);
    });

    test('multi-category overlap caps interest_match at 1.0', () {
      final ads = [
        Ad(
          id: 'MULTI',
          title: '',
          description: '',
          advertiserName: '',
          tier: AdTier.bronze,
          latitude: userManila.latitude,
          longitude: userManila.longitude,
          categories: const [Category.food, Category.coffee],
        ),
        Ad(
          id: 'NOCAT',
          title: '',
          description: '',
          advertiserName: '',
          tier: AdTier.bronze,
          latitude: userManila.latitude,
          longitude: userManila.longitude,
        ),
      ];
      final out = engine.rank(
        ads: ads,
        userLocation: userManila,
        events: const [],
        now: now,
        interestProfile: const {Category.food: 0.6, Category.coffee: 0.6},
      );
      expect(out.first.id, 'MULTI');
    });

    test('empty interestProfile is identical to v1 behavior', () {
      final out = engine.rank(
        ads: [ad('B', AdTier.bronze), ad('G', AdTier.gold), ad('S', AdTier.silver)],
        userLocation: userManila,
        events: const [],
        now: now,
        interestProfile: const {},
      );
      expect(out.map((a) => a.id).toList(), ['G', 'S', 'B']);
    });
  });
}
