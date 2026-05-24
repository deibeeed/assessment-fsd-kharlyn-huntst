# Bottom Nav with Liked Tab (v3) — Design

**Status:** Draft for review
**Date:** 2026-05-24
**Author:** Kharlyn (with Claude as brainstorming partner)
**Builds on:** v0.2 (tagged `v0.2-assessment-submission`).

---

## 1. Context & Goals

The v2 social feed makes interest-driven ad ranking work, but the *evidence* is hidden: a reviewer scrolling the feed can see ads change, but can't easily see *which posts they liked* or *what categories that maps to*. This makes the algorithm story harder to evaluate at a glance.

v3 adds a Material 3 `NavigationBar` with two tabs:

- **Home** — the existing `FeedPage` (the social feed)
- **Liked** — a new page showing (a) the derived per-category interest profile as chips, (b) the list of liked posts

This makes the feedback loop explicit: a reviewer can like a few posts, switch to Liked to see how their profile shifted, switch back to Home to see ads re-rank accordingly.

A secondary UX improvement: when the feed re-ranks (refresh FAB, pull-to-refresh, location change, or interest profile change), the feed scrolls back to the top automatically — so the reviewer always sees the newly top-ranked ad without manually scrolling up.

**Non-goals:**
- Persistent navigation history beyond the two tabs (no nested routes inside Liked)
- Per-tab AppBars with different actions beyond what already exists
- New domain logic, new repositories, or new tests
- Sorting/searching within the Liked tab

---

## 2. Architecture Overview

Two new presentation-layer widgets + one stateful refactor + a one-line `main.dart` change. No new blocs, no new repositories, no new models.

```
┌─────────────────────────────────────────────────────────┐
│ Presentation                                            │
│  • RootShell (NEW)                                      │
│      Scaffold with NavigationBar + IndexedStack         │
│      children: [FeedPage(), LikedPage()]                │
│  • LikedPage (NEW)                                      │
│      Watches PostBloc, ReactionCubit, InterestCubit     │
│      Renders interest chips + filtered PostCards        │
│  • _InterestChipStrip (NEW, private to LikedPage)       │
│      Horizontal Wrap of category chips with %           │
│  • MixedFeedView (MODIFIED)                             │
│      StatelessWidget → StatefulWidget; owns             │
│      ScrollController; scrolls to top on re-rank        │
│  • FeedPage, PostCard, AdCard, LocationPicker — unchanged│
└─────────────────────────────────────────────────────────┘
```

`main.dart`'s only change: `home: const FeedPage()` → `home: const RootShell()`. The `MultiBlocProvider` wrapping stays exactly as-is — both tabs share the same blocs, which is what makes the interest signal flow cleanly across tabs.

---

## 3. Component Details

### 3.1 `RootShell` — `lib/presentation/shell/root_shell.dart`

```dart
class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [FeedPage(), LikedPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Liked',
          ),
        ],
      ),
    );
  }
}
```

**Why `IndexedStack` instead of conditional widget or `PageView`:**
- Preserves `FeedPage`'s scroll position across tab switches (the reviewer scrolls 20 posts, taps Liked, comes back — must not re-scroll).
- Preserves any in-flight animations and widget state (e.g., a `SnackBar` showing).
- Both tabs are built once and kept in the tree. Memory overhead is negligible for two pages.
- Simpler than `Navigator.push` + named routes for this 2-tab case.

Each page (`FeedPage`, `LikedPage`) keeps its own `Scaffold` + AppBar. `RootShell`'s own Scaffold provides only the `NavigationBar` — the body is just `IndexedStack`. This double-Scaffold pattern is standard Material practice and is exactly how the Flutter docs recommend bottom-nav apps.

### 3.2 `LikedPage` — `lib/presentation/liked/view/liked_page.dart`

```dart
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
        PostInitial() || PostLoading() =>
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
              Icon(Icons.favorite_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline),
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
      itemCount: liked.length + 1,  // +1 for the header chip strip
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
```

**Why filter on the LikedPage side instead of adding a `getLiked()` method to PostRepository:** the post catalog is in-memory and stable. Filtering 100 posts by a Set membership on every build is trivial. Adding a repository method would require new tests and a new bloc state and add zero performance value.

**Empty state:** centered icon + message tells the reviewer how to populate this tab. This is the first thing they'll see, so the instruction matters.

### 3.3 `_InterestChipStrip` — same file as LikedPage

```dart
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
```

Sorted by percentage descending. Renders nothing when profile is empty (the Wrap would still render but invisible). The "Your interest profile" label sits above the chips so the reviewer knows what they're looking at.

### 3.4 `MixedFeedView` — refactor for auto-scroll-to-top on re-rank

Current `MixedFeedView` is a `StatelessWidget`. Convert it to `StatefulWidget` to own a `ScrollController`.

Add a `BlocListener<FeedBloc, FeedState>` wrapping the `RefreshIndicator`. The listener has `listenWhen: (prev, curr) => prev is FeedLoaded && curr is FeedLoaded` — this fires only on RE-RANKS (Loaded → Loaded), not on initial load (Initial/Loading → Loaded) where the user is already at the top.

On fire: `_scrollController.animateTo(0, duration: 300ms, curve: Curves.easeOut)`. Guarded with `_scrollController.hasClients` to avoid edge cases during widget mount/unmount.

```dart
class MixedFeedView extends StatefulWidget {
  const MixedFeedView({
    super.key,
    required this.posts,
    required this.rankedAds,
    required this.userLocation,
  });

  final List<Post> posts;
  final List<Ad> rankedAds;
  final UserLocation userLocation;

  @override
  State<MixedFeedView> createState() => _MixedFeedViewState();
}

class _MixedFeedViewState extends State<MixedFeedView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Object> _buildItems() {
    final items = <Object>[];
    var adIndex = 0;
    for (var i = 0; i < widget.posts.length; i++) {
      items.add(widget.posts[i]);
      if ((i + 1) % kPostsPerAd == 0 && adIndex < widget.rankedAds.length) {
        items.add(widget.rankedAds[adIndex]);
        adIndex++;
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final likedIds = context.watch<ReactionCubit>().state;
    final items = _buildItems();

    return BlocListener<FeedBloc, FeedState>(
      listenWhen: (prev, curr) => prev is FeedLoaded && curr is FeedLoaded,
      listener: (context, _) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
      child: RefreshIndicator(
        onRefresh: () async =>
            context.read<FeedBloc>().add(const FeedRequested()),
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            // ... same item builder as before, swap `posts`/`rankedAds`/`userLocation` for `widget.posts`/etc.
          },
        ),
      ),
    );
  }
}
```

The `itemBuilder` body is unchanged in logic — only the references to `posts`, `rankedAds`, and `userLocation` become `widget.posts` / `widget.rankedAds` / `widget.userLocation`.

### 3.5 `main.dart` — one-line change

Find:
```dart
home: const FeedPage(),
```

Replace with:
```dart
home: const RootShell(),
```

Add an import for `package:ad_ranking_prototype/presentation/shell/root_shell.dart`. Remove the now-unused `feed_page.dart` import from `main.dart` (analyzer will flag it). `FeedPage` is still imported by `RootShell` directly, so the FeedPage class itself stays reachable.

---

## 4. Folder Structure (delta from v2)

```
lib/
  presentation/
    shell/
      root_shell.dart                # NEW
    liked/
      view/
        liked_page.dart              # NEW (also defines _LikedBody and _InterestChipStrip)
    feed/
      view/
        mixed_feed_view.dart         # MODIFY (StatelessWidget → StatefulWidget, scroll controller, BlocListener)
  main.dart                          # MODIFY (1 line: home: → RootShell)
```

No new test files. Existing 34 tests stay valid.

---

## 5. Testing Strategy

No new tests. Justification:
- `RootShell` is purely structural (Scaffold + NavigationBar + IndexedStack). Widget tests would verify "tapping the Liked icon changes the selected index" — which is the Flutter framework doing its job, not our code.
- `LikedPage` filters posts by a Set and renders existing widgets. The filtering is a one-liner; the rendering uses already-tested `PostCard`.
- `_InterestChipStrip` is pure rendering of an already-tested `InterestCubit` state.
- The scroll-to-top behavior in `MixedFeedView` is a side-effect of a known event sequence; a widget test would require a full pump-and-settle harness for marginal value.

Manual smoke-test in Task 24 / final verification covers all the new behavior.

Existing 34 tests must continue to pass — verified at the end.

---

## 6. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Scroll-to-top fires during a re-rank caused by initial load and feels jarring | `listenWhen: prev is FeedLoaded && curr is FeedLoaded` filter — won't fire when previous state was `FeedInitial` or `FeedLoading` |
| Switching tabs forces both pages to rebuild every time | `IndexedStack` keeps both subtrees alive; no rebuild on tab switch |
| `LikedPage` is huge when the user has liked many posts | List is bounded by post catalog size (100). Reasonable for a prototype. README tradeoffs already mention pagination is out of scope. |
| Profile chip strip changes order on every like, causing visual jitter | Sort is deterministic (descending by value, stable by enum order on ties). Re-renders are smooth; chips appearing/disappearing as percentages change is the intended demo behavior. |
| `_InterestChipStrip` is private to the file but mentioned in `_LikedBody` — must be declared in the same file | Spec keeps both as private classes inside `liked_page.dart`. File is small enough that one-file containment is correct. |

---

## 7. README Update

A small addition to the Quick start section, after the existing "Tap the heart on any post" paragraph:

```
The bottom navigation has two tabs: Home (the social feed) and Liked. The Liked tab shows your current interest profile (per-category percentages derived from likes) and the posts you've liked — useful for seeing why the next ad slot might favor a certain category.
```

No other README sections need updating — the existing "Interest learning" section already describes the underlying mechanism; this just notes where to see it.

---

## 8. Success Criteria

v3 is complete when:

1. App runs on mobile and web via `flutter run`.
2. Bottom navigation shows Home and Liked tabs; tapping each switches the body.
3. Switching from Home to Liked preserves Home's scroll position (verify by scrolling Home, switching, switching back).
4. Liked tab shows empty state when nothing is liked.
5. After liking 3+ posts, Liked tab shows: interest profile chips sorted by percentage, and the liked posts below.
6. Unliking from the Liked tab removes the post from the Liked list in real time AND updates the interest profile chips.
7. On feed re-rank (FAB / pull-to-refresh / location change / interest change), the feed scrolls to top within ~300ms.
8. All 34 v2 tests still pass.
9. `flutter analyze` clean.
10. README Quick start mentions the bottom nav.
