enum BehavioralState {
  passiveBrowsing,
  productInterest,
  comparison,
  purchaseConsideration,
  assistanceSeeking,
  unknown
}

class BehaviorResult {
  final BehavioralState state;
  final double confidence;
  final double relevanceScore;

  const BehaviorResult({
    required this.state,
    required this.confidence,
    required this.relevanceScore,
  });
}
