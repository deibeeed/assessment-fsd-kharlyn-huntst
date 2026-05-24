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
