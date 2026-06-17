class InteractionResponseDto {
  final String schemaVersion;
  final String? dialogueText;
  final String? actionType;

  InteractionResponseDto({
    this.schemaVersion = 'v1',
    this.dialogueText,
    this.actionType,
  });

  factory InteractionResponseDto.fromJson(Map<String, dynamic> json) {
    return InteractionResponseDto(
      schemaVersion: json['schema_version'] ?? 'v1',
      dialogueText: json['dialogue_text'] as String?,
      actionType: json['action_type'] as String?,
    );
  }
}
