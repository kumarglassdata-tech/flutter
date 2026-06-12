import '../domain/context_result.dart';
import '../dtos/context_dto.dart';

class ContextMapper {
  static ContextResult fromDto(ContextResponseDto dto) {
    return ContextResult(
      sceneDescription: dto.sceneContext?.description ?? '',
      sceneSalience: dto.sceneContext?.overallSalience ?? 0.0,
      trackedObjects: (dto.trackedObjects ?? []).map((obj) {
        return TrackedObjectDomain(
          id: obj.objectId,
          label: obj.label,
          boundingBox: obj.bbox,
          confidence: obj.confidence,
        );
      }).toList(),
    );
  }
}
