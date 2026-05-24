# Ad Ranking & Delivery Prototype

A lightweight Flutter prototype that ranks advertiser ads by tier + proximity + fairness, displays them in a scrollable feed, and logs impressions/clicks locally with Hive.


---

## Quick start

**Prerequisites:** Flutter SDK, Dart 3+ (tested on Flutter 3.41.6 / Dart 3.11.4).

```bash
flutter pub get
flutter run                  # mobile (emulator/device)
flutter run -d chrome        # web
flutter test                 # unit + bloc tests
```

Use the dropdown in the app bar to switch the mock user location (Manila / Cebu / Davao / Baguio). The feed re-ranks immediately. Tap the refresh FAB to re-rank manually after impressions accumulate.

Tap the heart on any post to like it. After 3–4 likes in the same category (food, coffee, etc.), the next sponsored ad slot will visibly favor that category — that's the interest signal feeding back into the ranking algorithm.

The bottom navigation has two tabs: Home (the social feed) and Liked. The Liked tab shows your current interest profile (per-category percentages derived from likes) and the posts you've liked — useful for seeing why the next ad slot might favor a certain category.

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

## Interest learning (the social loop)

The feed mixes organic posts and sponsored ads in a 4:1 cadence (1 ad after every 4 posts). Each post and ad is tagged with one or more categories (food, coffee, fashion, travel, fitness, tech, beauty, books). Reactions on organic posts build a per-category interest profile, which the ranking algorithm consumes as a new term:

```
+ W_interest × interest_match
```

where `interest_match = min(1.0, sum over ad.categories of profile[cat])`. With no reactions yet, the term is zero everywhere and the algorithm behaves exactly as v1. After a few likes, ads in matching categories get a meaningful boost — enough for a fresh Silver coffee ad to leap ahead of a heavily-shown Gold tech ad if the user has been liking coffee posts.

The interest derivation lives in a pure `InterestService` so it could be swapped with an ML model (collaborative filtering, embeddings) without touching the bloc or the ranker.

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
| Impression dedup + persisted in-memory analytics counters | Out of scope | Per-session seen-set + hydrate AnalyticsBloc from Hive on startup |
| Interest decay over time | Out of scope | Time-weighted reactions: recent likes count more (exponential decay) |
| Negative signals (downvote, "not interested") | Out of scope | Per-user blocklist + negative weighting in the ranker |
| Cold-start, budget pacing, frequency capping | Out of scope | Discussed above |

The test pyramid stops at Tier 2 (`bloc_test`) on purpose: the algorithm is where the bugs would live, and bloc tests cover the reactive plumbing. Widget tests on a 5-widget app would be ceremony without much bug-finding value.

---

## Where AI was used

Claude (`Opus 4.7` via Claude Code) was used as a brainstorming and boilerplate partner in this assessment:

- **Brainstorming session** — produced the design spec at `docs/superpowers/specs/2026-05-24-ad-ranking-prototype-design.md` and the task-by-task plan at `docs/superpowers/plans/2026-05-24-ad-ranking-prototype.md`. The architecture choices, ranking formula, weight values, and tradeoff list were proposed by Claude and ratified (and sometimes overridden) by me. The full conversation drove the design.
- **Boilerplate generation** — BLoC scaffolding (events/states), Hive type adapter, mock data list, Material 3 theme.
- **README polish** — first draft of this README, then edited by hand.

**Not from AI:** the choice to use Hive over Drift (driven by my own concern about Drift's web story), the decision to bump bloc tests to a must-have tier, the call to use Material 3 explicitly. Final weight values, formula trade-offs, and the "deterministic over probabilistic" choice were all deliberate decisions reviewed before committing.

The v2 evolution from an ads-only ranker into a mixed social feed with interest learning was also brainstormed with Claude through the same spec → plan → subagent-driven execution loop. See `docs/superpowers/specs/2026-05-24-social-feed-with-interest-learning-design.md` and the corresponding plan for the design conversation.
