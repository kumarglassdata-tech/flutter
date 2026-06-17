class ActionHubResponseDto {
  final String schemaVersion;
  final String? endpointUsed;
  final Map<String, dynamic> payload;

  ActionHubResponseDto({
    this.schemaVersion = 'v1',
    this.endpointUsed,
    required this.payload,
  });

  factory ActionHubResponseDto.fromJson(Map<String, dynamic> json, String endpoint) {
    return ActionHubResponseDto(
      schemaVersion: json['schema_version'] ?? 'v1',
      endpointUsed: endpoint,
      payload: json, // Store the raw map since it varies based on interaction engine
    );
  }
}
