class ActionHubResult {
  final String actionEndpoint;
  final Map<String, dynamic> generatedPayload;
  final String? productLink;
  final String? imageUrl;

  const ActionHubResult({
    required this.actionEndpoint,
    required this.generatedPayload,
    this.productLink,
    this.imageUrl,
  });
}
