import 'dart:ui';

class ContextResponseDto {
  final String schemaVersion;
  final SceneContextDto? sceneContext;
  final List<TrackedObjectDto>? trackedObjects;

  ContextResponseDto({
    this.schemaVersion = 'v1',
    this.sceneContext,
    this.trackedObjects,
  });

  factory ContextResponseDto.fromJson(Map<String, dynamic> json) {
    return ContextResponseDto(
      schemaVersion: json['schema_version'] ?? 'v1',
      sceneContext: json['scene_context'] != null ? SceneContextDto.fromJson(json['scene_context']) : null,
      trackedObjects: (json['tracked_objects'] as List<dynamic>?)
          ?.map((e) => TrackedObjectDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SceneContextDto {
  final String? description;
  final double? overallSalience;

  SceneContextDto({this.description, this.overallSalience});

  factory SceneContextDto.fromJson(Map<String, dynamic> json) {
    return SceneContextDto(
      description: json['description'] as String?,
      overallSalience: (json['overall_salience'] as num?)?.toDouble(),
    );
  }
}

class TrackedObjectDto {
  final String objectId;
  final String label;
  final String trackId;
  final Rect bbox;
  final double confidence;

  TrackedObjectDto({
    required this.objectId,
    required this.label,
    required this.trackId,
    required this.bbox,
    required this.confidence,
  });

  factory TrackedObjectDto.fromJson(Map<String, dynamic> json) {
    final bboxList = json['bbox'] as List<dynamic>? ?? [0.0, 0.0, 0.0, 0.0];
    final left = (bboxList.length > 0 ? bboxList[0] : 0.0) as num;
    final top = (bboxList.length > 1 ? bboxList[1] : 0.0) as num;
    final width = (bboxList.length > 2 ? bboxList[2] : 0.0) as num;
    final height = (bboxList.length > 3 ? bboxList[3] : 0.0) as num;

    return TrackedObjectDto(
      objectId: json['object_id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'unknown',
      trackId: json['track_id']?.toString() ?? '',
      bbox: Rect.fromLTWH(left.toDouble(), top.toDouble(), width.toDouble(), height.toDouble()),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
