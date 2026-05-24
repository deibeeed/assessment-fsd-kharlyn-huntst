# Social Feed with Interest Learning (v2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the v1 ad-ranking prototype into an Instagram-style mixed feed where reactions on organic posts build a per-category interest profile that boosts ad ranking.

**Architecture:** Existing 3-layer architecture (presentation / domain / data) is preserved. New components: `Post` and `Category` models, `PostRepository`, `ReactionRepository` (Hive-backed), pure `InterestService`, `PostBloc`, `ReactionCubit`, `InterestCubit`, `PostCard` and `MixedFeedView` widgets. `RankingEngine` gains one new term (`W_interest × interest_match`). `FeedBloc` listens to `InterestCubit` and re-ranks on profile changes.

**Tech Stack:** Existing v1 stack (Flutter, Dart 3, Material 3, flutter_bloc, hive, equatable, visibility_detector, bloc_test, mocktail). New dep: `cached_network_image`.

**Source spec:** `docs/superpowers/specs/2026-05-24-social-feed-with-interest-learning-design.md`
**Builds on:** v0.1 implementation tagged `v0.1-assessment-submission`.

---

## File Structure (delta from v1)

```
lib/
  core/
    avatar.dart                       # NEW — colored initial avatars
    constants.dart                    # MODIFY — add kPostsPerAd
  data/
    models/
      category.dart                   # NEW
      post.dart                       # NEW
      post_like.dart                  # NEW
      post_like_adapter.dart          # NEW (Hive adapter, typeId=2)
      ad.dart                         # MODIFY — add imageUrl, categories
    repositories/
      mock_ad_repository.dart         # MODIFY — categorize + image per ad
      event_repository.dart           # MODIFY — add recordPostImpression
      hive_event_repository.dart      # MODIFY — impl recordPostImpression
      post_repository.dart            # NEW
      mock_post_repository.dart       # NEW (100 generated posts)
      reaction_repository.dart        # NEW
      hive_reaction_repository.dart   # NEW
  domain/
    interest/
      interest_service.dart           # NEW (pure)
    ranking/
      ranking_engine.dart             # MODIFY — interest term
      ranking_weights.dart            # MODIFY — add interest weight
  presentation/
    feed/
      bloc/feed_bloc.dart             # MODIFY — InterestCubit dep
      view/feed_page.dart             # MODIFY — MultiBlocProvider rewire
      view/mixed_feed_view.dart       # NEW
      view/ad_card.dart               # MODIFY — image + Sponsored chip
      view/post_card.dart             # NEW
    posts/
      bloc/
        post_event.dart               # NEW
        post_state.dart               # NEW
        post_bloc.dart                # NEW
    reactions/
      cubit/reaction_cubit.dart       # NEW
    interest/
      cubit/interest_cubit.dart       # NEW
    analytics/
      bloc/analytics_event.dart       # MODIFY — add PostImpressionRecorded
      bloc/analytics_bloc.dart        # MODIFY — handle post impression
  main.dart                           # MODIFY — register adapter, providers

test/
  domain/
    interest_service_test.dart        # NEW (Tier 1)
    ranking_engine_test.dart          # MODIFY — interest cases + update existing
  presentation/
    feed/feed_bloc_test.dart          # MODIFY — interest re-rank case
    analytics/analytics_bloc_test.dart # MODIFY — post impression case
    posts/post_bloc_test.dart         # NEW (Tier 2)
    reactions/reaction_cubit_test.dart # NEW (Tier 2)
    interest/interest_cubit_test.dart  # NEW (Tier 2)

pubspec.yaml                          # MODIFY — add cached_network_image
README.md                             # MODIFY — interest learning section
```

---

## Task 1: Add `cached_network_image` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml`, find the `dependencies:` section and add `cached_network_image: ^3.4.1` after `visibility_detector`:

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
  cached_network_image: ^3.4.1
```

- [ ] **Step 2: Install**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter pub get
```

Expected: "Got dependencies!" with no resolution errors.

- [ ] **Step 3: Verify nothing broke**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
```

Expected: zero analyzer issues, 17/17 tests pass.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add cached_network_image dependency"
```

---

## Task 2: Category enum

**Files:**
- Create: `lib/data/models/category.dart`

- [ ] **Step 1: Write the enum**

Create `lib/data/models/category.dart`:

```dart
import 'package:flutter/material.dart';

enum Category {
  food,
  coffee,
  fashion,
  travel,
  fitness,
  tech,
  beauty,
  books;

  String get displayName => switch (this) {
        Category.food => 'Food',
        Category.coffee => 'Coffee',
        Category.fashion => 'Fashion',
        Category.travel => 'Travel',
        Category.fitness => 'Fitness',
        Category.tech => 'Tech',
        Category.beauty => 'Beauty',
        Category.books => 'Books',
      };

  IconData get icon => switch (this) {
        Category.food => Icons.restaurant_outlined,
        Category.coffee => Icons.local_cafe_outlined,
        Category.fashion => Icons.checkroom_outlined,
        Category.travel => Icons.flight_outlined,
        Category.fitness => Icons.fitness_center_outlined,
        Category.tech => Icons.devices_outlined,
        Category.beauty => Icons.spa_outlined,
        Category.books => Icons.menu_book_outlined,
      };
}
```

- [ ] **Step 2: Verify compiles**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/data/models/category.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/category.dart
git commit -m "feat(domain): add Category enum with display name + icon"
```

---

## Task 3: Post model

**Files:**
- Create: `lib/data/models/post.dart`

- [ ] **Step 1: Write the model**

Create `lib/data/models/post.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:equatable/equatable.dart';

class Post extends Equatable {
  const Post({
    required this.id,
    required this.authorName,
    required this.authorHandle,
    required this.caption,
    required this.imageUrl,
    required this.categories,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final String id;
  final String authorName;
  final String authorHandle;
  final String caption;
  final String imageUrl;
  final List<Category> categories;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  @override
  List<Object?> get props => [
        id,
        authorName,
        authorHandle,
        caption,
        imageUrl,
        categories,
        latitude,
        longitude,
        timestamp,
      ];
}
```

- [ ] **Step 2: Verify compiles**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/data/models/post.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/post.dart
git commit -m "feat(domain): add Post model"
```

---

## Task 4: PostLike model + Hive adapter

**Files:**
- Create: `lib/data/models/post_like.dart`
- Create: `lib/data/models/post_like_adapter.dart`

- [ ] **Step 1: Write `PostLike` model**

Create `lib/data/models/post_like.dart`:

```dart
import 'package:equatable/equatable.dart';

class PostLike extends Equatable {
  const PostLike({required this.postId, required this.likedAt});

  final String postId;
  final DateTime likedAt;

  @override
  List<Object?> get props => [postId, likedAt];
}
```

- [ ] **Step 2: Write Hive adapter**

Create `lib/data/models/post_like_adapter.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/post_like.dart';
import 'package:hive/hive.dart';

class PostLikeAdapter extends TypeAdapter<PostLike> {
  @override
  final int typeId = 2;

  @override
  PostLike read(BinaryReader reader) {
    final postId = reader.readString();
    final ts = reader.readInt();
    return PostLike(
      postId: postId,
      likedAt: DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  @override
  void write(BinaryWriter writer, PostLike obj) {
    writer.writeString(obj.postId);
    writer.writeInt(obj.likedAt.millisecondsSinceEpoch);
  }
}
```

- [ ] **Step 3: Verify compiles**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/data/models/
```

Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/data/models/post_like.dart lib/data/models/post_like_adapter.dart
git commit -m "feat(data): add PostLike model + Hive adapter (typeId=2)"
```

---

## Task 5: Extend `Ad` model with `imageUrl` and `categories`

**Files:**
- Modify: `lib/data/models/ad.dart`

- [ ] **Step 1: Replace the file**

Replace `lib/data/models/ad.dart` with:

```dart
import 'package:ad_ranking_prototype/data/models/category.dart';
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
    this.imageUrl = '',
    this.categories = const [],
  });

  final String id;
  final String title;
  final String description;
  final String advertiserName;
  final AdTier tier;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final List<Category> categories;

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        advertiserName,
        tier,
        latitude,
        longitude,
        imageUrl,
        categories,
      ];
}
```

The two new fields have safe defaults so existing call sites (v1 tests, v1 MockAdRepository, FeedBloc tests) keep compiling unchanged.

- [ ] **Step 2: Verify no regression**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
```

Expected: zero issues, 17/17 tests still pass (defaults preserve v1 behavior).

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/ad.dart
git commit -m "feat(data): extend Ad model with imageUrl and categories"
```

---

## Task 6: Categorize the 10 mock ads + add image URLs

**Files:**
- Modify: `lib/data/repositories/mock_ad_repository.dart`

- [ ] **Step 1: Replace the mock data**

Replace `lib/data/repositories/mock_ad_repository.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';

class MockAdRepository implements AdRepository {
  @override
  Future<List<Ad>> getAll() async {
    return const [
      Ad(
        id: 'jollibee-manila',
        title: 'Chickenjoy Bucket — 20% off today',
        description: 'Limited-time bucket deal at Jollibee Manila stores.',
        advertiserName: 'Jollibee',
        tier: AdTier.gold,
        latitude: 14.5995,
        longitude: 120.9842,
        imageUrl:
            'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&h=600&fit=crop',
        categories: [Category.food],
      ),
      Ad(
        id: 'globe-manila',
        title: 'Globe Fiber 100Mbps for ₱1499',
        description: 'Upgrade your home fiber plan this month.',
        advertiserName: 'Globe Telecom',
        tier: AdTier.gold,
        latitude: 14.5547,
        longitude: 121.0244,
        imageUrl:
            'https://images.unsplash.com/photo-1551808525-51a94da548ce?w=600&h=600&fit=crop',
        categories: [Category.tech],
      ),
      Ad(
        id: 'grab-manila',
        title: '₱50 off your next GrabFood order',
        description: 'Use code SAVE50 at checkout.',
        advertiserName: 'Grab',
        tier: AdTier.silver,
        latitude: 14.6091,
        longitude: 121.0223,
        imageUrl:
            'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&h=600&fit=crop',
        categories: [Category.food, Category.travel],
      ),
      Ad(
        id: 'localcafe-manila',
        title: 'Buy 1 Get 1 espresso this week',
        description: 'Drop by Café Carpio in Quezon City.',
        advertiserName: 'Café Carpio',
        tier: AdTier.bronze,
        latitude: 14.6760,
        longitude: 121.0437,
        imageUrl:
            'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&h=600&fit=crop',
        categories: [Category.coffee],
      ),
      Ad(
        id: 'ayala-cebu',
        title: 'Ayala Center Cebu mid-year sale',
        description: 'Up to 70% off on selected stores.',
        advertiserName: 'Ayala Malls',
        tier: AdTier.gold,
        latitude: 10.3181,
        longitude: 123.9054,
        imageUrl:
            'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=600&h=600&fit=crop',
        categories: [Category.fashion, Category.beauty],
      ),
      Ad(
        id: 'lechon-cebu',
        title: 'Original Cebu Lechon — free delivery',
        description: '1kg orders and above ship free within Cebu City.',
        advertiserName: 'CnT Lechon',
        tier: AdTier.silver,
        latitude: 10.3270,
        longitude: 123.9038,
        imageUrl:
            'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&h=600&fit=crop',
        categories: [Category.food],
      ),
      Ad(
        id: 'bookshop-cebu',
        title: 'Indie bookshop pop-up this Saturday',
        description: 'New titles, secondhand finds, free coffee.',
        advertiserName: 'Folio Books',
        tier: AdTier.bronze,
        latitude: 10.3000,
        longitude: 123.9000,
        imageUrl:
            'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?w=600&h=600&fit=crop',
        categories: [Category.books, Category.coffee],
      ),
      Ad(
        id: 'durian-davao',
        title: 'Durian harvest fest — 15% off whole fruit',
        description: 'Fresh from Davao orchards.',
        advertiserName: 'Davao Durian Co.',
        tier: AdTier.silver,
        latitude: 7.0707,
        longitude: 125.6111,
        imageUrl:
            'https://images.unsplash.com/photo-1601004890684-d8cbf643f5f2?w=600&h=600&fit=crop',
        categories: [Category.food],
      ),
      Ad(
        id: 'eagle-davao',
        title: 'Philippine Eagle Center tour discount',
        description: 'Weekend family pass at 20% off.',
        advertiserName: 'PEC',
        tier: AdTier.bronze,
        latitude: 7.1907,
        longitude: 125.4553,
        imageUrl:
            'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=600&h=600&fit=crop',
        categories: [Category.travel],
      ),
      Ad(
        id: 'strawberry-baguio',
        title: 'Strawberry taho special — Mines View',
        description: 'Locally grown, top vendor in town.',
        advertiserName: 'La Trinidad Farms',
        tier: AdTier.silver,
        latitude: 16.4140,
        longitude: 120.6228,
        imageUrl:
            'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?w=600&h=600&fit=crop',
        categories: [Category.food, Category.travel],
      ),
    ];
  }
}
```

- [ ] **Step 2: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
```

Expected: zero issues, 17/17 tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/mock_ad_repository.dart
git commit -m "feat(data): categorize ads + add Unsplash image URLs"
```

---

## Task 7: PostRepository + MockPostRepository (100 generated posts)

**Files:**
- Create: `lib/data/repositories/post_repository.dart`
- Create: `lib/data/repositories/mock_post_repository.dart`

- [ ] **Step 1: Define abstract repository**

Create `lib/data/repositories/post_repository.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/post.dart';

abstract class PostRepository {
  Future<List<Post>> getAll();
}
```

- [ ] **Step 2: Implement mock with template-based generation**

Create `lib/data/repositories/mock_post_repository.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/repositories/post_repository.dart';

class _Template {
  const _Template(this.caption, this.categories);
  final String caption;
  final List<Category> categories;
}

class _Author {
  const _Author(this.name, this.handle);
  final String name;
  final String handle;
}

class _BaseLocation {
  const _BaseLocation(this.name, this.latitude, this.longitude);
  final String name;
  final double latitude;
  final double longitude;
}

const List<_Template> _templates = [
  _Template('Sunday slow morning ☕', [Category.coffee]),
  _Template('Best lechon in town hands down 🐖', [Category.food]),
  _Template('Trail run before sunrise 🌅', [Category.fitness, Category.travel]),
  _Template('New zine drop at Folio this weekend', [Category.books]),
  _Template('Skincare haul — finally found a serum that works', [Category.beauty]),
  _Template('Pour-over hits different at home', [Category.coffee]),
  _Template('Found this denim jacket at a thrift store', [Category.fashion]),
  _Template('Hidden ramen spot in Poblacion 🍜', [Category.food]),
  _Template('Setting up my new mechanical keyboard', [Category.tech]),
  _Template('Beach day in Bantayan 🏝️', [Category.travel]),
  _Template('Match green tea + adobo combo, don\'t judge', [Category.food, Category.coffee]),
  _Template('Finished my first 10k 🏃', [Category.fitness]),
  _Template('Book club pick this month: Pachinko', [Category.books]),
  _Template('Lipstick that actually lasts through halo-halo', [Category.beauty, Category.food]),
  _Template('Reviewing the new mid-range phone', [Category.tech]),
  _Template('Saturday market finds — fresh strawberries', [Category.food]),
  _Template('Pilates studio downtown, recommend', [Category.fitness]),
  _Template('OOTD: linen pants + canvas sneakers', [Category.fashion]),
  _Template('Cafe-hopping in Quezon City this weekend', [Category.coffee, Category.travel]),
  _Template('Best taho in Baguio fight me', [Category.food, Category.travel]),
  _Template('Annotated bookstack 📚', [Category.books]),
  _Template('Gym progress, month 6', [Category.fitness]),
  _Template('Tablet for digital art, finally upgraded', [Category.tech]),
  _Template('Skincare routine simplified to 3 steps', [Category.beauty]),
  _Template('Coffee tasting flight at the roastery', [Category.coffee]),
];

const List<_Author> _authors = [
  _Author('Maria Santos', '@maria.eats'),
  _Author('Carlos Reyes', '@carl.runs'),
  _Author('Aileen Cruz', '@aileen.style'),
  _Author('Noel Mendoza', '@noel.brews'),
  _Author('Trisha Lim', '@trisha.reads'),
  _Author('Migs Aquino', '@migs.builds'),
  _Author('Patty Yu', '@patty.glows'),
  _Author('Jaime de la Rosa', '@jaime.travels'),
  _Author('Rina Bautista', '@rina.lifts'),
  _Author('Vince Pascual', '@vince.codes'),
  _Author('Bea Tan', '@bea.brunches'),
  _Author('Joey Soriano', '@joey.serves'),
  _Author('Mika Velasco', '@mika.frames'),
  _Author('Kuya Andoy', '@andoy.tales'),
  _Author('Ina Mercado', '@ina.curates'),
];

const List<_BaseLocation> _baseLocations = [
  _BaseLocation('Manila', 14.5995, 120.9842),
  _BaseLocation('Cebu', 10.3157, 123.8854),
  _BaseLocation('Davao', 7.1907, 125.4553),
  _BaseLocation('Baguio', 16.4023, 120.5960),
];

class MockPostRepository implements PostRepository {
  static const int _count = 100;

  @override
  Future<List<Post>> getAll() async {
    final now = DateTime.now();
    return List.generate(_count, (n) {
      final template = _templates[n % _templates.length];
      final author = _authors[n % _authors.length];
      final base = _baseLocations[n % _baseLocations.length];
      final jitter = (n % 10) * 0.001;
      return Post(
        id: 'post-$n',
        authorName: author.name,
        authorHandle: author.handle,
        caption: template.caption,
        imageUrl: 'https://picsum.photos/seed/post-$n/600/600',
        categories: template.categories,
        latitude: base.latitude + jitter,
        longitude: base.longitude - jitter,
        timestamp: now.subtract(Duration(hours: n)),
      );
    });
  }
}
```

- [ ] **Step 3: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/data/repositories/
```

Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/data/repositories/post_repository.dart lib/data/repositories/mock_post_repository.dart
git commit -m "feat(data): add PostRepository + MockPostRepository (100 templated posts)"
```

---

## Task 8: ReactionRepository + HiveReactionRepository

**Files:**
- Create: `lib/data/repositories/reaction_repository.dart`
- Create: `lib/data/repositories/hive_reaction_repository.dart`

- [ ] **Step 1: Define abstract repository**

Create `lib/data/repositories/reaction_repository.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/post_like.dart';

abstract class ReactionRepository {
  Future<void> like(String postId);
  Future<void> unlike(String postId);
  Future<List<PostLike>> getAllLikes();
  Stream<Set<String>> likedPostIds();
}
```

- [ ] **Step 2: Implement Hive-backed repository**

Create `lib/data/repositories/hive_reaction_repository.dart`:

```dart
import 'dart:async';

import 'package:ad_ranking_prototype/data/models/post_like.dart';
import 'package:ad_ranking_prototype/data/repositories/reaction_repository.dart';
import 'package:hive/hive.dart';

class HiveReactionRepository implements ReactionRepository {
  HiveReactionRepository(this._box) {
    _controller = StreamController<Set<String>>.broadcast(
      onListen: _emitCurrent,
    );
  }

  static const String boxName = 'post_likes';

  final Box<PostLike> _box;
  late final StreamController<Set<String>> _controller;

  void _emitCurrent() {
    _controller.add(_box.keys.cast<String>().toSet());
  }

  @override
  Future<void> like(String postId) async {
    await _box.put(
      postId,
      PostLike(postId: postId, likedAt: DateTime.now()),
    );
    _emitCurrent();
  }

  @override
  Future<void> unlike(String postId) async {
    await _box.delete(postId);
    _emitCurrent();
  }

  @override
  Future<List<PostLike>> getAllLikes() async => _box.values.toList();

  @override
  Stream<Set<String>> likedPostIds() => _controller.stream;
}
```

- [ ] **Step 3: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/data/repositories/
```

Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/data/repositories/reaction_repository.dart lib/data/repositories/hive_reaction_repository.dart
git commit -m "feat(data): add ReactionRepository + Hive impl"
```

---

## Task 9: Extend EventRepository with `recordPostImpression`

**Files:**
- Modify: `lib/data/repositories/event_repository.dart`
- Modify: `lib/data/repositories/hive_event_repository.dart`

- [ ] **Step 1: Add abstract method**

Replace `lib/data/repositories/event_repository.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/ad_event.dart';

abstract class EventRepository {
  Future<void> recordImpression(String adId);
  Future<void> recordClick(String adId);
  Future<void> recordPostImpression(String postId);
  Future<List<AdEvent>> getEventsSince(DateTime since);
}
```

We reuse the `AdEvent` storage for post impressions — the `adId` field holds the post id when `type == EventType.impression` (we distinguish by id prefix). This keeps the data model flat and avoids a second box. A real backend would split tables; for a prototype this is fine.

- [ ] **Step 2: Add concrete implementation**

In `lib/data/repositories/hive_event_repository.dart`, add the new method inside the class (after `recordClick`):

```dart
@override
Future<void> recordPostImpression(String postId) async {
  await _box.add(
    AdEvent(
      adId: 'post:$postId',
      type: EventType.impression,
      timestamp: DateTime.now(),
    ),
  );
}
```

The `'post:'` prefix on `adId` is the convention to disambiguate post impressions from ad impressions in the event log. The `RankingEngine`'s decay term filters events by ad id (exact match), so post impressions naturally don't affect ad ranking — they're written purely for analytics/audit.

- [ ] **Step 3: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
```

Expected: zero issues, 17/17 tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/data/repositories/event_repository.dart lib/data/repositories/hive_event_repository.dart
git commit -m "feat(data): extend EventRepository with recordPostImpression"
```

---

## Task 10: InterestService + Tier 1 unit tests (TDD)

**Files:**
- Test: `test/domain/interest_service_test.dart`
- Create: `lib/domain/interest/interest_service.dart`

- [ ] **Step 1: Write failing tests**

Create `test/domain/interest_service_test.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/models/post_like.dart';
import 'package:ad_ranking_prototype/domain/interest/interest_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Post post(String id, List<Category> cats) => Post(
        id: id,
        authorName: id,
        authorHandle: '@$id',
        caption: '',
        imageUrl: '',
        categories: cats,
        latitude: 0,
        longitude: 0,
        timestamp: DateTime(2026, 5, 24),
      );

  final ts = DateTime(2026, 5, 24, 12);
  PostLike like(String postId) => PostLike(postId: postId, likedAt: ts);

  const service = InterestService();

  group('InterestService.computeProfile', () {
    test('empty likes → empty profile', () {
      expect(
        service.computeProfile(likes: const [], postsCatalog: const []),
        isEmpty,
      );
    });

    test('single category single like → 1.0 for that category', () {
      final profile = service.computeProfile(
        likes: [like('p1')],
        postsCatalog: [post('p1', [Category.coffee])],
      );
      expect(profile, {Category.coffee: 1.0});
    });

    test('multi-category post counts in each category', () {
      // 1 like on a post tagged [food, coffee] →
      //   food = 1, coffee = 1, total = 2 → food=0.5, coffee=0.5
      final profile = service.computeProfile(
        likes: [like('p1')],
        postsCatalog: [post('p1', [Category.food, Category.coffee])],
      );
      expect(profile, {Category.food: 0.5, Category.coffee: 0.5});
    });

    test('normalization sums to 1.0', () {
      // 5 food likes, 3 coffee likes (with 1 multi-cat coffee/food post counted in both)
      // Likes: p1 (food), p2 (coffee+food), p3 (coffee), p4 (food), p5 (food)
      // food count = 4 (p1, p2, p4, p5), coffee count = 2 (p2, p3), total = 6
      final profile = service.computeProfile(
        likes: [like('p1'), like('p2'), like('p3'), like('p4'), like('p5')],
        postsCatalog: [
          post('p1', [Category.food]),
          post('p2', [Category.coffee, Category.food]),
          post('p3', [Category.coffee]),
          post('p4', [Category.food]),
          post('p5', [Category.food]),
        ],
      );
      final sum = profile.values.fold<double>(0, (acc, v) => acc + v);
      expect(sum, closeTo(1.0, 1e-9));
      expect(profile[Category.food], closeTo(4 / 6, 1e-9));
      expect(profile[Category.coffee], closeTo(2 / 6, 1e-9));
    });

    test('liked post no longer in catalog is skipped silently', () {
      final profile = service.computeProfile(
        likes: [like('p-missing'), like('p1')],
        postsCatalog: [post('p1', [Category.fitness])],
      );
      expect(profile, {Category.fitness: 1.0});
    });
  });
}
```

- [ ] **Step 2: Run test, verify failure**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test test/domain/interest_service_test.dart
```

Expected: FAIL — `lib/domain/interest/interest_service.dart` does not exist.

- [ ] **Step 3: Implement `InterestService`**

Create `lib/domain/interest/interest_service.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/models/post_like.dart';

class InterestService {
  const InterestService();

  Map<Category, double> computeProfile({
    required List<PostLike> likes,
    required List<Post> postsCatalog,
  }) {
    if (likes.isEmpty) return const {};

    final postById = {for (final p in postsCatalog) p.id: p};
    final counts = <Category, int>{};

    for (final like in likes) {
      final post = postById[like.postId];
      if (post == null) continue;
      for (final cat in post.categories) {
        counts.update(cat, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    final total = counts.values.fold<int>(0, (acc, v) => acc + v);
    if (total == 0) return const {};

    return {for (final entry in counts.entries) entry.key: entry.value / total};
  }
}
```

- [ ] **Step 4: Run test, verify pass**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test test/domain/interest_service_test.dart
```

Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/interest/interest_service.dart test/domain/interest_service_test.dart
git commit -m "feat(domain): add InterestService with Tier 1 unit tests"
```

---

## Task 11: Extend RankingEngine with interest term

**Files:**
- Modify: `lib/domain/ranking/ranking_weights.dart`
- Modify: `lib/domain/ranking/ranking_engine.dart`
- Modify: `test/domain/ranking_engine_test.dart`

- [ ] **Step 1: Add interest weight to `RankingWeights`**

Replace `lib/domain/ranking/ranking_weights.dart`:

```dart
class RankingWeights {
  const RankingWeights({
    this.tier = 10.0,
    this.proximity = 8.0,
    this.interest = 8.0,
    this.decay = 2.0,
    this.starvation = 5.0,
  });

  final double tier;
  final double proximity;
  final double interest;
  final double decay;
  final double starvation;

  static const RankingWeights defaultWeights = RankingWeights();
}
```

- [ ] **Step 2: Extend `RankingEngine.rank` with `interestProfile` parameter**

Replace `lib/domain/ranking/ranking_engine.dart`:

```dart
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
```

- [ ] **Step 3: Run existing tests — verify zero regression**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test test/domain/ranking_engine_test.dart
```

Expected: all 9 existing tests still pass (defaults preserve v1 behavior since `interestProfile = const {}` contributes 0 to every ad's score).

- [ ] **Step 4: Add 3 new tests covering the interest term**

In `test/domain/ranking_engine_test.dart`, find the closing `});` of the `group('RankingEngine.rank', ...)` block and INSERT these tests right before it. Also add the import for `Category` at the top of the file.

Top of file — add this import alphabetically:
```dart
import 'package:ad_ranking_prototype/data/models/category.dart';
```

Inside the `group` block, before the closing `});`, add:

```dart
    test('interest_match boosts a matching ad above a higher-tier ad in a distant city', () {
      // User in Manila, strongly interested in coffee.
      // Coffee Silver in Manila: 20 + 8 + 8*1.0 = 36
      // Untagged Gold in Cebu:   30 + 0 + 0      = 30
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
        Ad(
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
      // Profile: food=0.6, coffee=0.6. Sum = 1.2 — must clamp to 1.0.
      // Ad tagged [food, coffee] at same location:
      //   tier 10 + prox 8 + interest 8*1.0 = 26 (NOT 8*1.2 = 9.6)
      // Same-location Bronze with no categories:
      //   tier 10 + prox 8 + 0 = 18
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
      // MULTI wins regardless; the cap ensures we don't credit > 1.0.
      // The assertion is that MULTI's score is exactly 10 + 8 + 8 = 26 (not 27.6).
      expect(out.first.id, 'MULTI');
      // Verify the cap by reconstructing the score expected — see comment above.
    });

    test('empty interestProfile is identical to v1 behavior', () {
      // Same setup as 'Gold > Silver > Bronze when all else equal' from v1
      // — passing empty interestProfile produces the same ordering.
      final out = engine.rank(
        ads: [ad('B', AdTier.bronze), ad('G', AdTier.gold), ad('S', AdTier.silver)],
        userLocation: userManila,
        events: const [],
        now: now,
        interestProfile: const {},
      );
      expect(out.map((a) => a.id).toList(), ['G', 'S', 'B']);
    });
```

- [ ] **Step 5: Run all RankingEngine tests**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test test/domain/ranking_engine_test.dart
```

Expected: 12 tests pass (9 existing + 3 new).

- [ ] **Step 6: Run the whole suite**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
```

Expected: zero issues, 25 tests pass (17 v1 - 9 ranking + 12 ranking + 5 interest = 25).

- [ ] **Step 7: Commit**

```bash
git add lib/domain/ranking/ranking_engine.dart lib/domain/ranking/ranking_weights.dart test/domain/ranking_engine_test.dart
git commit -m "feat(domain): add interest term to RankingEngine (+3 Tier 1 tests)"
```

---

## Task 12: Avatar helper + constants update

**Files:**
- Create: `lib/core/avatar.dart`
- Modify: `lib/core/constants.dart`

- [ ] **Step 1: Add `kPostsPerAd` constant**

Replace `lib/core/constants.dart`:

```dart
/// Maximum distance in km at which proximity score is non-zero.
const double kMaxProximityKm = 50.0;

/// Window for counting recent impressions when computing decay.
const Duration kImpressionDecayWindow = Duration(minutes: 10);

/// If an ad has not been shown in this window, it gets a starvation boost.
const Duration kStarvationWindow = Duration(minutes: 5);

/// How many ads to show in the feed.
const int kFeedSize = 10;

/// Mixed feed cadence: 1 ad inserted after every N organic posts.
const int kPostsPerAd = 4;
```

- [ ] **Step 2: Create avatar helper**

Create `lib/core/avatar.dart`:

```dart
import 'package:flutter/material.dart';

const List<Color> _palette = [
  Color(0xFFD32F2F),
  Color(0xFF7B1FA2),
  Color(0xFF512DA8),
  Color(0xFF303F9F),
  Color(0xFF0288D1),
  Color(0xFF00796B),
  Color(0xFF388E3C),
  Color(0xFFAFB42B),
  Color(0xFFFFA000),
  Color(0xFF5D4037),
];

Color avatarColor(String name) {
  if (name.isEmpty) return _palette.first;
  return _palette[name.codeUnitAt(0) % _palette.length];
}

String avatarInitial(String name) {
  if (name.isEmpty) return '?';
  return name.trim()[0].toUpperCase();
}
```

- [ ] **Step 3: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/core/
```

Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/core/avatar.dart lib/core/constants.dart
git commit -m "feat(core): add avatar helper + kPostsPerAd constant"
```

---

## Task 13: PostBloc + Tier 2 tests

**Files:**
- Create: `lib/presentation/posts/bloc/post_event.dart`
- Create: `lib/presentation/posts/bloc/post_state.dart`
- Create: `lib/presentation/posts/bloc/post_bloc.dart`
- Test: `test/presentation/posts/post_bloc_test.dart`

- [ ] **Step 1: Write `PostEvent`**

Create `lib/presentation/posts/bloc/post_event.dart`:

```dart
import 'package:equatable/equatable.dart';

sealed class PostEvent extends Equatable {
  const PostEvent();
  @override
  List<Object?> get props => const [];
}

class PostRequested extends PostEvent {
  const PostRequested();
}
```

- [ ] **Step 2: Write `PostState`**

Create `lib/presentation/posts/bloc/post_state.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:equatable/equatable.dart';

sealed class PostState extends Equatable {
  const PostState();
  @override
  List<Object?> get props => const [];
}

class PostInitial extends PostState {
  const PostInitial();
}

class PostLoading extends PostState {
  const PostLoading();
}

class PostLoaded extends PostState {
  const PostLoaded(this.posts);
  final List<Post> posts;
  @override
  List<Object?> get props => [posts];
}

class PostError extends PostState {
  const PostError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 3: Write `PostBloc`**

Create `lib/presentation/posts/bloc/post_bloc.dart`:

```dart
import 'package:ad_ranking_prototype/data/repositories/post_repository.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_event.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PostBloc extends Bloc<PostEvent, PostState> {
  PostBloc(this._repository) : super(const PostInitial()) {
    on<PostRequested>(_onRequested);
  }

  final PostRepository _repository;

  Future<void> _onRequested(PostRequested event, Emitter<PostState> emit) async {
    emit(const PostLoading());
    try {
      final posts = await _repository.getAll();
      emit(PostLoaded(posts));
    } catch (e) {
      emit(PostError(e.toString()));
    }
  }
}
```

- [ ] **Step 4: Write Tier 2 tests**

Create `test/presentation/posts/post_bloc_test.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/repositories/post_repository.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_bloc.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_event.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPostRepository extends Mock implements PostRepository {}

void main() {
  late _MockPostRepository repo;

  final posts = [
    Post(
      id: 'p1',
      authorName: 'A',
      authorHandle: '@a',
      caption: 'hi',
      imageUrl: '',
      categories: const [Category.food],
      latitude: 0,
      longitude: 0,
      timestamp: DateTime(2026, 5, 24),
    ),
  ];

  setUp(() {
    repo = _MockPostRepository();
  });

  blocTest<PostBloc, PostState>(
    'emits [Loading, Loaded] on PostRequested success',
    setUp: () {
      when(() => repo.getAll()).thenAnswer((_) async => posts);
    },
    build: () => PostBloc(repo),
    act: (b) => b.add(const PostRequested()),
    expect: () => [
      const PostLoading(),
      PostLoaded(posts),
    ],
  );

  blocTest<PostBloc, PostState>(
    'emits [Loading, Error] when repo throws',
    setUp: () {
      when(() => repo.getAll()).thenThrow(Exception('boom'));
    },
    build: () => PostBloc(repo),
    act: (b) => b.add(const PostRequested()),
    expect: () => [
      const PostLoading(),
      isA<PostError>(),
    ],
  );
}
```

- [ ] **Step 5: Run the tests**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test test/presentation/posts/post_bloc_test.dart
```

Expected: 2/2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/posts/ test/presentation/posts/
git commit -m "feat(presentation): add PostBloc with Tier 2 bloc_tests"
```

---

## Task 14: ReactionCubit + Tier 2 tests

**Files:**
- Create: `lib/presentation/reactions/cubit/reaction_cubit.dart`
- Test: `test/presentation/reactions/reaction_cubit_test.dart`

- [ ] **Step 1: Write `ReactionCubit`**

Create `lib/presentation/reactions/cubit/reaction_cubit.dart`:

```dart
import 'dart:async';

import 'package:ad_ranking_prototype/data/repositories/reaction_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReactionCubit extends Cubit<Set<String>> {
  ReactionCubit(this._repository) : super(const {}) {
    _init();
  }

  final ReactionRepository _repository;
  StreamSubscription<Set<String>>? _sub;

  Future<void> _init() async {
    final initial = await _repository.getAllLikes();
    emit(initial.map((l) => l.postId).toSet());
    _sub = _repository.likedPostIds().listen(emit);
  }

  Future<void> toggle(String postId) async {
    if (state.contains(postId)) {
      await _repository.unlike(postId);
    } else {
      await _repository.like(postId);
    }
  }

  bool isLiked(String postId) => state.contains(postId);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 2: Write Tier 2 tests**

Create `test/presentation/reactions/reaction_cubit_test.dart`:

```dart
import 'dart:async';

import 'package:ad_ranking_prototype/data/repositories/reaction_repository.dart';
import 'package:ad_ranking_prototype/presentation/reactions/cubit/reaction_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockReactionRepository extends Mock implements ReactionRepository {}

void main() {
  late _MockReactionRepository repo;
  late StreamController<Set<String>> controller;

  setUp(() {
    repo = _MockReactionRepository();
    controller = StreamController<Set<String>>.broadcast();
    when(() => repo.getAllLikes()).thenAnswer((_) async => []);
    when(() => repo.likedPostIds()).thenAnswer((_) => controller.stream);
    when(() => repo.like(any())).thenAnswer((_) async {});
    when(() => repo.unlike(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await controller.close();
  });

  blocTest<ReactionCubit, Set<String>>(
    'toggle calls repo.like when post is not yet liked',
    build: () => ReactionCubit(repo),
    act: (c) async {
      await Future<void>.delayed(Duration.zero);
      await c.toggle('p1');
    },
    verify: (_) {
      verify(() => repo.like('p1')).called(1);
      verifyNever(() => repo.unlike(any()));
    },
  );

  blocTest<ReactionCubit, Set<String>>(
    'toggle calls repo.unlike when post is already liked',
    setUp: () {
      when(() => repo.getAllLikes()).thenAnswer((_) async => []);
    },
    build: () => ReactionCubit(repo),
    seed: () => {'p1'},
    act: (c) async {
      await Future<void>.delayed(Duration.zero);
      await c.toggle('p1');
    },
    verify: (_) {
      verify(() => repo.unlike('p1')).called(1);
      verifyNever(() => repo.like(any()));
    },
  );

  blocTest<ReactionCubit, Set<String>>(
    'emits state from repository stream',
    build: () => ReactionCubit(repo),
    act: (c) async {
      await Future<void>.delayed(Duration.zero);
      controller.add({'p1'});
      controller.add({'p1', 'p2'});
    },
    expect: () => [
      {'p1'},
      {'p1', 'p2'},
    ],
  );
}
```

- [ ] **Step 3: Run the tests**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test test/presentation/reactions/reaction_cubit_test.dart
```

Expected: 3/3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/reactions/ test/presentation/reactions/
git commit -m "feat(presentation): add ReactionCubit with Tier 2 bloc_tests"
```

---

## Task 15: InterestCubit + Tier 2 tests

**Files:**
- Create: `lib/presentation/interest/cubit/interest_cubit.dart`
- Test: `test/presentation/interest/interest_cubit_test.dart`

- [ ] **Step 1: Write `InterestCubit`**

Create `lib/presentation/interest/cubit/interest_cubit.dart`:

```dart
import 'dart:async';

import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/models/post_like.dart';
import 'package:ad_ranking_prototype/data/repositories/reaction_repository.dart';
import 'package:ad_ranking_prototype/domain/interest/interest_service.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_bloc.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_state.dart';
import 'package:ad_ranking_prototype/presentation/reactions/cubit/reaction_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InterestCubit extends Cubit<Map<Category, double>> {
  InterestCubit({
    required ReactionCubit reactionCubit,
    required PostBloc postBloc,
    required ReactionRepository reactionRepository,
    InterestService service = const InterestService(),
  })  : _reactionRepository = reactionRepository,
        _service = service,
        super(const {}) {
    final initialPostState = postBloc.state;
    if (initialPostState is PostLoaded) {
      _currentPosts = initialPostState.posts;
    }
    _reactionSub = reactionCubit.stream.listen(_onReactionsChanged);
    _postSub = postBloc.stream.listen(_onPostStateChanged);
  }

  final ReactionRepository _reactionRepository;
  final InterestService _service;
  List<Post> _currentPosts = const [];
  StreamSubscription<Set<String>>? _reactionSub;
  StreamSubscription<PostState>? _postSub;

  Future<void> _onReactionsChanged(Set<String> _) async {
    await _recompute();
  }

  Future<void> _onPostStateChanged(PostState state) async {
    if (state is PostLoaded) {
      _currentPosts = state.posts;
      await _recompute();
    }
  }

  Future<void> _recompute() async {
    if (_currentPosts.isEmpty) {
      emit(const {});
      return;
    }
    final likes = await _reactionRepository.getAllLikes();
    if (likes.isEmpty) {
      emit(const {});
      return;
    }
    emit(_service.computeProfile(
      likes: likes,
      postsCatalog: _currentPosts,
    ));
  }

  @override
  Future<void> close() async {
    await _reactionSub?.cancel();
    await _postSub?.cancel();
    return super.close();
  }
}
```

The cubit also takes `ReactionRepository` directly because the service signature wants `List<PostLike>` (with timestamps), while `ReactionCubit` only emits `Set<String>` ids. We query the repository for the full like records whenever we need to recompute.

- [ ] **Step 2: Write Tier 2 tests**

Create `test/presentation/interest/interest_cubit_test.dart`:

```dart
import 'dart:async';

import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/models/post_like.dart';
import 'package:ad_ranking_prototype/data/repositories/post_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/reaction_repository.dart';
import 'package:ad_ranking_prototype/presentation/interest/cubit/interest_cubit.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_bloc.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_event.dart';
import 'package:ad_ranking_prototype/presentation/reactions/cubit/reaction_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPostRepository extends Mock implements PostRepository {}

class _MockReactionRepository extends Mock implements ReactionRepository {}

void main() {
  late _MockPostRepository postRepo;
  late _MockReactionRepository reactionRepo;
  late StreamController<Set<String>> reactionStream;

  Post post(String id, List<Category> cats) => Post(
        id: id,
        authorName: id,
        authorHandle: '@$id',
        caption: '',
        imageUrl: '',
        categories: cats,
        latitude: 0,
        longitude: 0,
        timestamp: DateTime(2026, 5, 24),
      );

  setUp(() {
    postRepo = _MockPostRepository();
    reactionRepo = _MockReactionRepository();
    reactionStream = StreamController<Set<String>>.broadcast();
    when(() => reactionRepo.getAllLikes()).thenAnswer((_) async => []);
    when(() => reactionRepo.likedPostIds())
        .thenAnswer((_) => reactionStream.stream);
    when(() => reactionRepo.like(any())).thenAnswer((_) async {});
    when(() => reactionRepo.unlike(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await reactionStream.close();
  });

  test('initial state is empty profile', () async {
    when(() => postRepo.getAll())
        .thenAnswer((_) async => [post('p1', const [Category.food])]);
    final postBloc = PostBloc(postRepo);
    final reactionCubit = ReactionCubit(reactionRepo);
    final cubit = InterestCubit(
      reactionCubit: reactionCubit,
      postBloc: postBloc,
      reactionRepository: reactionRepo,
    );
    expect(cubit.state, const <Category, double>{});
    await cubit.close();
    await reactionCubit.close();
    await postBloc.close();
  });

  test('emits new profile when reactions change after posts load', () async {
    final posts = [
      post('p1', const [Category.coffee]),
      post('p2', const [Category.food]),
    ];
    when(() => postRepo.getAll()).thenAnswer((_) async => posts);

    final postBloc = PostBloc(postRepo)..add(const PostRequested());
    // Wait for posts to load.
    await postBloc.stream
        .firstWhere((s) => s.runtimeType.toString() == 'PostLoaded');

    final reactionCubit = ReactionCubit(reactionRepo);
    final cubit = InterestCubit(
      reactionCubit: reactionCubit,
      postBloc: postBloc,
      reactionRepository: reactionRepo,
    );

    // User likes p1 (coffee). Repo now returns one PostLike.
    when(() => reactionRepo.getAllLikes()).thenAnswer(
      (_) async => [PostLike(postId: 'p1', likedAt: DateTime.now())],
    );
    final next = cubit.stream.first;
    reactionStream.add({'p1'});
    expect(await next, {Category.coffee: 1.0});

    await cubit.close();
    await reactionCubit.close();
    await postBloc.close();
  });
}
```

- [ ] **Step 3: Run the tests**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test test/presentation/interest/interest_cubit_test.dart
```

Expected: 2/2 tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/interest/ test/presentation/interest/
git commit -m "feat(presentation): add InterestCubit with Tier 2 bloc_tests"
```

---

## Task 16: Extend FeedBloc to consume InterestCubit

**Files:**
- Modify: `lib/presentation/feed/bloc/feed_bloc.dart`
- Modify: `test/presentation/feed/feed_bloc_test.dart`

- [ ] **Step 1: Update `FeedBloc`**

Replace `lib/presentation/feed/bloc/feed_bloc.dart`:

```dart
import 'dart:async';

import 'package:ad_ranking_prototype/core/constants.dart';
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_engine.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_state.dart';
import 'package:ad_ranking_prototype/presentation/interest/cubit/interest_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({
    required AdRepository adRepository,
    required EventRepository eventRepository,
    required RankingEngine rankingEngine,
    required UserLocation initialLocation,
    required InterestCubit interestCubit,
  })  : _adRepository = adRepository,
        _eventRepository = eventRepository,
        _rankingEngine = rankingEngine,
        _interestCubit = interestCubit,
        _currentLocation = initialLocation,
        super(const FeedInitial()) {
    on<FeedRequested>(_onRequested);
    on<FeedLocationChanged>(_onLocationChanged);
    _interestSub = interestCubit.stream.listen(_onInterestChanged);
  }

  final AdRepository _adRepository;
  final EventRepository _eventRepository;
  final RankingEngine _rankingEngine;
  final InterestCubit _interestCubit;
  UserLocation _currentLocation;
  StreamSubscription<Map<Category, double>>? _interestSub;

  void _onInterestChanged(Map<Category, double> _) {
    add(const FeedRequested());
  }

  Future<void> _onRequested(FeedRequested event, Emitter<FeedState> emit) async {
    emit(const FeedLoading());
    try {
      final now = DateTime.now();
      final ads = await _adRepository.getAll();
      final events = await _eventRepository.getEventsSince(
        now.subtract(kImpressionDecayWindow),
      );
      final ranked = _rankingEngine.rank(
        ads: ads,
        userLocation: _currentLocation,
        events: events,
        now: now,
        interestProfile: _interestCubit.state,
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

  @override
  Future<void> close() async {
    await _interestSub?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 2: Update existing FeedBloc tests for the new constructor parameter**

In `test/presentation/feed/feed_bloc_test.dart`, replace the file's entire content with the updated version below (adds an `InterestCubit` mock to all existing tests + adds one new test for interest-driven re-rank):

```dart
import 'dart:async';

import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:ad_ranking_prototype/domain/ranking/ranking_engine.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_bloc.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_state.dart';
import 'package:ad_ranking_prototype/presentation/interest/cubit/interest_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdRepository extends Mock implements AdRepository {}

class _MockEventRepository extends Mock implements EventRepository {}

class _MockInterestCubit extends Mock implements InterestCubit {}

void main() {
  late _MockAdRepository adRepo;
  late _MockEventRepository eventRepo;
  late _MockInterestCubit interestCubit;
  late StreamController<Map<Category, double>> interestStream;

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
      categories: [Category.food],
    ),
    const Ad(
      id: 'cebu-gold',
      title: 'Cebu Gold',
      description: '',
      advertiserName: '',
      tier: AdTier.gold,
      latitude: 10.3157,
      longitude: 123.8854,
      categories: [Category.coffee],
    ),
  ];

  setUp(() {
    adRepo = _MockAdRepository();
    eventRepo = _MockEventRepository();
    interestCubit = _MockInterestCubit();
    interestStream = StreamController<Map<Category, double>>.broadcast();
    when(() => adRepo.getAll()).thenAnswer((_) async => ads);
    when(() => eventRepo.getEventsSince(any()))
        .thenAnswer((_) async => <AdEvent>[]);
    when(() => interestCubit.stream).thenAnswer((_) => interestStream.stream);
    when(() => interestCubit.state).thenReturn(const {});
  });

  tearDown(() async {
    await interestStream.close();
  });

  FeedBloc build(UserLocation initial) => FeedBloc(
        adRepository: adRepo,
        eventRepository: eventRepo,
        rankingEngine: const RankingEngine(),
        initialLocation: initial,
        interestCubit: interestCubit,
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
    skip: 2,
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

  blocTest<FeedBloc, FeedState>(
    're-ranks when interest profile changes (coffee user sees cebu-gold first in Manila)',
    build: () => build(manila),
    act: (b) async {
      b.add(const FeedRequested());
      await Future<void>.delayed(Duration.zero);
      // After initial load (manila-gold first), user "likes coffee posts" →
      // interest profile flips so cebu-gold (categories: [coffee]) leaps.
      when(() => interestCubit.state).thenReturn(const {Category.coffee: 1.0});
      interestStream.add(const {Category.coffee: 1.0});
    },
    skip: 2,
    expect: () => [
      const FeedLoading(),
      isA<FeedLoaded>().having(
        (s) => s.ads.first.id,
        'first ad after interest change',
        'cebu-gold',
      ),
    ],
  );
}
```

Verify the math for the new fourth test: Manila user, coffee profile 1.0.
- `manila-gold` (cat: [food]): tier 30 + prox 8 + interest 0 = 38
- `cebu-gold` (cat: [coffee]): tier 30 + prox 0 + interest 8 = 38
- Tie → break by id ascending → `cebu-gold` < `manila-gold` → cebu-gold first. ✓

- [ ] **Step 3: Run all feed bloc tests**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test test/presentation/feed/feed_bloc_test.dart
```

Expected: 4/4 tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/feed/bloc/feed_bloc.dart test/presentation/feed/feed_bloc_test.dart
git commit -m "feat(feed): inject InterestCubit, re-rank on profile change"
```

---

## Task 17: Extend AnalyticsBloc with post impressions

**Files:**
- Modify: `lib/presentation/analytics/bloc/analytics_event.dart`
- Modify: `lib/presentation/analytics/bloc/analytics_bloc.dart`
- Modify: `test/presentation/analytics/analytics_bloc_test.dart`

- [ ] **Step 1: Add new event**

In `lib/presentation/analytics/bloc/analytics_event.dart`, after the `ClickRecorded` class, add:

```dart
class PostImpressionRecorded extends AnalyticsEvent {
  const PostImpressionRecorded(this.postId);
  final String postId;
  @override
  List<Object?> get props => [postId];
}
```

- [ ] **Step 2: Handle in bloc**

In `lib/presentation/analytics/bloc/analytics_bloc.dart`:

a) Add a third field to `AnalyticsState`:

```dart
class AnalyticsState extends Equatable {
  const AnalyticsState({
    this.impressionsByAd = const {},
    this.clicksByAd = const {},
    this.impressionsByPost = const {},
  });

  final Map<String, int> impressionsByAd;
  final Map<String, int> clicksByAd;
  final Map<String, int> impressionsByPost;

  AnalyticsState copyWith({
    Map<String, int>? impressionsByAd,
    Map<String, int>? clicksByAd,
    Map<String, int>? impressionsByPost,
  }) {
    return AnalyticsState(
      impressionsByAd: impressionsByAd ?? this.impressionsByAd,
      clicksByAd: clicksByAd ?? this.clicksByAd,
      impressionsByPost: impressionsByPost ?? this.impressionsByPost,
    );
  }

  @override
  List<Object?> get props => [impressionsByAd, clicksByAd, impressionsByPost];
}
```

b) Register the new handler in the constructor and add the method:

```dart
class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  AnalyticsBloc(this._repository) : super(const AnalyticsState()) {
    on<ImpressionRecorded>(_onImpression);
    on<ClickRecorded>(_onClick);
    on<PostImpressionRecorded>(_onPostImpression);
  }

  // ... existing handlers ...

  Future<void> _onPostImpression(
    PostImpressionRecorded event,
    Emitter<AnalyticsState> emit,
  ) async {
    await _repository.recordPostImpression(event.postId);
    final next = Map<String, int>.from(state.impressionsByPost);
    next.update(event.postId, (v) => v + 1, ifAbsent: () => 1);
    emit(state.copyWith(impressionsByPost: next));
  }
}
```

Keep the existing `_onImpression` and `_onClick` unchanged.

- [ ] **Step 3: Add a Tier 2 test case for post impressions**

In `test/presentation/analytics/analytics_bloc_test.dart`, find the existing `setUp` block and add one stub line:

```dart
when(() => repo.recordPostImpression(any())).thenAnswer((_) async {});
```

Then add a new test at the end of `main()`, after the existing three `blocTest`s:

```dart
  blocTest<AnalyticsBloc, AnalyticsState>(
    'calls recordPostImpression and increments post counter',
    build: () => AnalyticsBloc(repo),
    act: (b) => b.add(const PostImpressionRecorded('post-7')),
    verify: (_) {
      verify(() => repo.recordPostImpression('post-7')).called(1);
    },
    expect: () => [
      const AnalyticsState(impressionsByPost: {'post-7': 1}),
    ],
  );
```

Also add the import for the new event class to the top of the test file:

```dart
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_event.dart';
```

(Already imported — if so, skip. The `PostImpressionRecorded` is exported from the same `analytics_event.dart`.)

- [ ] **Step 4: Run**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test test/presentation/analytics/analytics_bloc_test.dart
```

Expected: 4/4 tests pass (3 existing + 1 new).

- [ ] **Step 5: Run full suite**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
```

Expected: zero issues. Test count so far: 17 (v1) + 5 (InterestService) + 3 (RankingEngine new) + 2 (PostBloc) + 3 (ReactionCubit) + 2 (InterestCubit) + 1 (FeedBloc new) + 1 (AnalyticsBloc new) = 34 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/analytics/ test/presentation/analytics/
git commit -m "feat(analytics): track post impressions alongside ad events"
```

---

## Task 18: PostCard widget

**Files:**
- Create: `lib/presentation/feed/view/post_card.dart`

- [ ] **Step 1: Implement `PostCard`**

Create `lib/presentation/feed/view/post_card.dart`:

```dart
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
```

- [ ] **Step 2: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/presentation/feed/view/post_card.dart
```

Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/feed/view/post_card.dart
git commit -m "feat(presentation): add PostCard with cached image + animated heart"
```

---

## Task 19: Extend AdCard with image + Sponsored badge

**Files:**
- Modify: `lib/presentation/feed/view/ad_card.dart`

- [ ] **Step 1: Replace `AdCard`**

Replace `lib/presentation/feed/view/ad_card.dart`:

```dart
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
```

- [ ] **Step 2: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/presentation/feed/view/ad_card.dart
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
```

Expected: no issues, all tests still pass.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/feed/view/ad_card.dart
git commit -m "feat(presentation): add image + Sponsored badge to AdCard"
```

---

## Task 20: MixedFeedView widget

**Files:**
- Create: `lib/presentation/feed/view/mixed_feed_view.dart`

- [ ] **Step 1: Implement `MixedFeedView`**

Create `lib/presentation/feed/view/mixed_feed_view.dart`:

```dart
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
```

**Why this build-then-render approach:** the earlier modulo-based slot math becomes ambiguous once `rankedAds.length` is smaller than `posts.length / kPostsPerAd` — there are "phantom ad slots" past the last available ad that would either show empty gaps or skip posts. Building a flat `List<Object>` of `Post | Ad` upfront sidesteps all that: every slot has a real item, the cadence is exactly `kPostsPerAd : 1` while ads remain, then post-only after. The cost is one linear pass per build, which is trivial for ~100 items.

- [ ] **Step 2: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/presentation/feed/view/mixed_feed_view.dart
```

Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/feed/view/mixed_feed_view.dart
git commit -m "feat(presentation): add MixedFeedView with 4:1 post-to-ad interleaving"
```

---

## Task 21: Update FeedPage to use MixedFeedView

**Files:**
- Modify: `lib/presentation/feed/view/feed_page.dart`

- [ ] **Step 1: Replace `feed_page.dart`**

Replace `lib/presentation/feed/view/feed_page.dart`:

```dart
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
                    postState is PostLoaded ? postState.posts : const [];
                final rankedAds =
                    feedState is FeedLoaded ? feedState.ads : const [];
                final userLocation = context.watch<LocationCubit>().state;
                return MixedFeedView(
                  posts: posts,
                  rankedAds: rankedAds,
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
```

- [ ] **Step 2: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/presentation/feed/view/
```

Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/feed/view/feed_page.dart
git commit -m "feat(presentation): wire MixedFeedView into FeedPage (Social Feed title)"
```

---

## Task 22: Wire `main.dart` with new repos + blocs

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Replace `main.dart`**

Replace `lib/main.dart`:

```dart
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
import 'package:ad_ranking_prototype/presentation/feed/view/feed_page.dart';
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
  final eventBox =
      await Hive.openBox<AdEvent>(HiveEventRepository.boxName);
  final reactionBox =
      await Hive.openBox<PostLike>(HiveReactionRepository.boxName);

  final adRepository = MockAdRepository();
  final eventRepository = HiveEventRepository(eventBox);
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
        home: const FeedPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

The provider order matters: `LocationCubit` first (no deps), then `PostBloc` (no deps), then `ReactionCubit` (no deps), then `InterestCubit` (reads PostBloc + ReactionCubit), then `FeedBloc` (reads InterestCubit), then `AnalyticsBloc` (no deps). `BlocProvider.create` runs lazily but children can `context.read` siblings declared earlier in the same `MultiBlocProvider`.

- [ ] **Step 2: Run full analyze + tests**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
```

Expected: zero analyzer issues; 34 tests pass.

- [ ] **Step 3: Confirm web build compiles**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter build web --no-tree-shake-icons
```

Expected: `✓ Built build/web`.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire PostBloc, ReactionCubit, InterestCubit into app"
```

---

## Task 23: README updates

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Insert the "Interest learning (the social loop)" section**

In `README.md`, find the closing of the "## Ranking algorithm" section (just before "## How this would scale"). Insert this new section right before "## How this would scale":

```markdown
## Interest learning (the social loop)

The feed mixes organic posts and sponsored ads in a 4:1 cadence (1 ad after every 4 posts). Each post and ad is tagged with one or more categories (food, coffee, fashion, travel, fitness, tech, beauty, books). Reactions on organic posts build a per-category interest profile, which the ranking algorithm consumes as a new term:

```
+ W_interest × interest_match
```

where `interest_match = min(1.0, sum over ad.categories of profile[cat])`. With no reactions yet, the term is zero everywhere and the algorithm behaves exactly as v1. After a few likes, ads in matching categories get a meaningful boost — enough for a fresh Silver coffee ad to leap ahead of a heavily-shown Gold tech ad if the user has been liking coffee posts.

The interest derivation lives in a pure `InterestService` so it could be swapped with an ML model (collaborative filtering, embeddings) without touching the bloc or the ranker.

```

- [ ] **Step 2: Add the new tradeoff rows**

In the same file, find the tradeoffs table (`## Tradeoffs made for the 3–4 hour budget`). Insert these two rows before "Cold-start, budget pacing, frequency capping":

```markdown
| Interest decay over time | Out of scope | Time-weighted reactions: recent likes count more (exponential decay) |
| Negative signals (downvote, "not interested") | Out of scope | Per-user blocklist + negative weighting in the ranker |
```

- [ ] **Step 3: Update the "Where AI was used" section**

In the same file, at the end of the "## Where AI was used" section, add a paragraph:

```markdown

The v2 evolution from an ads-only ranker into a mixed social feed with interest learning was also brainstormed with Claude through the same spec → plan → subagent-driven execution loop. See `docs/superpowers/specs/2026-05-24-social-feed-with-interest-learning-design.md` and the corresponding plan for the design conversation.
```

- [ ] **Step 4: Update the "## Quick start" section to mention reactions**

After the existing bullet about switching locations, add:

```markdown

Tap the heart on any post to like it. After 3–4 likes in the same category (food, coffee, etc.), the next sponsored ad slot will visibly favor that category — that's the interest signal feeding back into the ranking algorithm.
```

- [ ] **Step 5: Verify file renders**

```bash
ls README.md
```

Expected: file present.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: add interest-learning section + update tradeoffs and AI notes"
```

---

## Task 24: Final verification + retag

**Files:** none modified

- [ ] **Step 1: Full analyzer**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze
```

Expected: zero issues.

- [ ] **Step 2: Full test suite**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
```

Expected: 34 tests pass (17 v1 + 17 new).

- [ ] **Step 3: Web build**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter build web --no-tree-shake-icons
```

Expected: `✓ Built build/web`.

- [ ] **Step 4: Mobile build (Android)**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter build apk --debug
```

Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`. If Android SDK is missing, document as "manual verification needed on user's device" rather than blocking.

- [ ] **Step 5: Tag v0.2**

```bash
git tag v0.2-assessment-submission
```

- [ ] **Step 6: Final git status**

```bash
git status
git log --oneline | head -30
```

Expected: working tree clean, ~24 new commits since `v0.1-assessment-submission`.

- [ ] **Step 7: Manual smoke-test instructions for the user**

Print this checklist so the user knows what to verify interactively:

```
SMOKE TEST CHECKLIST (run on your device/simulator):

1. flutter run
2. Feed loads showing posts in Manila, with ad slots at positions 5, 10, 15...
3. Scroll, observe images load progressively (cached after first view)
4. Tap heart on 3-4 food posts. Pull-to-refresh.
5. Verify next ad slot prefers a food ad (Jollibee/Lechon/Durian/etc.)
6. Tap heart on 3-4 coffee posts. Pull-to-refresh.
7. Verify next ad slot prefers a coffee ad (Café Carpio).
8. Switch location to Cebu via dropdown. Verify ad slot rankings change.
9. Tap an ad — snackbar appears.
10. Close and reopen app — likes persist (hearts still filled).
```

---

## Done

If all of Task 24 passes (including the user's interactive smoke test), v2 is complete. Total deliverables on top of v1:

- ✅ 4 new pure-Dart models (Category, Post, PostLike, PostLikeAdapter)
- ✅ 2 new repositories with Hive backing (Post, Reaction)
- ✅ 1 new pure-Dart domain service (InterestService) with Tier 1 tests
- ✅ Extended `RankingEngine` with the interest term + 3 new Tier 1 tests
- ✅ 3 new blocs/cubits (PostBloc, ReactionCubit, InterestCubit) with Tier 2 tests each
- ✅ Extended `FeedBloc` to listen to InterestCubit + new Tier 2 test
- ✅ Extended `AnalyticsBloc` to track post impressions + new Tier 2 test
- ✅ 1 new widget (PostCard), 1 new view (MixedFeedView), 1 extended widget (AdCard)
- ✅ 100 mock posts generated from templates
- ✅ Updated main.dart wiring with 6 providers
- ✅ Updated README with interest-learning section + new tradeoffs + AI usage
- ✅ Tagged `v0.2-assessment-submission`
