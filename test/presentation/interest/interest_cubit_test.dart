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
    // Allow ReactionCubit._init() async gap to complete so likedPostIds()
    // subscription is established before we push to the stream.
    await Future<void>.delayed(Duration.zero);

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
