import 'dart:ui';

class ContextResult {
  final String sceneDescription;
  final double sceneSalience;
  final List<TrackedObjectDomain> trackedObjects;

  const ContextResult({
    required this.sceneDescription,
    required this.sceneSalience,
    this.trackedObjects = const [],
  });
}

class TrackedObjectDomain {
  final String id;
  final String label;
  final Rect boundingBox;
  final double confidence;

  const TrackedObjectDomain({
    required this.id,
    required this.label,
    required this.boundingBox,
    required this.confidence,
  });
}
