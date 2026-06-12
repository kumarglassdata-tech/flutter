class BehaviorResponseDto {
  final String schemaVersion;
  final String? behavioralState;
  final double? stateConfidence;
  final double? relevanceScore;

  BehaviorResponseDto({
    this.schemaVersion = 'v1',
    this.behavioralState,
    this.stateConfidence,
    this.relevanceScore,
  });

  factory BehaviorResponseDto.fromJson(Map<String, dynamic> json) {
    return BehaviorResponseDto(
      schemaVersion: json['schema_version'] ?? 'v1',
      behavioralState: json['behavioral_state'] as String?,
      stateConfidence: (json['state_confidence'] as num?)?.toDouble(),
      relevanceScore: (json['relevance_score'] as num?)?.toDouble(),
    );
  }
}
