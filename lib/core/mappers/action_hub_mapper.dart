import '../domain/action_hub_result.dart';
import '../dtos/action_hub_dto.dart';

class ActionHubMapper {
  static ActionHubResult fromDto(ActionHubResponseDto dto) {
    final payload = dto.payload;
    final String? link = payload['product_url'] ?? payload['link'] ?? payload['url'];
    final String? image = payload['image_url'] ?? payload['thumbnail'] ?? payload['image'];

    return ActionHubResult(
      actionEndpoint: dto.endpointUsed ?? 'unknown',
      generatedPayload: payload,
      productLink: link,
      imageUrl: image,
    );
  }
}
