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
