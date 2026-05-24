# Ad Ranking & Delivery Prototype — Design

**Status:** Draft for review
**Date:** 2026-05-24
**Author:** Kharlyn (with Claude as brainstorming partner)
**Source:** `Full Stack Developer Assessment.md`

---

## 1. Context & Goals

The assessment asks for a lightweight prototype that demonstrates mobile/frontend engineering, API integration, ranking logic, and scalable system design. The reviewer values **clear thinking, maintainable code, and pragmatic engineering decisions over completeness**, with a hard time budget of 3–4 hours.

The intellectual centerpiece is the ranking algorithm: it must balance three competing goals — advertiser tier priority (Gold > Silver > Bronze), proximity relevance, and fairness so lower tiers aren't starved.

**Stack:** Flutter (mobile-first, with web as a stretch since Hive supports it natively).

**Non-goals (explicitly out of scope for the time budget):**
- Real backend / cloud deployment
- Authentication or user identity
- Real GPS / location permissions
- A/B testing infrastructure for ranking weights
- Polished UI / branding
- Production-grade observability

---

## 2. Architecture Overview

Layered architecture with three layers and strict directionality (presentation → domain → data):

```
┌─────────────────────────────────────────┐
│ Presentation (BLoCs + Widgets)          │
│  • FeedBloc, AnalyticsBloc, LocationCubit│
│  • FeedPage, AdCard, LocationPicker     │
└──────────────────┬──────────────────────┘
                   │ depends on
┌──────────────────┴──────────────────────┐
│ Domain (pure Dart, no Flutter deps)     │
│  • RankingEngine  (pure function)       │
│  • Models: Ad, AdTier, AdEvent, Location│
└──────────────────┬──────────────────────┘
                   │ depends on
┌──────────────────┴──────────────────────┐
│ Data                                     │
│  • AdRepository      → MockAdRepository │
│  • EventRepository   → HiveEventRepository│
│  • LocationRepository → in-memory list  │
└─────────────────────────────────────────┘
```

**Key design choices:**

- **`RankingEngine` is a pure function.** Takes `(ads, userLocation, eventHistory)` → returns a ranked `List<Ad>`. No Flutter, no IO, no side effects. This is the easiest part to unit-test and the part a reviewer will most want to read.
- **Repositories are abstract classes with concrete implementations.** Makes mocking trivial in BLoC tests and gives the README a clean "swap in a real backend" story.
- **One BLoC per concern.** `FeedBloc` owns ranking and feed state; `AnalyticsBloc` owns event recording; `LocationCubit` owns the current mock location. No god-BLoC.

**Why these choices over alternatives:**

| Choice | Picked | Alternative considered | Rationale |
|---|---|---|---|
| Backend | In-app service layer | Firebase Functions; local server | Assessment allows mocked data; frees time for the README and tests. Service interfaces let us swap in a real backend later. |
| UI shape | Scrollable feed of ranked ads | Single-card "next" UI; map UI | Shows ranking results clearly side-by-side; demo-able. Map UI eats too much time on plumbing. |
| State mgmt | flutter_bloc | Riverpod, Provider, setState | Predictable, common in enterprise Flutter, plays well with the testing strategy. |
| Storage | Hive | Drift/sqflite, in-memory only | Native web support (avoids `sqflite_common_ffi_web` indirection), no SQL needed for an append-only event log. |
| Location | Mock locations with picker | Real GPS via geolocator | Demos how proximity changes ranking in real time; no permission plumbing or simulator GPS setup. |
| UI / theming | Material 3 (`useMaterial3: true`) with a `ColorScheme.fromSeed` palette | Custom design system; default Material 2 | Material 3 is the modern Flutter default and gives a polished baseline with zero custom design work — keeps time focused on the algorithm and tests. Tier color (Gold/Silver/Bronze) overlays the seeded palette. |

---

## 3. Ranking Algorithm

### 3.1 Formula

For each candidate ad:

```
score(ad) = (W_tier × tier_weight)
          + (W_prox × proximity_score)
          − (W_decay × recent_impression_count)
          + (W_starve × starvation_boost)
```

Sort descending, take the top N for the feed.

### 3.2 Terms

| Term | Definition |
|---|---|
| `tier_weight` | Gold = 3, Silver = 2, Bronze = 1 |
| `proximity_score` | `max(0, 1 − distance_km / MAX_KM)` where `MAX_KM = 50`. Linear decay; 0 km ⇒ 1.0, ≥50 km ⇒ 0. Haversine for `distance_km`. |
| `recent_impression_count` | Number of impressions for this ad in the last 10 min |
| `starvation_boost` | `1.0` if ad has not been shown in the last 5 min, else `0` |

### 3.3 Initial weights

| Weight | Value | Effect |
|---|---|---|
| `W_tier` | 10 | Tier dominates by default — premium gets premium placement |
| `W_prox` | 8 | Proximity is a strong secondary factor, never beats tier on its own |
| `W_decay` | 2 | Three recent impressions ⇒ −6 to score, enough for one tier-level overtake |
| `W_starve` | 5 | A 5-point lift surfaces ignored lower-tier ads without dominating |

All four constants live in a single `RankingWeights` value class so they can be tuned in one place. The README discusses how to tune via A/B testing and CTR feedback in a real system.

### 3.4 Why deterministic top-N, not probabilistic sampling

Considered weighted random sampling (each ad has a probability ∝ score, sample without replacement). Elegant and inherently anti-starvation, but harder to explain *why* a given ordering happened — reviewers tend to want to read the algorithm and predict the output. Deterministic top-N with a decay term gives the same anti-starvation behavior over time while remaining inspectable.

### 3.5 Why impressions don't trigger immediate re-rank

If every impression event triggered a re-rank of the visible feed, scrolling would shuffle items under the user's finger. Re-ranking is triggered by:
1. Location change (immediate, via `LocationCubit` stream)
2. Pull-to-refresh (explicit user intent)
3. (Optional) a debounced periodic trigger so reviewers can watch decay take effect

This is a real production tradeoff: list stability vs. ranking freshness. README will name it explicitly.

### 3.6 Edge cases the engine must handle

- Empty ad list → empty result
- All ads outside `MAX_KM` → still rank deterministically by tier + decay + starvation (proximity term is 0 across the board)
- First-ever load (no event history) → `starvation_boost` applies to every ad → effectively pure tier+proximity ordering
- Identical scores → break ties by ad ID for determinism (important for tests)

---

## 4. Data Flow

The four flows that matter:

```
1. App opens
   main() → Hive.init → repositories wired into BlocProviders
   LocationCubit emits initial mock location (e.g. Manila)
   FeedBloc.add(FeedRequested)
     → AdRepository.getAll()        (~10 mocked ads)
     → EventRepository.getRecent()  (impression history from Hive)
     → RankingEngine.rank(ads, location, events)
     → emit(FeedLoaded(rankedAds))

2. Ad becomes visible (scroll triggers VisibilityDetector)
   AnalyticsBloc.add(ImpressionRecorded(adId))
     → EventRepository.recordImpression(adId)
   (No automatic re-rank — see §3.5)

3. Ad tapped
   AnalyticsBloc.add(ClickRecorded(adId))
     → EventRepository.recordClick(adId)
     → SnackBar: "Clicked: <ad title>"

4. Location changed via picker
   LocationCubit.setLocation(newLocation)
   FeedBloc listens to LocationCubit stream → re-ranks immediately
```

---

## 5. Folder Structure

```
lib/
  core/
    theme.dart            (Material 3 + seeded ColorScheme; tier color helpers)
    constants.dart
  data/
    models/
      ad.dart                    (Ad, AdTier enum)
      ad_event.dart              (with Hive type adapter)
      user_location.dart
    repositories/
      ad_repository.dart         (abstract)
      mock_ad_repository.dart    (impl, ~10 hardcoded ads)
      event_repository.dart      (abstract)
      hive_event_repository.dart
      location_repository.dart   (in-memory list of mock locations)
  domain/
    ranking/
      ranking_engine.dart        (PURE — no Flutter, no IO)
      ranking_weights.dart
  presentation/
    feed/
      bloc/
        feed_bloc.dart
        feed_event.dart
        feed_state.dart
      view/
        feed_page.dart
        ad_card.dart
    location/
      cubit/location_cubit.dart
      view/location_picker.dart
    analytics/
      bloc/analytics_bloc.dart
  main.dart

test/
  domain/
    ranking_engine_test.dart     (Tier 1)
  presentation/
    feed/feed_bloc_test.dart     (Tier 2)
```

Two things worth flagging:
- **`domain/` has zero Flutter imports.** Pure Dart, pure functions. This is the kind of separation a reviewer will notice.
- **Repositories are abstract.** Easy to mock; gives a clean swap-in story for a real backend.

---

## 6. Testing Strategy

Tiered by ROI on a 3–4 hour budget:

| Tier | Scope | Estimated time | Commitment |
|---|---|---|---|
| 1 | Unit tests on `RankingEngine` | 20–30 min | **Must-have** |
| 2 | `bloc_test` on `FeedBloc` (and `AnalyticsBloc`) | 20–30 min | **Must-have** |
| 3 | Widget test on `FeedPage` (renders, tap fires click) | 30–45 min | Nice-to-have |
| 4 | Integration test (happy-path flow) | 45–60 min | Bonus only |

Tier 2 cases worth covering:
- `FeedBloc` emits `FeedLoading` → `FeedLoaded(rankedAds)` on `FeedRequested`
- `FeedBloc` re-emits with re-ranked order when location changes
- `AnalyticsBloc` calls `EventRepository.recordImpression` on `ImpressionRecorded`
- `AnalyticsBloc` calls `EventRepository.recordClick` on `ClickRecorded`

### Tier 1 cases (the must-have unit tests)

1. Gold beats Silver beats Bronze when all else equal (same location, no events)
2. Closer ad of the same tier outranks farther ad
3. Decayed nearby Silver beats a distant Gold with 3 recent impressions
   (Gold at 50 km, 3 impressions: 30 − 6 + 0 = 24; Silver at 0 km, fresh: 20 + 8 = 28)
4. Bronze with starvation boost surfaces above heavily-shown Gold at same distance
   (requires Gold to have ≥ 8 recent impressions: 30 − 16 = 14 < 10 + 5 = 15)
5. Empty ad list → empty result
6. All ads outside `MAX_KM` → proximity term is 0 across the board; still deterministic
   by tier + decay + starvation
7. Identical scores break ties by ad ID

The README will explicitly state: *"With more time I would add widget and integration tests; the test pyramid here prioritizes the algorithm (Tier 1) and the reactive state plumbing (Tier 2) because that's where the bugs would live."*

---

## 7. README Outline (Deliverable)

```
# Ad Ranking & Delivery Prototype

## Quick start
- prereqs, flutter pub get, flutter run, where to switch mock location

## Architecture decisions
- Why layered (presentation / domain / data) for a small app
- Why BLoC
- Why Hive over Drift/SQLite
- Why Material 3 (modern Flutter default; polished baseline for zero cost)
- Why "no real backend" (assessment scope; interfaces let us swap one in)

## Ranking algorithm
- The formula, in plain English + the math
- Why each weight has the value it does
- Tradeoff: deterministic top-N vs probabilistic sampling
- Why impressions don't trigger immediate re-rank (UX vs freshness)
- How weights would be tuned in production (A/B testing, CTR feedback)

## How this would scale
- Retrieval layer (Redis cache of candidate ads by region/tier)
- Ranking layer (this engine, but distributed; per-request scoring)
- Event pipeline (Kafka / Pub/Sub for impressions/clicks → OLAP for analytics)
- Why the current `EventRepository` interface maps cleanly to a streaming producer
- Cold-start, budget pacing, frequency capping (named as out-of-scope but understood)

## Tradeoffs made for the 3–4 hour budget
- No real backend
- Mock locations instead of GPS
- No auth / user identity (events are anonymous)
- No A/B testing infra for the weights
- Tests stop at Tier 2 (or wherever we land)

## Where AI was used
- Brainstorming architecture and ranking approach
- Boilerplate generation (Hive adapters, BLoC scaffolding)
- README polish
- What was NOT AI: ranking formula reasoning, tradeoff decisions, weight choices
```

The "Where AI was used" section will be deliberately specific. The assessment explicitly asks for it; reviewers respect honesty over either hiding it or hand-waving it.

---

## 8. Risks & Open Questions

| Risk | Mitigation |
|---|---|
| Time budget slip — wiring Hive type adapters can be fiddly | Use `hive_flutter` with code generation; keep the event model flat (one `AdEvent` class with a type field, not separate Impression/Click classes) |
| Reviewer runs on web and hits Hive web init quirks | Document `Hive.initFlutter()` flow; test on web before submission |
| Re-rank not visible in demo (because impressions don't trigger it) | Add a "Re-rank now" button as a debug affordance, or pull-to-refresh |
| Ranking weights look arbitrary | README walks through *why* each weight has its value and how prod would tune them |

---

## 9. Success Criteria

The prototype is considered complete when:

1. App runs on mobile (and ideally web) via `flutter run`
2. Feed displays ranked ads with visible tier/distance indicators
3. Switching mock location re-ranks the feed visibly
4. Impressions and clicks are persisted across app restarts (Hive)
5. `RankingEngine` unit tests (Tier 1) pass
6. README covers all 5 sections in the outline above
7. Total elapsed implementation time stays at or under 4 hours
