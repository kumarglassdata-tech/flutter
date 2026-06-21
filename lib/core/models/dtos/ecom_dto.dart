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
    String? productUrl = json['product_url'] as String?;
    String? price = json['price'] as String?;

    // Handle ecom_client's array wrapper or mock fallback
    if (productUrl == null && json.containsKey('suggestions')) {
      final suggestions = json['suggestions'] as List?;
      if (suggestions != null && suggestions.isNotEmpty) {
        final firstItem = suggestions.first;
        if (firstItem is Map) {
          productUrl = firstItem['product_url'] as String? ?? firstItem['link'] as String?;
          price = firstItem['price'] as String?;
        } else if (firstItem is String) {
          productUrl = firstItem;
        }
      }
    }

    return EcomResponseDto(
      schemaVersion: json['schema_version'] ?? 'v1',
      productUrl: productUrl,
      price: price,
    );
  }
}
