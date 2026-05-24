# Ad Ranking & Delivery Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter prototype that ranks advertiser ads by tier + proximity with fairness, displays them in a scrollable feed, and logs impressions/clicks — completed in 3–4 hours.

**Architecture:** Three-layer Flutter app (presentation/domain/data). `RankingEngine` is a pure Dart function in the domain layer (no Flutter, no IO). `flutter_bloc` for state management. `Hive` for cross-platform event persistence. No real backend — repositories are abstract with mocked implementations.

**Tech Stack:** Flutter (stable), Dart 3, Material 3, `flutter_bloc`, `hive` + `hive_flutter`, `equatable`, `visibility_detector`, `bloc_test`, `mocktail`.

**Source spec:** `docs/superpowers/specs/2026-05-24-ad-ranking-prototype-design.md`

---

## File Structure

```
lib/
  core/
    theme.dart                      # Material 3 ThemeData + tier color helper
    constants.dart                  # MAX_KM, time windows, default mock location
    distance.dart                   # Haversine helper (pure)
  data/
    models/
      ad.dart                       # Ad + AdTier enum
      ad_event.dart                 # AdEvent + EventType enum + Hive adapter
      user_location.dart            # UserLocation
    repositories/
      ad_repository.dart            # abstract
      mock_ad_repository.dart       # ~10 hardcoded ads across PH cities
      event_repository.dart         # abstract
      hive_event_repository.dart    # Hive impl
      location_repository.dart      # in-memory list of mock locations
  domain/
    ranking/
      ranking_weights.dart          # W_tier, W_prox, W_decay, W_starve
      ranking_engine.dart           # pure rank() function
  presentation/
    feed/
      bloc/
        feed_event.dart
        feed_state.dart
        feed_bloc.dart
      view/
        feed_page.dart
        ad_card.dart
    location/
      cubit/location_cubit.dart
      view/location_picker.dart
    analytics/
      bloc/
        analytics_event.dart
        analytics_bloc.dart
  main.dart

test/
  domain/
    ranking_engine_test.dart        # Tier 1 — must-have
    distance_test.dart              # one happy-path test
  presentation/
    feed/feed_bloc_test.dart        # Tier 2 — must-have
    analytics/analytics_bloc_test.dart  # Tier 2 — must-have

README.md                           # architecture + ranking + scale + AI usage
```

---

## Task 1: Project bootstrap

**Files:**
- Create: `pubspec.yaml`, `lib/main.dart`, `.gitignore`, `analysis_options.yaml` (via `flutter create`)
- Create: `docs/superpowers/specs/...` (already exists)

- [ ] **Step 1: Initialize git repo**

Run from project root (`/Users/deibeeed/Projects/assessment_fsd_kharlyn_huntst`):

```bash
git init
git add docs/
git commit -m "docs: add design spec and implementation plan"
```

- [ ] **Step 2: Create Flutter project in current directory**

```bash
flutter create --project-name ad_ranking_prototype --org com.kharlyn.assessment --platforms=ios,android,web .
```

Expected: scaffolds `lib/`, `pubspec.yaml`, `test/`, platform dirs.

- [ ] **Step 3: Add dependencies to `pubspec.yaml`**

In the `dependencies:` section (replace the current block):

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  visibility_detector: ^0.4.0+2
```

In the `dev_dependencies:` section:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  bloc_test: ^9.1.7
  mocktail: ^1.0.4
```

- [ ] **Step 4: Install dependencies**

```bash
flutter pub get
```

Expected: "Got dependencies!" with no errors.

- [ ] **Step 5: Verify default app runs**

```bash
flutter test
```

Expected: default counter widget test passes.

- [ ] **Step 6: Commit bootstrap**

```bash
git add .
git commit -m "chore: bootstrap Flutter project with bloc, hive, test deps"
```

---

## Task 2: Domain models — Ad, AdTier, UserLocation

**Files:**
- Create: `lib/data/models/ad.dart`
- Create: `lib/data/models/user_location.dart`

- [ ] **Step 1: Write `Ad` and `AdTier` model**

Create `lib/data/models/ad.dart`:

```dart
import 'package:equatable/equatable.dart';

enum AdTier {
  gold,
  silver,
  bronze;

  int get weight => switch (this) {
        AdTier.gold => 3,
        AdTier.silver => 2,
        AdTier.bronze => 1,
      };
}

class Ad extends Equatable {
  const Ad({
    required this.id,
    required this.title,
    required this.description,
    required this.advertiserName,
    required this.tier,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String title;
  final String description;
  final String advertiserName;
  final AdTier tier;
  final double latitude;
  final double longitude;

  @override
  List<Object?> get props =>
      [id, title, description, advertiserName, tier, latitude, longitude];
}
```

- [ ] **Step 2: Write `UserLocation` model**

Create `lib/data/models/user_location.dart`:

```dart
import 'package:equatable/equatable.dart';

class UserLocation extends Equatable {
  const UserLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [name, latitude, longitude];
}
```

- [ ] **Step 3: Verify it compiles**

```bash
flutter analyze lib/data/models/
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/data/models/
git commit -m "feat(domain): add Ad, AdTier, UserLocation models"
```

---

## Task 3: Distance helper (haversine) — TDD

**Files:**
- Test: `test/domain/distance_test.dart`
- Create: `lib/core/distance.dart`

- [ ] **Step 1: Write failing test**

Create `test/domain/distance_test.dart`:

```dart
import 'package:ad_ranking_prototype/core/distance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('haversineKm', () {
    test('returns 0 for identical coordinates', () {
      expect(haversineKm(14.5995, 120.9842, 14.5995, 120.9842), 0);
    });

    test('returns ~570 km for Manila to Cebu', () {
      // Manila: 14.5995, 120.9842; Cebu: 10.3157, 123.8854
      final d = haversineKm(14.5995, 120.9842, 10.3157, 123.8854);
      expect(d, closeTo(570, 20));
    });
  });
}
```

- [ ] **Step 2: Run test, verify failure**

```bash
flutter test test/domain/distance_test.dart
```

Expected: FAIL — file `lib/core/distance.dart` does not exist.

- [ ] **Step 3: Implement `haversineKm`**

Create `lib/core/distance.dart`:

```dart
import 'dart:math' as math;

const double _earthRadiusKm = 6371.0;

double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusKm * c;
}

double _toRad(double deg) => deg * math.pi / 180.0;
```

- [ ] **Step 4: Run test, verify pass**

```bash
flutter test test/domain/distance_test.dart
```

Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/distance.dart test/domain/distance_test.dart
git commit -m "feat(core): add haversineKm distance helper with tests"
```

---

## Task 4: Ranking weights + constants

**Files:**
- Create: `lib/core/constants.dart`
- Create: `lib/domain/ranking/ranking_weights.dart`

- [ ] **Step 1: Write constants**

Create `lib/core/constants.dart`:

```dart
/// Maximum distance in km at which proximity score is non-zero.
const double kMaxProximityKm = 50.0;

/// Window for counting recent impressions when computing decay.
const Duration kImpressionDecayWindow = Duration(minutes: 10);

/// If an ad has not been shown in this window, it gets a starvation boost.
const Duration kStarvationWindow = Duration(minutes: 5);

/// How many ads to show in the feed.
const int kFeedSize = 10;
```

- [ ] **Step 2: Write `RankingWeights`**

Create `lib/domain/ranking/ranking_weights.dart`:

```dart
class RankingWeights {
  const RankingWeights({
    this.tier = 10.0,
    this.proximity = 8.0,
    this.decay = 2.0,
    this.starvation = 5.0,
  });

  final double tier;
  final double proximity;
  final double decay;
  final double starvation;

  static const RankingWeights defaultWeights = RankingWeights();
}
```

- [ ] **Step 3: Verify compiles**

```bash
flutter analyze lib/core/ lib/domain/
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/core/constants.dart lib/domain/ranking/ranking_weights.dart
git commit -m "feat(domain): add ranking constants and RankingWeights value class"
```

---

## Task 5: `AdEvent` model + Hive adapter

**Files:**
- Create: `lib/data/models/ad_event.dart`

- [ ] **Step 1: Write `AdEvent` and `EventType`**

Create `lib/data/models/ad_event.dart`. We write the Hive adapter by hand (no codegen) to keep dependencies light:

```dart
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

enum EventType { impression, click }

class AdEvent extends Equatable {
  const AdEvent({
    required this.adId,
    required this.type,
    required this.timestamp,
  });

  final String adId;
  final EventType type;
  final DateTime timestamp;

  @override
  List<Object?> get props => [adId, type, timestamp];
}

class AdEventAdapter extends TypeAdapter<AdEvent> {
  @override
  final int typeId = 1;

  @override
  AdEvent read(BinaryReader reader) {
    final adId = reader.readString();
    final typeIndex = reader.readByte();
    final ts = reader.readInt();
    return AdEvent(
      adId: adId,
      type: EventType.values[typeIndex],
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  @override
  void write(BinaryWriter writer, AdEvent obj) {
    writer.writeString(obj.adId);
    writer.writeByte(obj.type.index);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
  }
}
```

- [ ] **Step 2: Verify compiles**

```bash
flutter analyze lib/data/models/
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/ad_event.dart
git commit -m "feat(data): add AdEvent model with hand-written Hive adapter"
```

---

## Task 6: `RankingEngine` — Tier 1 unit tests (must-have)

**Files:**
- Test: `test/domain/ranking_engine_test.dart`
- Create: `lib/domain/ranking/ranking_engine.dart`

This is the algorithmic centerpiece. We write the full Tier 1 test suite first, then implement.

- [ ] **Step 1: Write failing tests for `RankingEngine`**

Create `test/domain/ranking_engine_test.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_engine.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_weights.dart';
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

  final engine = RankingEngine();
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
  });
}
```

- [ ] **Step 2: Run tests, verify failure**

```bash
flutter test test/domain/ranking_engine_test.dart
```

Expected: FAIL — `RankingEngine` is undefined.

- [ ] **Step 3: Implement `RankingEngine`**

Create `lib/domain/ranking/ranking_engine.dart`:

```dart
import 'dart:math' as math;

import 'package:ad_ranking_prototype/core/constants.dart';
import 'package:ad_ranking_prototype/core/distance.dart';
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/ad_event.dart';
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

      final score = weights.tier * ad.tier.weight +
          weights.proximity * proximityScore -
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
```

- [ ] **Step 4: Run tests, verify all pass**

```bash
flutter test test/domain/ranking_engine_test.dart
```

Expected: all 9 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/ranking/ranking_engine.dart test/domain/ranking_engine_test.dart
git commit -m "feat(domain): implement RankingEngine with Tier 1 unit tests"
```

---

## Task 7: `AdRepository` + `MockAdRepository`

**Files:**
- Create: `lib/data/repositories/ad_repository.dart`
- Create: `lib/data/repositories/mock_ad_repository.dart`

- [ ] **Step 1: Define abstract repository**

Create `lib/data/repositories/ad_repository.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/ad.dart';

abstract class AdRepository {
  Future<List<Ad>> getAll();
}
```

- [ ] **Step 2: Implement mock repository with ~10 ads across PH cities**

Create `lib/data/repositories/mock_ad_repository.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';

class MockAdRepository implements AdRepository {
  @override
  Future<List<Ad>> getAll() async {
    return const [
      // Manila (14.5995, 120.9842)
      Ad(
        id: 'jollibee-manila',
        title: 'Chickenjoy Bucket — 20% off today',
        description: 'Limited-time bucket deal at Jollibee Manila stores.',
        advertiserName: 'Jollibee',
        tier: AdTier.gold,
        latitude: 14.5995,
        longitude: 120.9842,
      ),
      Ad(
        id: 'globe-manila',
        title: 'Globe Fiber 100Mbps for ₱1499',
        description: 'Upgrade your home fiber plan this month.',
        advertiserName: 'Globe Telecom',
        tier: AdTier.gold,
        latitude: 14.5547,
        longitude: 121.0244,
      ),
      Ad(
        id: 'grab-manila',
        title: '₱50 off your next GrabFood order',
        description: 'Use code SAVE50 at checkout.',
        advertiserName: 'Grab',
        tier: AdTier.silver,
        latitude: 14.6091,
        longitude: 121.0223,
      ),
      Ad(
        id: 'localcafe-manila',
        title: 'Buy 1 Get 1 espresso this week',
        description: 'Drop by Café Carpio in Quezon City.',
        advertiserName: 'Café Carpio',
        tier: AdTier.bronze,
        latitude: 14.6760,
        longitude: 121.0437,
      ),

      // Cebu (10.3157, 123.8854)
      Ad(
        id: 'ayala-cebu',
        title: 'Ayala Center Cebu mid-year sale',
        description: 'Up to 70% off on selected stores.',
        advertiserName: 'Ayala Malls',
        tier: AdTier.gold,
        latitude: 10.3181,
        longitude: 123.9054,
      ),
      Ad(
        id: 'lechon-cebu',
        title: 'Original Cebu Lechon — free delivery',
        description: '1kg orders and above ship free within Cebu City.',
        advertiserName: 'CnT Lechon',
        tier: AdTier.silver,
        latitude: 10.3270,
        longitude: 123.9038,
      ),
      Ad(
        id: 'bookshop-cebu',
        title: 'Indie bookshop pop-up this Saturday',
        description: 'New titles, secondhand finds, free coffee.',
        advertiserName: 'Folio Books',
        tier: AdTier.bronze,
        latitude: 10.3000,
        longitude: 123.9000,
      ),

      // Davao (7.1907, 125.4553)
      Ad(
        id: 'durian-davao',
        title: 'Durian harvest fest — 15% off whole fruit',
        description: 'Fresh from Davao orchards.',
        advertiserName: 'Davao Durian Co.',
        tier: AdTier.silver,
        latitude: 7.0707,
        longitude: 125.6111,
      ),
      Ad(
        id: 'eagle-davao',
        title: 'Philippine Eagle Center tour discount',
        description: 'Weekend family pass at 20% off.',
        advertiserName: 'PEC',
        tier: AdTier.bronze,
        latitude: 7.1907,
        longitude: 125.4553,
      ),

      // Baguio (16.4023, 120.5960)
      Ad(
        id: 'strawberry-baguio',
        title: 'Strawberry taho special — Mines View',
        description: 'Locally grown, top vendor in town.',
        advertiserName: 'La Trinidad Farms',
        tier: AdTier.silver,
        latitude: 16.4140,
        longitude: 120.6228,
      ),
    ];
  }
}
```

- [ ] **Step 3: Verify compiles**

```bash
flutter analyze lib/data/repositories/
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/data/repositories/ad_repository.dart lib/data/repositories/mock_ad_repository.dart
git commit -m "feat(data): add AdRepository interface + MockAdRepository with PH ads"
```

---

## Task 8: `EventRepository` + `HiveEventRepository`

**Files:**
- Create: `lib/data/repositories/event_repository.dart`
- Create: `lib/data/repositories/hive_event_repository.dart`

- [ ] **Step 1: Define abstract repository**

Create `lib/data/repositories/event_repository.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/ad_event.dart';

abstract class EventRepository {
  Future<void> recordImpression(String adId);
  Future<void> recordClick(String adId);
  Future<List<AdEvent>> getEventsSince(DateTime since);
}
```

- [ ] **Step 2: Implement Hive-backed repository**

Create `lib/data/repositories/hive_event_repository.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:hive/hive.dart';

class HiveEventRepository implements EventRepository {
  HiveEventRepository(this._box);

  static const String boxName = 'ad_events';

  final Box<AdEvent> _box;

  @override
  Future<void> recordImpression(String adId) async {
    await _box.add(
      AdEvent(
        adId: adId,
        type: EventType.impression,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> recordClick(String adId) async {
    await _box.add(
      AdEvent(
        adId: adId,
        type: EventType.click,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<AdEvent>> getEventsSince(DateTime since) async {
    return _box.values.where((e) => e.timestamp.isAfter(since)).toList();
  }
}
```

- [ ] **Step 3: Verify compiles**

```bash
flutter analyze lib/data/repositories/
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/data/repositories/event_repository.dart lib/data/repositories/hive_event_repository.dart
git commit -m "feat(data): add EventRepository interface + Hive impl"
```

---

## Task 9: `LocationRepository`

**Files:**
- Create: `lib/data/repositories/location_repository.dart`

- [ ] **Step 1: Implement in-memory location repository**

Create `lib/data/repositories/location_repository.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/user_location.dart';

class LocationRepository {
  const LocationRepository();

  static const List<UserLocation> _locations = [
    UserLocation(name: 'Manila', latitude: 14.5995, longitude: 120.9842),
    UserLocation(name: 'Cebu', latitude: 10.3157, longitude: 123.8854),
    UserLocation(name: 'Davao', latitude: 7.1907, longitude: 125.4553),
    UserLocation(name: 'Baguio', latitude: 16.4023, longitude: 120.5960),
  ];

  List<UserLocation> getAll() => _locations;

  UserLocation get defaultLocation => _locations.first;
}
```

- [ ] **Step 2: Verify compiles**

```bash
flutter analyze lib/data/repositories/
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/location_repository.dart
git commit -m "feat(data): add LocationRepository with mock PH cities"
```

---

## Task 10: `LocationCubit`

**Files:**
- Create: `lib/presentation/location/cubit/location_cubit.dart`

- [ ] **Step 1: Implement cubit**

Create `lib/presentation/location/cubit/location_cubit.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/data/repositories/location_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocationCubit extends Cubit<UserLocation> {
  LocationCubit(this._repository) : super(_repository.defaultLocation);

  final LocationRepository _repository;

  List<UserLocation> get available => _repository.getAll();

  void select(UserLocation location) => emit(location);
}
```

- [ ] **Step 2: Verify compiles**

```bash
flutter analyze lib/presentation/location/
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/location/
git commit -m "feat(presentation): add LocationCubit"
```

---

## Task 11: `FeedBloc` + Tier 2 tests (must-have)

**Files:**
- Create: `lib/presentation/feed/bloc/feed_event.dart`
- Create: `lib/presentation/feed/bloc/feed_state.dart`
- Create: `lib/presentation/feed/bloc/feed_bloc.dart`
- Test: `test/presentation/feed/feed_bloc_test.dart`

- [ ] **Step 1: Write `FeedEvent`**

Create `lib/presentation/feed/bloc/feed_event.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:equatable/equatable.dart';

sealed class FeedEvent extends Equatable {
  const FeedEvent();
  @override
  List<Object?> get props => const [];
}

class FeedRequested extends FeedEvent {
  const FeedRequested();
}

class FeedLocationChanged extends FeedEvent {
  const FeedLocationChanged(this.location);
  final UserLocation location;
  @override
  List<Object?> get props => [location];
}
```

- [ ] **Step 2: Write `FeedState`**

Create `lib/presentation/feed/bloc/feed_state.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:equatable/equatable.dart';

sealed class FeedState extends Equatable {
  const FeedState();
  @override
  List<Object?> get props => const [];
}

class FeedInitial extends FeedState {
  const FeedInitial();
}

class FeedLoading extends FeedState {
  const FeedLoading();
}

class FeedLoaded extends FeedState {
  const FeedLoaded(this.ads);
  final List<Ad> ads;
  @override
  List<Object?> get props => [ads];
}

class FeedError extends FeedState {
  const FeedError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 3: Write `FeedBloc`**

Create `lib/presentation/feed/bloc/feed_bloc.dart`:

```dart
import 'package:ad_ranking_prototype/core/constants.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_engine.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({
    required AdRepository adRepository,
    required EventRepository eventRepository,
    required RankingEngine rankingEngine,
    required UserLocation initialLocation,
  })  : _adRepository = adRepository,
        _eventRepository = eventRepository,
        _rankingEngine = rankingEngine,
        _currentLocation = initialLocation,
        super(const FeedInitial()) {
    on<FeedRequested>(_onRequested);
    on<FeedLocationChanged>(_onLocationChanged);
  }

  final AdRepository _adRepository;
  final EventRepository _eventRepository;
  final RankingEngine _rankingEngine;
  UserLocation _currentLocation;

  Future<void> _onRequested(FeedRequested event, Emitter<FeedState> emit) async {
    emit(const FeedLoading());
    try {
      final ads = await _adRepository.getAll();
      final events = await _eventRepository.getEventsSince(
        DateTime.now().subtract(kImpressionDecayWindow),
      );
      final ranked = _rankingEngine.rank(
        ads: ads,
        userLocation: _currentLocation,
        events: events,
        now: DateTime.now(),
        limit: kFeedSize,
      );
      emit(FeedLoaded(ranked));
    } catch (e) {
      emit(FeedError(e.toString()));
    }
  }

  Future<void> _onLocationChanged(
    FeedLocationChanged event,
    Emitter<FeedState> emit,
  ) async {
    _currentLocation = event.location;
    add(const FeedRequested());
  }
}
```

- [ ] **Step 4: Write Tier 2 tests for `FeedBloc`**

Create `test/presentation/feed/feed_bloc_test.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_engine.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_bloc.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdRepository extends Mock implements AdRepository {}

class _MockEventRepository extends Mock implements EventRepository {}

void main() {
  late _MockAdRepository adRepo;
  late _MockEventRepository eventRepo;

  const manila = UserLocation(
    name: 'Manila',
    latitude: 14.5995,
    longitude: 120.9842,
  );
  const cebu = UserLocation(
    name: 'Cebu',
    latitude: 10.3157,
    longitude: 123.8854,
  );

  final ads = [
    const Ad(
      id: 'manila-gold',
      title: 'Manila Gold',
      description: '',
      advertiserName: '',
      tier: AdTier.gold,
      latitude: 14.5995,
      longitude: 120.9842,
    ),
    const Ad(
      id: 'cebu-gold',
      title: 'Cebu Gold',
      description: '',
      advertiserName: '',
      tier: AdTier.gold,
      latitude: 10.3157,
      longitude: 123.8854,
    ),
  ];

  setUp(() {
    adRepo = _MockAdRepository();
    eventRepo = _MockEventRepository();
    when(() => adRepo.getAll()).thenAnswer((_) async => ads);
    when(() => eventRepo.getEventsSince(any()))
        .thenAnswer((_) async => <AdEvent>[]);
  });

  FeedBloc build(UserLocation initial) => FeedBloc(
        adRepository: adRepo,
        eventRepository: eventRepo,
        rankingEngine: const RankingEngine(),
        initialLocation: initial,
      );

  blocTest<FeedBloc, FeedState>(
    'emits [Loading, Loaded] on FeedRequested',
    build: () => build(manila),
    act: (b) => b.add(const FeedRequested()),
    expect: () => [
      const FeedLoading(),
      isA<FeedLoaded>().having(
        (s) => s.ads.first.id,
        'first ad',
        'manila-gold',
      ),
    ],
  );

  blocTest<FeedBloc, FeedState>(
    're-ranks when location changes — Cebu user sees cebu-gold first',
    build: () => build(manila),
    act: (b) async {
      b.add(const FeedRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(const FeedLocationChanged(cebu));
    },
    skip: 2, // skip initial Loading + Loaded for Manila
    expect: () => [
      const FeedLoading(),
      isA<FeedLoaded>().having(
        (s) => s.ads.first.id,
        'first ad after re-rank',
        'cebu-gold',
      ),
    ],
  );

  blocTest<FeedBloc, FeedState>(
    'emits FeedError when AdRepository throws',
    build: () {
      when(() => adRepo.getAll()).thenThrow(Exception('boom'));
      return build(manila);
    },
    act: (b) => b.add(const FeedRequested()),
    expect: () => [
      const FeedLoading(),
      isA<FeedError>(),
    ],
  );
}
```

- [ ] **Step 5: Run tests, verify all pass**

```bash
flutter test test/presentation/feed/feed_bloc_test.dart
```

Expected: all 3 bloc tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/feed/ test/presentation/feed/
git commit -m "feat(presentation): add FeedBloc with Tier 2 bloc_tests"
```

---

## Task 12: `AnalyticsBloc` + Tier 2 tests (must-have)

**Files:**
- Create: `lib/presentation/analytics/bloc/analytics_event.dart`
- Create: `lib/presentation/analytics/bloc/analytics_bloc.dart`
- Test: `test/presentation/analytics/analytics_bloc_test.dart`

- [ ] **Step 1: Write `AnalyticsEvent`**

Create `lib/presentation/analytics/bloc/analytics_event.dart`:

```dart
import 'package:equatable/equatable.dart';

sealed class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();
  @override
  List<Object?> get props => const [];
}

class ImpressionRecorded extends AnalyticsEvent {
  const ImpressionRecorded(this.adId);
  final String adId;
  @override
  List<Object?> get props => [adId];
}

class ClickRecorded extends AnalyticsEvent {
  const ClickRecorded(this.adId);
  final String adId;
  @override
  List<Object?> get props => [adId];
}
```

- [ ] **Step 2: Write `AnalyticsBloc`**

Create `lib/presentation/analytics/bloc/analytics_bloc.dart`. `AnalyticsBloc` fires writes but does not surface state changes that the UI needs, so we use a `Bloc<AnalyticsEvent, void>` pattern via a single Unit state. To stay simple, model the state as a counter map so the UI can show "X impressions, Y clicks" if useful, and so we have observable state to test.

```dart
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_event.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnalyticsState extends Equatable {
  const AnalyticsState({
    this.impressionsByAd = const {},
    this.clicksByAd = const {},
  });

  final Map<String, int> impressionsByAd;
  final Map<String, int> clicksByAd;

  AnalyticsState copyWith({
    Map<String, int>? impressionsByAd,
    Map<String, int>? clicksByAd,
  }) {
    return AnalyticsState(
      impressionsByAd: impressionsByAd ?? this.impressionsByAd,
      clicksByAd: clicksByAd ?? this.clicksByAd,
    );
  }

  @override
  List<Object?> get props => [impressionsByAd, clicksByAd];
}

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  AnalyticsBloc(this._repository) : super(const AnalyticsState()) {
    on<ImpressionRecorded>(_onImpression);
    on<ClickRecorded>(_onClick);
  }

  final EventRepository _repository;

  Future<void> _onImpression(
    ImpressionRecorded event,
    Emitter<AnalyticsState> emit,
  ) async {
    await _repository.recordImpression(event.adId);
    final next = Map<String, int>.from(state.impressionsByAd);
    next.update(event.adId, (v) => v + 1, ifAbsent: () => 1);
    emit(state.copyWith(impressionsByAd: next));
  }

  Future<void> _onClick(
    ClickRecorded event,
    Emitter<AnalyticsState> emit,
  ) async {
    await _repository.recordClick(event.adId);
    final next = Map<String, int>.from(state.clicksByAd);
    next.update(event.adId, (v) => v + 1, ifAbsent: () => 1);
    emit(state.copyWith(clicksByAd: next));
  }
}
```

- [ ] **Step 3: Write Tier 2 tests for `AnalyticsBloc`**

Create `test/presentation/analytics/analytics_bloc_test.dart`:

```dart
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_bloc.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_event.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockEventRepository extends Mock implements EventRepository {}

void main() {
  late _MockEventRepository repo;

  setUp(() {
    repo = _MockEventRepository();
    when(() => repo.recordImpression(any())).thenAnswer((_) async {});
    when(() => repo.recordClick(any())).thenAnswer((_) async {});
  });

  blocTest<AnalyticsBloc, AnalyticsState>(
    'calls recordImpression and increments counter',
    build: () => AnalyticsBloc(repo),
    act: (b) => b.add(const ImpressionRecorded('ad-1')),
    verify: (_) {
      verify(() => repo.recordImpression('ad-1')).called(1);
    },
    expect: () => [
      const AnalyticsState(impressionsByAd: {'ad-1': 1}),
    ],
  );

  blocTest<AnalyticsBloc, AnalyticsState>(
    'calls recordClick and increments counter',
    build: () => AnalyticsBloc(repo),
    act: (b) => b.add(const ClickRecorded('ad-2')),
    verify: (_) {
      verify(() => repo.recordClick('ad-2')).called(1);
    },
    expect: () => [
      const AnalyticsState(clicksByAd: {'ad-2': 1}),
    ],
  );

  blocTest<AnalyticsBloc, AnalyticsState>(
    'increments per ad across multiple impressions',
    build: () => AnalyticsBloc(repo),
    act: (b) {
      b.add(const ImpressionRecorded('ad-1'));
      b.add(const ImpressionRecorded('ad-1'));
      b.add(const ImpressionRecorded('ad-2'));
    },
    expect: () => [
      const AnalyticsState(impressionsByAd: {'ad-1': 1}),
      const AnalyticsState(impressionsByAd: {'ad-1': 2}),
      const AnalyticsState(impressionsByAd: {'ad-1': 2, 'ad-2': 1}),
    ],
  );
}
```

- [ ] **Step 4: Run tests, verify all pass**

```bash
flutter test test/presentation/analytics/analytics_bloc_test.dart
```

Expected: all 3 bloc tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/analytics/ test/presentation/analytics/
git commit -m "feat(presentation): add AnalyticsBloc with Tier 2 bloc_tests"
```

---

## Task 13: Material 3 theme + tier color helper

**Files:**
- Create: `lib/core/theme.dart`

- [ ] **Step 1: Implement theme**

Create `lib/core/theme.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
    );
  }
}

Color tierColor(AdTier tier) {
  switch (tier) {
    case AdTier.gold:
      return const Color(0xFFD4AF37);
    case AdTier.silver:
      return const Color(0xFFB0B0B0);
    case AdTier.bronze:
      return const Color(0xFFB87333);
  }
}

String tierLabel(AdTier tier) {
  switch (tier) {
    case AdTier.gold:
      return 'GOLD';
    case AdTier.silver:
      return 'SILVER';
    case AdTier.bronze:
      return 'BRONZE';
  }
}
```

- [ ] **Step 2: Verify compiles**

```bash
flutter analyze lib/core/theme.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/theme.dart
git commit -m "feat(core): add Material 3 theme + tier color/label helpers"
```

---

## Task 14: `AdCard` widget

**Files:**
- Create: `lib/presentation/feed/view/ad_card.dart`

- [ ] **Step 1: Implement `AdCard`**

Create `lib/presentation/feed/view/ad_card.dart`:

```dart
import 'package:ad_ranking_prototype/core/distance.dart';
import 'package:ad_ranking_prototype/core/theme.dart';
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
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
        child: Padding(
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
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compiles**

```bash
flutter analyze lib/presentation/feed/view/ad_card.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/feed/view/ad_card.dart
git commit -m "feat(presentation): add AdCard widget with tier badge + distance"
```

---

## Task 15: `LocationPicker` widget

**Files:**
- Create: `lib/presentation/location/view/location_picker.dart`

- [ ] **Step 1: Implement `LocationPicker`**

Create `lib/presentation/location/view/location_picker.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/presentation/location/cubit/location_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocationPicker extends StatelessWidget {
  const LocationPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<LocationCubit>();
    return DropdownButton<UserLocation>(
      value: cubit.state,
      icon: const Icon(Icons.location_on_outlined),
      underline: const SizedBox.shrink(),
      onChanged: (loc) {
        if (loc != null) cubit.select(loc);
      },
      items: [
        for (final loc in cubit.available)
          DropdownMenuItem(value: loc, child: Text(loc.name)),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify compiles**

```bash
flutter analyze lib/presentation/location/
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/location/view/
git commit -m "feat(presentation): add LocationPicker dropdown"
```

---

## Task 16: `FeedPage` view

**Files:**
- Create: `lib/presentation/feed/view/feed_page.dart`

- [ ] **Step 1: Implement `FeedPage`**

Create `lib/presentation/feed/view/feed_page.dart`:

```dart
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
```

- [ ] **Step 2: Verify compiles**

```bash
flutter analyze lib/presentation/feed/view/
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/feed/view/feed_page.dart
git commit -m "feat(presentation): add FeedPage with visibility-tracked feed list"
```

---

## Task 17: Wire `main.dart`

**Files:**
- Modify: `lib/main.dart` (full replacement)

- [ ] **Step 1: Replace `main.dart`**

Replace `lib/main.dart`:

```dart
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
```

- [ ] **Step 2: Delete obsolete default test**

The default `flutter create` writes `test/widget_test.dart` that depends on the removed counter app. Delete it:

```bash
rm test/widget_test.dart
```

- [ ] **Step 3: Run full analyze + tests**

```bash
flutter analyze
flutter test
```

Expected: no analyzer issues; all unit + bloc tests pass.

- [ ] **Step 4: Smoke-run the app on a target you have ready**

For mobile: `flutter run -d <emulator_id_or_device>`
For web: `flutter run -d chrome`

Expected: app launches, shows feed sorted by Manila proximity (Manila ads top), tier badges visible, location picker in app bar, taps show snackbar.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git rm test/widget_test.dart
git commit -m "feat: wire app — Hive init, BlocProviders, FeedPage"
```

---

## Task 18: README

**Files:**
- Modify: `README.md` (full rewrite)

- [ ] **Step 1: Replace `README.md`**

Replace `README.md`:

````markdown
# Ad Ranking & Delivery Prototype

A lightweight Flutter prototype that ranks advertiser ads by tier + proximity + fairness, displays them in a scrollable feed, and logs impressions/clicks locally with Hive.


---

## Quick start

**Prerequisites:** Flutter SDK (stable channel, Dart 3+).

```bash
flutter pub get
flutter run                  # mobile (emulator/device)
flutter run -d chrome        # web
flutter test                 # unit + bloc tests
```

Use the dropdown in the app bar to switch the mock user location (Manila / Cebu / Davao / Baguio). The feed re-ranks immediately. Tap the refresh FAB to re-rank manually after impressions accumulate.

---

## Architecture decisions

**Layered architecture** — presentation (BLoCs + widgets), domain (`RankingEngine`, models), data (repositories). The dependency arrow points strictly downward. `domain/` has zero Flutter imports — the ranking algorithm is a pure function you can hold in one file and test exhaustively.

**flutter_bloc** for state management. Explicit events/states make the data flow easy to read and to test with `bloc_test`. One BLoC per concern (`FeedBloc`, `AnalyticsBloc`, `LocationCubit`) — no god-blocs.

**Hive over SQLite/Drift** for the event log. The data shape is append-only with simple range queries — no SQL needed. Hive works natively on web (uses IndexedDB transparently), avoiding the `sqflite_common_ffi_web` indirection.

**Material 3** with a seeded `ColorScheme` (`Colors.indigo`). Modern default, polished baseline for zero custom design work. Tier color (gold/silver/bronze) overlays the seeded palette where it matters.

**No real backend.** The assessment allows mocked data, so `AdRepository` is an abstract interface with a `MockAdRepository` impl. To plug in a real backend, write an `HttpAdRepository` and swap it in `main.dart`. Same for `EventRepository`.

---

## Ranking algorithm

For each candidate ad:

```
score(ad) = (W_tier   × tier_weight)
          + (W_prox   × proximity_score)
          − (W_decay  × recent_impression_count)
          + (W_starve × starvation_boost)
```

Sort descending. Take top N (default N = 10).

| Term | Definition |
|---|---|
| `tier_weight` | Gold = 3, Silver = 2, Bronze = 1 |
| `proximity_score` | `max(0, 1 − distance_km / 50)` — linear decay, 0 km ⇒ 1.0, ≥50 km ⇒ 0 |
| `recent_impression_count` | impressions in the last 10 min |
| `starvation_boost` | `1.0` if ad has not been shown in 5 min, else `0` |

**Initial weights:** `W_tier = 10`, `W_prox = 8`, `W_decay = 2`, `W_starve = 5`. Defined in `RankingWeights.defaultWeights`.

**Why each weight:**
- `W_tier > W_prox` ⇒ a Gold ad in the same city beats a Bronze next door. Premium gets premium placement, which is the business rule.
- `W_prox = 8` lets a fresh, nearby Silver leapfrog a distant Gold once that Gold has been shown a few times.
- `W_decay = 2` ⇒ 3 recent impressions cost 6 score, enough for one tier-level overtake.
- `W_starve = 5` is large enough to surface an ignored Bronze without ever dominating a high-tier ad that's getting clicked.

**Why deterministic top-N, not probabilistic sampling.** Weighted random sampling is elegant and inherently anti-starvation, but harder to *explain*. A reviewer (or a customer) should be able to read the formula, look at the inputs, and predict the output. The decay term gives the same anti-starvation effect over time while keeping ordering inspectable.

**Why impressions don't trigger immediate re-ranking.** Re-ranking on every impression would shuffle the list under the user's finger as they scroll. The trigger conditions are: (a) location change, (b) pull-to-refresh, (c) refresh FAB. In production, you'd push state updates from a streaming source asynchronously and only swap the list at natural boundaries (page changes, app focus).

**How weights would be tuned in production.** Treat them as hyperparameters. Run A/B tests where each variant uses different `W_*` values, measure CTR per tier and overall revenue, and use a multi-armed bandit (e.g., Thompson sampling) to converge to the best mix. Re-tune quarterly as the advertiser mix shifts.

---

## How this would scale

**Retrieval layer.** A request says "I'm in Cebu and looking at a food feed." A retrieval service (think Redis or a vector store) returns the top ~1000 candidate ads by region + category, pre-filtered for budget and frequency caps. Today's `MockAdRepository` is the placeholder for this layer.

**Ranking layer.** Take those ~1000 candidates and run them through this same `RankingEngine` (or a learned model) per request. Stateless and horizontally scalable. The pure-function design here is intentional — it would deploy unchanged behind any HTTP wrapper.

**Event pipeline.** Impressions and clicks are written to a streaming bus (Kafka, Pub/Sub, Kinesis). The current `EventRepository.recordImpression` would become a producer call instead of a Hive write. From the bus, two consumers fan out:
1. A real-time aggregator (Flink / Spark Streaming) that updates per-ad counters in Redis → feeds back into the next ranking call's decay term.
2. An OLAP sink (BigQuery / Snowflake) for offline analytics, advertiser dashboards, and weight tuning.

**Caching.** Per-region candidate sets cache for 30–60s in Redis. Per-user frequency-cap counters live in a fast KV (e.g., DynamoDB).

**Out of scope but understood:** cold-start handling for new advertisers, budget pacing (don't burn an advertiser's daily budget in 10 minutes), per-user frequency capping, fraud detection.

---

## Tradeoffs made for the 3–4 hour budget

| Skipped | Reason | Real-system replacement |
|---|---|---|
| Real backend | Assessment allows mocked data | `HttpAdRepository` behind the same interface |
| Real GPS | Permission + simulator setup eats time | `geolocator` + permission_handler |
| User identity / auth | Out of scope for prototype | OAuth or anonymous device ID |
| A/B testing infra for weights | Out of scope | Feature flags + bandit-based tuning |
| Widget + integration tests | Time budget | Listed in `docs/superpowers/specs/...` as future work |
| Cold-start, budget pacing, frequency capping | Out of scope | Discussed above |

The test pyramid stops at Tier 2 (`bloc_test`) on purpose: the algorithm is where the bugs would live, and bloc tests cover the reactive plumbing. Widget tests on a 5-widget app would be ceremony without much bug-finding value.

---

## Where AI was used

Claude (`Opus 4.7` via Claude Code) was used as a brainstorming and boilerplate partner in this assessment:

- **Brainstorming session** — produced the design spec at `docs/superpowers/specs/2026-05-24-ad-ranking-prototype-design.md` and the task-by-task plan at `docs/superpowers/plans/2026-05-24-ad-ranking-prototype.md`. The architecture choices, ranking formula, weight values, and tradeoff list were proposed by Claude and ratified (and sometimes overridden) by me. The full conversation drove the design.
- **Boilerplate generation** — BLoC scaffolding (events/states), Hive type adapter, mock data list, Material 3 theme.
- **README polish** — first draft of this README, then edited by hand.

**Not from AI:** the choice to use Hive over Drift (driven by my own concern about Drift's web story), the decision to bump bloc tests to a must-have tier, the call to use Material 3 explicitly. Final weight values, formula trade-offs, and the "deterministic over probabilistic" choice were all deliberate decisions reviewed before committing.
````

- [ ] **Step 2: Verify the project layout**

```bash
ls README.md docs/superpowers/specs docs/superpowers/plans
```

Expected: all three present.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: write architecture + ranking + scale + AI-usage README"
```

---

## Task 19: Final verification

- [ ] **Step 1: Run full analyzer and tests**

```bash
flutter analyze
flutter test
```

Expected: zero analyzer issues; all unit + bloc tests pass.

- [ ] **Step 2: Smoke-run on mobile target**

```bash
flutter run -d <device-or-emulator>
```

Verify:
- Feed loads with Manila as default location, Jollibee/Globe (Gold, near) at top.
- Switching to Cebu re-orders so Ayala Cebu (Gold, near Cebu) moves to top.
- Tapping an ad shows a snackbar.
- Refresh FAB or pull-to-refresh re-ranks.
- Close and reopen app — impressions persist (visible by feed re-ordering due to decay).

- [ ] **Step 3: Smoke-run on web (optional but encouraged)**

```bash
flutter run -d chrome
```

Verify the same behaviors. Hive should persist across browser refresh via IndexedDB.

- [ ] **Step 4: Tag the deliverable commit**

```bash
git log --oneline
git tag v0.1-assessment-submission
```

- [ ] **Step 5: Final commit if any verification fixes were needed**

```bash
git status
# (commit any fixes)
```

---

## Done

If all of Task 19 passes, the prototype is ready to submit. Deliverables match the assessment requirements:

- ✅ Source code (`lib/`)
- ✅ Setup/run instructions (`README.md`)
- ✅ Architecture notes covering: decisions, tradeoffs, scaling, caching/DB/MQ, AI usage (`README.md`)
- ✅ Working ranking algorithm with tier + proximity + anti-starvation
- ✅ Frontend with impression/click interactions
- ✅ Persistent event logging (Hive)
- ✅ Test pyramid (Tier 1 unit + Tier 2 bloc)
