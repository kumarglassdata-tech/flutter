class GateDecision {
  final bool shouldInteract;
  final bool shouldRunEcom;
  final bool shouldPersistMemory;
  final double relevanceScore;
  final String reason;

  const GateDecision({
    required this.shouldInteract,
    required this.shouldRunEcom,
    required this.shouldPersistMemory,
    required this.relevanceScore,
    required this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'shouldInteract': shouldInteract,
      'shouldRunEcom': shouldRunEcom,
      'shouldPersistMemory': shouldPersistMemory,
      'relevanceScore': relevanceScore,
      'reason': reason,
    };
  }
}
