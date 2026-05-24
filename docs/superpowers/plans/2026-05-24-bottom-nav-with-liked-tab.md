# Bottom Nav with Liked Tab (v3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Material 3 bottom navigation with Home and Liked tabs; the Liked tab shows the derived interest profile + liked posts. Also: feed auto-scrolls to top on every re-rank.

**Architecture:** Three new presentation files (RootShell, LikedPage, _InterestChipStrip) + one stateful refactor of MixedFeedView (adds ScrollController + BlocListener for scroll-to-top) + one-line main.dart change. No new blocs, repositories, models, or tests. Both tabs share the existing MultiBlocProvider so the interest signal flows across tabs.

**Tech Stack:** Existing v2 stack (Flutter, Dart 3, Material 3, flutter_bloc, hive, cached_network_image). No new dependencies.

**Source spec:** `docs/superpowers/specs/2026-05-24-bottom-nav-with-liked-tab-design.md`
**Builds on:** v0.2 implementation tagged `v0.2-assessment-submission`.

---

## File Structure (delta from v2)

```
lib/
  presentation/
    shell/
      root_shell.dart                 # NEW — Scaffold + NavigationBar + IndexedStack
    liked/
      view/
        liked_page.dart               # NEW — LikedPage + _LikedBody + _InterestChipStrip
    feed/
      view/
        mixed_feed_view.dart          # MODIFY — Stateless → Stateful, ScrollController, BlocListener
  main.dart                           # MODIFY — home: RootShell, remove unused FeedPage import

README.md                             # MODIFY — Quick start mentions bottom nav
```

No new test files. 34 existing tests must continue to pass.

---

## Task 1: Refactor MixedFeedView for scroll-to-top on re-rank

**Files:**
- Modify: `lib/presentation/feed/view/mixed_feed_view.dart`

- [ ] **Step 1: Replace `mixed_feed_view.dart` entirely**

Replace the current `lib/presentation/feed/view/mixed_feed_view.dart` with:

```dart
import 'package:ad_ranking_prototype/core/constants.dart';
import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_bloc.dart';
import 'package:ad_ranking_prototype/presentation/analytics/bloc/analytics_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_bloc.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_event.dart';
import 'package:ad_ranking_prototype/presentation/feed/bloc/feed_state.dart';
import 'package:ad_ranking_prototype/presentation/feed/view/ad_card.dart';
import 'package:ad_ranking_prototype/presentation/feed/view/post_card.dart';
import 'package:ad_ranking_prototype/presentation/reactions/cubit/reaction_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

  /// Builds a flat list of items in render order. Pure function of inputs.
  /// Pattern: for every kPostsPerAd posts, append one ad (if any remain).
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

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final likedIds = context.watch<ReactionCubit>().state;
    final items = _buildItems();

    return BlocListener<FeedBloc, FeedState>(
      listenWhen: (prev, curr) => prev is FeedLoaded && curr is FeedLoaded,
      listener: (_, __) => _scrollToTop(),
      child: RefreshIndicator(
        onRefresh: () async =>
            context.read<FeedBloc>().add(const FeedRequested()),
        child: ListView.separated(
          controller: _scrollController,
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
                  userLocation: widget.userLocation,
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
      ),
    );
  }
}
```

Changes from the v2 version:
- `StatelessWidget` → `StatefulWidget` with `_MixedFeedViewState`
- `_scrollController` field + `dispose()`
- `_buildItems()` reads from `widget.posts`/`widget.rankedAds` instead of local params
- `_scrollToTop()` helper guarded by `hasClients`
- Outer wrap: `BlocListener<FeedBloc, FeedState>` with `listenWhen: prev is FeedLoaded && curr is FeedLoaded`
- `ListView.separated` now has `controller: _scrollController`
- `userLocation` reference inside `AdCard` is `widget.userLocation`

- [ ] **Step 2: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/presentation/feed/view/mixed_feed_view.dart
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
```

Expected: zero issues, 34/34 tests still pass.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/feed/view/mixed_feed_view.dart
git commit -m "feat(feed): MixedFeedView scrolls to top on re-rank"
```

---

## Task 2: LikedPage + InterestChipStrip

**Files:**
- Create: `lib/presentation/liked/view/liked_page.dart`

- [ ] **Step 1: Create the file**

Create `lib/presentation/liked/view/liked_page.dart`:

```dart
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/presentation/feed/view/post_card.dart';
import 'package:ad_ranking_prototype/presentation/interest/cubit/interest_cubit.dart';
import 'package:ad_ranking_prototype/presentation/location/view/location_picker.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_bloc.dart';
import 'package:ad_ranking_prototype/presentation/posts/bloc/post_state.dart';
import 'package:ad_ranking_prototype/presentation/reactions/cubit/reaction_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        PostInitial() ||
        PostLoading() =>
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
              Icon(
                Icons.favorite_outline,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
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
      itemCount: liked.length + 1,
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

- [ ] **Step 2: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/presentation/liked/
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
```

Expected: zero issues, 34/34 still pass.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/liked/view/liked_page.dart
git commit -m "feat(presentation): add LikedPage with interest profile chip strip"
```

---

## Task 3: RootShell with NavigationBar + IndexedStack

**Files:**
- Create: `lib/presentation/shell/root_shell.dart`

- [ ] **Step 1: Create the file**

Create `lib/presentation/shell/root_shell.dart`:

```dart
import 'package:ad_ranking_prototype/presentation/feed/view/feed_page.dart';
import 'package:ad_ranking_prototype/presentation/liked/view/liked_page.dart';
import 'package:flutter/material.dart';

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

- [ ] **Step 2: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze lib/presentation/shell/
```

Expected: zero issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/shell/root_shell.dart
git commit -m "feat(presentation): add RootShell with NavigationBar + IndexedStack"
```

---

## Task 4: Wire RootShell into main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Edit imports**

In `lib/main.dart`:

Find:
```dart
import 'package:ad_ranking_prototype/presentation/feed/view/feed_page.dart';
```

Replace with:
```dart
import 'package:ad_ranking_prototype/presentation/shell/root_shell.dart';
```

- [ ] **Step 2: Change `home:`**

In the `MaterialApp` constructor at the bottom of `AdRankingApp.build`, find:
```dart
home: const FeedPage(),
```

Replace with:
```dart
home: const RootShell(),
```

- [ ] **Step 3: Verify**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter analyze
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter test
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter build web --no-tree-shake-icons
```

Expected: zero analyzer issues; 34/34 tests pass; web build succeeds.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: swap MaterialApp home to RootShell (bottom nav)"
```

---

## Task 5: README Quick start update

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the bottom-nav paragraph**

In `README.md`, find the existing paragraph in the "## Quick start" section that starts with `Tap the heart on any post to like it.` Append this new paragraph immediately after it:

```markdown

The bottom navigation has two tabs: Home (the social feed) and Liked. The Liked tab shows your current interest profile (per-category percentages derived from likes) and the posts you've liked — useful for seeing why the next ad slot might favor a certain category.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: note bottom nav + Liked tab in Quick start"
```

---

## Task 6: Final verification + retag

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

Expected: 34 tests pass (no new tests added in v3 by design).

- [ ] **Step 3: Web build**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter build web --no-tree-shake-icons
```

Expected: `✓ Built build/web`.

- [ ] **Step 4: Mobile APK debug build**

```bash
/Users/deibeeed/fvm/versions/3.41.6/bin/flutter build apk --debug
```

Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`. If Android SDK is missing on this machine, document as "manual verification needed on user's device" rather than blocking.

- [ ] **Step 5: Move tag forward to v0.3**

```bash
git tag v0.3-assessment-submission
```

(v0.1 and v0.2 tags stay where they are.)

- [ ] **Step 6: Final status**

```bash
git status
git log --oneline | head -15
```

Confirm working tree clean; ~6 new commits since `v0.2-assessment-submission`.

- [ ] **Step 7: Print smoke-test checklist for the user**

```
SMOKE TEST CHECKLIST (user runs on device):

1. Cold-launch the app (full `flutter run`, not hot-restart, since v3 changes app shell structure).
2. Bottom nav visible with Home + Liked tabs. Home is selected by default.
3. Scroll Home feed by ~10 cards. Tap Liked tab. Tap Home tab. Confirm scroll position is preserved (you're NOT back at the top).
4. Liked tab: with no likes yet, see the empty state ("Tap hearts on the Home tab…").
5. Like 4 coffee posts on Home. Tap Liked tab. See: "Your interest profile" chip showing Coffee 100%; the 4 liked posts below.
6. Like a food post. Switch to Liked. Chips now show Coffee + Food with adjusted percentages.
7. Unlike one of the coffee posts from inside the Liked tab. The post disappears immediately; percentages re-balance.
8. Switch back to Home. Tap the refresh FAB. The feed animates a scroll to top (~300ms). The first ad slot should reflect the updated interest profile.
9. Switch location to Cebu via dropdown (Home OR Liked — both have the picker). Feed re-ranks AND scrolls to top.
```

---

## Done

If all of Task 6 passes plus the user's interactive smoke test, v3 is complete. Total delta on top of v2:

- ✅ 2 new presentation files (RootShell, LikedPage)
- ✅ 1 stateful refactor (MixedFeedView gains ScrollController + auto-scroll-to-top)
- ✅ 1-line main.dart switch
- ✅ README Quick start updated
- ✅ 34/34 tests still pass (no new tests by design)
- ✅ Tagged `v0.3-assessment-submission`
