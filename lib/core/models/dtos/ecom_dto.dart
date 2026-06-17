class EcomResponseDto {
  final String schemaVersion;
  final String? productUrl;
  final String? price;

  EcomResponseDto({
    this.schemaVersion = 'v1',
    this.productUrl,
    this.price,
  });

  factory EcomResponseDto.fromJson(Map<String, dynamic> json) {
    return EcomResponseDto(
      schemaVersion: json['schema_version'] ?? 'v1',
      productUrl: json['product_url'] as String?,
      price: json['price'] as String?,
    );
  }
}
