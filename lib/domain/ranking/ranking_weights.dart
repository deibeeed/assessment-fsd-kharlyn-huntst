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
