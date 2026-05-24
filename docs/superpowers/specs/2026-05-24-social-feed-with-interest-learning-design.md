# Social Feed with Interest Learning (v2) — Design

**Status:** Draft for review
**Date:** 2026-05-24
**Author:** Kharlyn (with Claude as brainstorming partner)
**Builds on:** `docs/superpowers/specs/2026-05-24-ad-ranking-prototype-design.md` and the v0.1 implementation tagged `v0.1-assessment-submission`.

---

## 1. Context & Goals

The v1 prototype is an ads-only feed ranked by tier + proximity + anti-starvation. It meets the assessment's stated requirements but reads as a sorting demo — there's no signal that the *user* matters to the algorithm.

v2 evolves the surface into an **Instagram-style social feed** where organic posts and sponsored ads share one stream. The user reacts to organic posts (like / unlike). Reactions derive a per-category interest profile. The ranking algorithm gains a new term that boosts ads whose categories match the user's profile.

The product story becomes: **the app *learns* what you care about, and the ads it picks reflect that, *combined* with where you are and which advertisers paid more.** That's a real ad-tech product narrative, not a sorting exercise.

**Non-goals (still out of scope for the budget):**
- Real backend, real auth, real GPS
- Time-decay of interest (recent likes weighing more)
- ML-based interest models (collaborative filtering, embeddings)
- Negative signals (downvote, hide, "not interested")
- Per-post-author follow graph
- Comment threads, share, save
- Real-time push updates (streaming new posts)

---

## 2. Architecture Overview

The existing layered architecture is preserved. New components (NEW) layer onto existing ones; existing interfaces stay unchanged where possible.

```
┌─────────────────────────────────────────────────────────┐
│ Presentation                                            │
│  • MixedFeedView (NEW — interleaves posts + ads)        │
│  • PostCard (NEW), AdCard (extended: image + Sponsored) │
│  • PostBloc (NEW), ReactionCubit (NEW)                  │
│  • InterestCubit (NEW)                                  │
│  • FeedBloc (extended: listens to InterestCubit)        │
│  • LocationCubit, AnalyticsBloc (unchanged)             │
└────────────────────────┬────────────────────────────────┘
┌────────────────────────┴────────────────────────────────┐
│ Domain (pure Dart, no Flutter deps)                     │
│  • RankingEngine (extended: +W_interest term)           │
│  • InterestService (NEW, pure function)                 │
│  • Models: Post (NEW), Category (NEW), PostLike (NEW),  │
│           Ad (+imageUrl, +categories)                   │
└────────────────────────┬────────────────────────────────┘
┌────────────────────────┴────────────────────────────────┐
│ Data                                                    │
│  • PostRepository → MockPostRepository (NEW, 100 posts) │
│  • ReactionRepository → HiveReactionRepository (NEW)    │
│  • AdRepository, EventRepository, LocationRepository    │
│    (existing — only MockAdRepository content changes    │
│    to add imageUrl + categories per ad)                 │
└─────────────────────────────────────────────────────────┘
```

**Reactive data flow (the new loop):**

```
[ user taps heart on a coffee post ]
        │
        ▼
ReactionCubit.toggle(postId)
        │
        ▼
HiveReactionRepository.like(postId)   ← persisted to Hive
        │
        ▼
ReactionCubit emits new Set<likedIds>
        │
        ▼
InterestCubit recomputes Map<Category, double> profile
        │
        ▼
FeedBloc listens to InterestCubit, re-runs RankingEngine
with the new interest term
        │
        ▼
MixedFeedView rebuilds; ads in slots 5,10,15… reflect
the freshly-computed interest signal
```

**Why the interleaving lives in the view, not in a bloc:** the slot pattern (1 ad per 4 posts) is purely presentational — there is no state to manage. `MixedFeedView` is given `posts: List<Post>` and `rankedAds: List<Ad>` and produces a `ListView.builder` that maps each index to either a post or the next ranked ad. Putting this in a bloc would invent state that doesn't exist.

**Why `InterestCubit` is its own component, not folded into `ReactionCubit` or `FeedBloc`:** interest derivation is a pure function with two inputs (likes + post catalog) and one output (the profile). Isolating it makes it the easiest part to test, lets us swap the implementation (rule-based → ML model) without touching either upstream or downstream, and gives the README a clean "this would become a microservice in prod" story.

---

## 3. Data Models

### 3.1 `Category` enum (closed set, 8 values)

```dart
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

### 3.2 `Post` model

```dart
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
  final String authorName;        // e.g. "Maria Santos"
  final String authorHandle;      // e.g. "@maria.eats"
  final String caption;
  final String imageUrl;          // https://picsum.photos/seed/{id}/600/600
  final List<Category> categories;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
}
```

### 3.3 `PostLike` model + Hive adapter (typeId = 2)

Persisted via Hive in its own box `post_likes`. Adapter co-located in `lib/data/models/post_like_adapter.dart` (same split pattern as `AdEventAdapter`).

```dart
class PostLike extends Equatable {
  const PostLike({required this.postId, required this.likedAt});
  final String postId;
  final DateTime likedAt;
}
```

### 3.4 `Ad` model — extensions

Existing `Ad` gains two fields:

```dart
final String imageUrl;             // hand-picked Unsplash URL per ad
final List<Category> categories;   // 1-2 categories per ad
```

Existing 10 mock ads get curated categorization, for example:
- `jollibee-manila` → `[food]`
- `globe-manila` → `[tech]`
- `grab-manila` → `[food, travel]`
- `localcafe-manila` → `[coffee]`
- `ayala-cebu` → `[fashion, beauty]`
- `lechon-cebu` → `[food]`
- `bookshop-cebu` → `[books, coffee]`
- `durian-davao` → `[food]`
- `eagle-davao` → `[travel]`
- `strawberry-baguio` → `[food, travel]`

---

## 4. Interest Derivation (`InterestService`)

Pure function in `lib/domain/interest/interest_service.dart`:

```dart
Map<Category, double> computeProfile({
  required List<PostLike> likes,
  required List<Post> postsCatalog,
}) { ... }
```

**Algorithm:**
1. Build a quick `Map<String, Post>` index from `postsCatalog` by id.
2. For each `PostLike`, look up the post. For each `Category` in `post.categories`, increment a per-category counter by 1.
3. Sum all counters → `totalWeight`.
4. If `totalWeight == 0`, return `{}` (no signal).
5. Otherwise, return `{cat: count / totalWeight}` for each category that has a non-zero count. Categories with no likes are absent from the map; consumers treat absent as 0.

**Worked example:**

User liked posts:
- p1 (categories: [food]) → food + 1
- p2 (categories: [coffee, food]) → coffee + 1, food + 1
- p3 (categories: [coffee]) → coffee + 1
- p4 (categories: [food]) → food + 1
- p5 (categories: [food]) → food + 1

Counters: food = 4, coffee = 2. Total = 6.

Profile: `{food: 0.667, coffee: 0.333}`. Other categories absent (treated as 0).

**Edge cases:**
- Empty likes → empty map.
- A liked post that's no longer in the catalog (was removed/edited) → skipped silently; do not throw.
- Identical results given the same inputs (pure, deterministic).

---

## 5. Ranking Formula Changes

### 5.1 Updated formula

```
score(ad) = (W_tier   × tier_weight)
          + (W_prox   × proximity_score)
          + (W_int    × interest_match)        ← NEW
          − (W_decay  × recent_impression_count)
          + (W_starve × starvation_boost)
```

### 5.2 `interest_match` definition

Given the user's `profile: Map<Category, double>` and the ad's `categories: List<Category>`:

```
interest_match = min(1.0, sum over c in ad.categories of (profile[c] ?? 0.0))
```

- Single-category ad: caps out at the user's interest in that one category.
- Multi-category ad: stacks (food + coffee match accumulates) but is capped at 1.0 to prevent runaway boost on ads tagged with many categories.
- Empty profile (no likes yet) → `interest_match = 0` for every ad → ranking degrades to v1 behavior.

### 5.3 New weight

```dart
class RankingWeights {
  const RankingWeights({
    this.tier = 10.0,
    this.proximity = 8.0,
    this.interest = 8.0,             // NEW
    this.decay = 2.0,
    this.starvation = 5.0,
  });
  // ...
}
```

`W_interest = 8` parallels `W_prox`. Both are second-order signals after tier; both can swing the ordering meaningfully without overwhelming tier dominance.

### 5.4 Sanity checks against the new weight

| Scenario | Numbers | Outcome |
|---|---|---|
| User strongly likes food (food=0.8). Food-tagged Silver in same city vs same-city Gold (untagged) | Silver: 20+8+6.4 = 34.4. Gold: 30+8+0 = 38 | Gold still wins — tier > interest, as intended. |
| Same as above, but Gold is in Cebu (distant from user in Manila) | Silver: 34.4. Gold: 30+0+0 = 30 | Silver food ad wins — interest + proximity together beat distant tier. |
| User has interest profile `{food:0.3, coffee:0.3, travel:0.2}`. Ad tagged `[food, coffee]` | interest_match = min(1, 0.6) = 0.6 → +4.8 boost | Reasonable mid-strength signal. |
| First-time user, no likes | interest_match = 0 for all ads | Behavior identical to v1 ranking. |

### 5.5 `RankingEngine.rank` signature change

```dart
List<Ad> rank({
  required List<Ad> ads,
  required UserLocation userLocation,
  required List<AdEvent> events,
  required DateTime now,
  Map<Category, double> interestProfile = const {},   // NEW, defaults to empty
  int? limit,
});
```

The default makes the new parameter backward-compatible — existing test cases that don't pass it still compile and pass (with the new term contributing 0).

---

## 6. Repositories

### 6.1 `PostRepository` + `MockPostRepository`

```dart
abstract class PostRepository {
  Future<List<Post>> getAll();
}
```

`MockPostRepository.getAll()` generates 100 posts deterministically from a list of caption templates × authors × categories × locations × seeds. Code generation rather than 100 hand-written entries. Sample template:

```dart
const _captions = [
  'Sunday slow morning ☕',
  'Best lechon in town hands down',
  'Trail run before sunrise',
  // ... ~25 templates
];

const _authors = [
  ('Maria Santos', '@maria.eats'),
  ('Carlos Reyes', '@carl.runs'),
  // ... ~15 authors
];
```

Each generated post has a stable `id` like `post-{n}` so the Picsum seed `https://picsum.photos/seed/post-{n}/600/600` returns the same image every load. Location is sampled from the 4 PH cities (Manila/Cebu/Davao/Baguio) plus small jitter.

### 6.2 `ReactionRepository` + `HiveReactionRepository`

```dart
abstract class ReactionRepository {
  Future<void> like(String postId);
  Future<void> unlike(String postId);
  Future<List<PostLike>> getAllLikes();
  Stream<Set<String>> likedPostIds();   // reactive view for UI / cubit
}
```

Backed by a Hive box `post_likes` keyed by `postId` (so `like` is upsert, `unlike` is delete, both idempotent). The stream emits the current set after every change.

---

## 7. Blocs & Cubits

### 7.1 `PostBloc` (new)

`Bloc<PostEvent, PostState>`. Loads the catalog once on `PostRequested`. Emits `PostLoading`/`PostLoaded(List<Post>)`/`PostError(message)`. Catalog is immutable after first load (no pagination, no refresh of contents — refreshing the feed re-shuffles client-side order but doesn't refetch).

### 7.2 `ReactionCubit` (new)

`Cubit<Set<String>>`. Initial state seeded from `ReactionRepository.getAllLikes()` mapped to IDs. Subscribes to `ReactionRepository.likedPostIds()`. Exposes:

```dart
Future<void> toggle(String postId);   // like if absent, unlike if present
bool isLiked(String postId) => state.contains(postId);
```

### 7.3 `InterestCubit` (new)

`Cubit<Map<Category, double>>`. Built with two dependencies: a `ReactionCubit` and a `PostBloc`. Subscribes to `reactionCubit.stream` (Set of liked IDs) and `postBloc.stream` (which emits a `PostLoaded` once). On any emission from either, looks up the liked posts from the latest catalog and calls `InterestService.computeProfile`. If the catalog hasn't loaded yet (`PostLoaded` not seen), holds an empty profile. Initial state: `const {}`.

### 7.4 `FeedBloc` (extended)

Constructor gains an `InterestCubit` dependency. Subscribes to its stream. On every interest profile change, internally adds a `FeedRequested` event so the feed re-ranks. The existing `FeedRequested` handler now reads the current profile from the cubit and passes it to `RankingEngine.rank`.

### 7.5 `AnalyticsBloc` (extended)

Tracks impressions for both posts AND ads (parity). Adds `PostImpressionRecorded(postId)` event alongside the existing `ImpressionRecorded(adId)` and `ClickRecorded(adId)` (kept as-is — no rename, to avoid breaking v1 tests). Persists post impressions to `EventRepository` via a new `recordPostImpression(postId)` method. Reactions persist via `ReactionRepository`, not `EventRepository`.

### 7.6 `LocationCubit` (unchanged)

Same as v1.

---

## 8. UI Components

### 8.1 `MixedFeedView` (replaces `_FeedList`)

```dart
class MixedFeedView extends StatelessWidget {
  // pulls posts from PostBloc, rankedAds from FeedBloc, likedIds from ReactionCubit,
  // userLocation from LocationCubit.
  // Renders ListView.builder with the slot logic in itemBuilder.
}
```

**Slot pattern:** for every 5 visible items, slot 5 (1-indexed) is an ad. So flattened index 4 = ad #0, index 9 = ad #1, index 14 = ad #2, etc. If `rankedAds` runs out (only 10 ads vs many post slots), ad slots show a `SizedBox.shrink()` to avoid a gap.

**Cadence calculation per `itemBuilder` index** (0-indexed):
```dart
final isAdSlot = (index + 1) % 5 == 0;
final adIndex = (index + 1) ~/ 5 - 1;            // 0, 1, 2, …
final postIndex = index - (index ~/ 5);          // skips ad slots
```

Pull-to-refresh triggers `FeedRequested` to re-rank ads. Post order stays stable (reverse-chronological by timestamp from the mock data); no shuffling — the interest-driven ad changes between slots are the visible signal.

### 8.2 `PostCard` (new)

Layout (top to bottom):
1. **Header row:** circular avatar (deterministic colored initial), author name + handle + "2h" relative time on the left, category chips on the right.
2. **Image:** 600×600 (or fit to width), `cached_network_image` with a `surfaceVariant` placeholder.
3. **Action row:** heart icon (filled red if liked, outlined gray if not). Heart animates on tap (scale 1.0 → 1.3 → 1.0 over 200ms; color crossfade).
4. **Like count:** deterministic `post.id.hashCode.abs() % 500 + 10` (no real persistence — purely flavor). Adds 1 visually if the current user has liked it.
5. **Caption:** prefixed with author handle in bold (`maria.eats Sunday slow morning ☕`).

### 8.3 `AdCard` (extended)

Additions:
- Image at the top (same 600×600 treatment as `PostCard`).
- "Sponsored" chip in the top-right of the header row (subdued surface color, small).
- Existing tier badge, advertiser name, distance, title, description all stay.

### 8.4 Avatar generation helper

```dart
// lib/core/avatar.dart
Color avatarColor(String name);     // hash-derived from name
String avatarInitial(String name);  // first letter, uppercase
```

Used by `PostCard` to render a `CircleAvatar` without a profile-image fetch.

### 8.5 New dependency

`cached_network_image: ^3.4.1` in `pubspec.yaml`.

---

## 9. Folder Structure (delta from v1)

```
lib/
  core/
    theme.dart                    (existing)
    constants.dart                (existing — add kPostsPerAd = 4)
    distance.dart                 (existing)
    avatar.dart                   (NEW)
  data/
    models/
      ad.dart                     (extended — add imageUrl, categories)
      ad_event.dart               (existing, unchanged)
      ad_event_adapter.dart       (existing, unchanged)
      user_location.dart          (existing, unchanged)
      category.dart               (NEW)
      post.dart                   (NEW)
      post_like.dart              (NEW)
      post_like_adapter.dart      (NEW)
    repositories/
      ad_repository.dart          (existing)
      mock_ad_repository.dart     (extended — add image + categories per ad)
      event_repository.dart       (extended — add recordPostImpression)
      hive_event_repository.dart  (extended)
      location_repository.dart    (existing)
      post_repository.dart        (NEW)
      mock_post_repository.dart   (NEW)
      reaction_repository.dart    (NEW)
      hive_reaction_repository.dart (NEW)
  domain/
    ranking/
      ranking_engine.dart         (extended — interest term)
      ranking_weights.dart        (extended — add interest weight)
    interest/
      interest_service.dart       (NEW, pure)
  presentation/
    feed/
      bloc/
        feed_bloc.dart            (extended)
        feed_event.dart           (existing)
        feed_state.dart           (existing)
      view/
        feed_page.dart            (extended — uses MixedFeedView)
        mixed_feed_view.dart      (NEW)
        ad_card.dart              (extended — image, sponsored chip)
        post_card.dart            (NEW)
    location/
      cubit/location_cubit.dart   (existing)
      view/location_picker.dart   (existing)
    analytics/
      bloc/
        analytics_bloc.dart       (extended)
        analytics_event.dart      (extended)
    posts/
      bloc/
        post_bloc.dart            (NEW)
        post_event.dart           (NEW)
        post_state.dart           (NEW)
    reactions/
      cubit/reaction_cubit.dart   (NEW)
    interest/
      cubit/interest_cubit.dart   (NEW)
  main.dart                       (extended — register new adapter, open new box, provide new blocs)

test/
  domain/
    ranking_engine_test.dart      (extended — interest test cases, also pass interestProfile to old cases)
    distance_test.dart            (existing)
    interest_service_test.dart    (NEW)
  presentation/
    feed/feed_bloc_test.dart      (extended — interest profile change re-ranks)
    analytics/analytics_bloc_test.dart (extended for post impressions)
    reactions/reaction_cubit_test.dart (NEW)
    interest/interest_cubit_test.dart (NEW)
    posts/post_bloc_test.dart     (NEW)
```

---

## 10. Testing Strategy

Tier 1 + Tier 2 remain must-haves. Adding to the 17 existing tests:

| Tier | New tests | Notes |
|---|---|---|
| 1 (unit) | `InterestService` × 5: empty likes → empty; single category; multi-cat post counted in each; normalization sums to 1; missing-post is skipped | Pure function, easy to test |
| 1 (unit) | `RankingEngine` × 3 added cases: interest_match boosts a matching ad; profile-less call equals v1 behavior; interest_match caps at 1.0 with overlap | Existing cases all updated to pass `interestProfile: const {}` |
| 2 (bloc) | `ReactionCubit` × 3: toggle adds, toggle again removes, persists via repo mock | |
| 2 (bloc) | `InterestCubit` × 2: emits new profile when likes change; emits empty on init | |
| 2 (bloc) | `FeedBloc` × 1: re-ranks when interest profile changes | Adds to the existing 3 |
| 2 (bloc) | `PostBloc` × 2: emits loaded on success; emits error on repo throw | Mirror of FeedBloc test shape |

Tier 3 (widget) and Tier 4 (integration) still skipped — same rationale as v1.

Total new tests: ~16. Total suite: ~33. Should still run in well under 5 seconds.

---

## 11. Mock Data — 100 Posts

Generated from a template:

```dart
class _PostTemplate {
  final String captionTemplate;
  final List<Category> categories;
}

const _templates = [
  _PostTemplate('Sunday slow morning ☕', [Category.coffee]),
  _PostTemplate('Best lechon in town hands down', [Category.food]),
  _PostTemplate('Trail run before sunrise 🌅', [Category.fitness, Category.travel]),
  _PostTemplate('New zine drop at Folio this weekend', [Category.books]),
  _PostTemplate('Skincare haul — finally found a serum that works', [Category.beauty]),
  // … ~25 templates spanning all 8 categories
];

const _authors = [
  ('Maria Santos', '@maria.eats'),
  ('Carlos Reyes', '@carl.runs'),
  ('Aileen Cruz', '@aileen.style'),
  // … ~15 author tuples
];

const _baseLocations = [
  (14.5995, 120.9842),  // Manila
  (10.3157, 123.8854),  // Cebu
  (7.1907, 125.4553),   // Davao
  (16.4023, 120.5960),  // Baguio
];
```

Generation: 100 iterations indexed `n = 0..99`. Per iteration:
- `template = _templates[n % _templates.length]`
- `author = _authors[n % _authors.length]`
- `base = _baseLocations[n % 4]`; lat/lng = base ± (n % 10) × 0.001 (small jitter inside the city)
- `timestamp = DateTime.now().subtract(Duration(hours: n))`
- `id = 'post-$n'`
- `imageUrl = 'https://picsum.photos/seed/post-$n/600/600'`

Deterministic, ~50 lines of code, no hand-typed bulk data.

---

## 12. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Scope: 5 new blocs/cubits, 2 new repos, 2 new widgets, 1 domain service | Tasks are independently testable; if time tight, skip `PostBloc.error` path and `AnalyticsBloc` post-impression extension and document as known limitations. |
| `cached_network_image` web behavior on first load | Surface-variant placeholder shows immediately; image fades in. Scroll stays smooth even before images arrive. |
| Picsum returns occasional non-matching content (a "coffee" post might show a mountain) | Category *chip* on the card is the source of truth for what the post is about. Reviewer sees the chip; image is decoration. |
| 100 mock posts could make first load slow on web | The post catalog is in-memory only (no IO). Initial render is bounded by the visible viewport only. |
| Tag collision with the `v0.1-assessment-submission` git tag | Tag v2 as `v0.2-assessment-submission` on completion. |

---

## 13. README Additions

A new section between "Ranking algorithm" and "How this would scale":

```
### Interest learning (the social loop)

The feed mixes organic posts and sponsored ads (1 ad per 4 posts).
Each post and ad is tagged with one or more categories (food, coffee,
fashion, travel, fitness, tech, beauty, books). Reactions on organic
posts build a per-category interest profile, which the ranking algorithm
consumes as a new term:

  + W_interest × interest_match

where interest_match is the user's interest in the ad's categories
(capped at 1.0). With no reactions, the term is zero and the algorithm
behaves exactly as v1. After a few likes, ads in matching categories
get a meaningful boost — enough for a fresh Silver coffee ad to leap
ahead of a heavily-shown Gold tech ad if the user has been liking
coffee posts.

The interest derivation lives in a pure `InterestService` so it could
be swapped with an ML model (collaborative filtering, embeddings)
without touching the bloc or the ranker.
```

A new row in the tradeoffs table:

```
| Interest decay over time | Out of scope | Time-weighted reactions: recent likes count more (exponential decay) |
```

The "Where AI was used" section gains a sentence:

```
The v2 social-feed evolution was also brainstormed with Claude through
the same spec → plan → subagent-driven execution loop documented in
`docs/superpowers/`.
```

---

## 14. Success Criteria

The v2 prototype is considered complete when:

1. App runs on mobile (and web) via `flutter run`.
2. Feed shows a mix of posts and ads in the 4:1 pattern.
3. Tapping a heart on a post toggles the like state visually AND persists across app restart.
4. After liking 3+ posts in the same category, the next ad in that category visibly outranks others.
5. Switching mock user location still re-ranks ads (existing v1 behavior preserved).
6. `InterestService` unit tests pass (Tier 1 must-have).
7. `ReactionCubit` and `InterestCubit` bloc tests pass (Tier 2 must-have).
8. All existing v1 tests still pass (no regression).
9. README has the "Interest learning" section.
10. Total elapsed v2 implementation time stays at or under 3 hours on top of the v1 budget.
