import '../domain/interaction_result.dart';
import '../dtos/interaction_dto.dart';

class InteractionMapper {
  static InteractionResult fromDto(InteractionResponseDto dto) {
    return InteractionResult(
      dialogueText: dto.dialogueText ?? '',
      actionType: dto.actionType ?? 'unknown',
    );
  }
}
