class MemoryResponseDto {
  final String schemaVersion;
  final String? memoryId;
  final String? status;
  final String? summary;

  MemoryResponseDto({
    this.schemaVersion = 'v1',
    this.memoryId,
    this.status,
    this.summary,
  });

  factory MemoryResponseDto.fromJson(Map<String, dynamic> json) {
    return MemoryResponseDto(
      schemaVersion: json['schema_version'] ?? 'v1',
      memoryId: json['memory_id'] as String?,
      status: json['status'] as String?,
      summary: json['summary'] as String?,
    );
  }
}
