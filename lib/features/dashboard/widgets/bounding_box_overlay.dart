import 'package:flutter/material.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class BoundingBox {
  final String label;
  final double confidence;
  final double left;
  final double top;
  final double width;
  final double height;

  BoundingBox({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

class BoundingBoxOverlay extends StatelessWidget {
  final ContextEngineOutput? lastContextOutput;
  final Size? imageSize;
  final bool isMirrored;

  const BoundingBoxOverlay({
    super.key,
    required this.lastContextOutput,
    this.imageSize,
    this.isMirrored = false,
  });

  @override
  Widget build(BuildContext context) {
    if (lastContextOutput == null) {
      return const SizedBox.shrink();
    }

    final raw = lastContextOutput!.raw;
    final boxes = _extractBoundingBoxes(raw);

    if (boxes.isEmpty) {
      return const SizedBox.shrink();
    }

    // Auto-detect normalized coordinates (0.0 - 1.0)
    bool isNormalized = false;
    if (boxes.isNotEmpty) {
      double maxCoord = 0;
      for (final b in boxes) {
        if (b.left + b.width > maxCoord) maxCoord = b.left + b.width;
        if (b.top + b.height > maxCoord) maxCoord = b.top + b.height;
      }
      if (maxCoord <= 1.0) {
        isNormalized = true;
      }
    }

    double refWidth = isNormalized ? 1.0 : (imageSize?.width ?? 0.0);
    double refHeight = isNormalized ? 1.0 : (imageSize?.height ?? 0.0);
    
    if (!isNormalized && imageSize == null) {
      if (raw['gaze_grounding']?['gaze_coordinates'] != null) {
        final gazeX = (raw['gaze_grounding']['gaze_coordinates']['x'] as num).toDouble();
        final gazeY = (raw['gaze_grounding']['gaze_coordinates']['y'] as num).toDouble();
        if (gazeX > 0 && gazeY > 0) {
          refWidth = gazeX * 2;
          refHeight = gazeY * 2;
        }
      } else {
        // Fallback to finding max bounds if no gaze center is provided
        for (final box in boxes) {
          if (box.left + box.width > refWidth) {
            refWidth = box.left + box.width;
          }
          if (box.top + box.height > refHeight) {
            refHeight = box.top + box.height;
          }
        }
      }
    }

    if (refWidth <= 0.0) refWidth = 1.0;
    if (refHeight <= 0.0) refHeight = 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = constraints.maxWidth / refWidth;
        final scaleY = constraints.maxHeight / refHeight;

        return Stack(
          children: boxes.asMap().entries.map((entry) {
            final int index = entry.key;
            final BoundingBox box = entry.value;

            double left = box.left * scaleX;
            final double top = box.top * scaleY;
            double width = box.width * scaleX;
            double height = box.height * scaleY;

            if (width < 0) width = width.abs();
            if (height < 0) height = height.abs();

            if (isMirrored) {
              left = constraints.maxWidth - left - width;
            }

            return AnimatedPositioned(
              key: ValueKey('${box.label}_$index'),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: left,
              top: top,
              width: width > 0 ? width : 1.0,
              height: height > 0 ? height : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00E5FF), width: 2.5),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(5),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      '${box.label.replaceAll(RegExp(r'\[.*?\]\s*'), '')} ${(box.confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  List<BoundingBox> _extractBoundingBoxes(Map<String, dynamic> raw) {
    final List<BoundingBox> boxes = [];

    // Format 1: vision_response -> detected_objects
    final visionResponse = raw['vision_response'];
    if (visionResponse is Map) {
      final detectedObjects = visionResponse['detected_objects'];
      if (detectedObjects is List) {
        for (var item in detectedObjects) {
          if (item is Map) {
            final name = item['object_name']?.toString() ?? 'object';
            final conf = (item['confidence'] ?? 1.0) as num;
            final bbox = item['bounding_box'];
            if (bbox is Map) {
              final x = (bbox['x'] ?? 0.0) as num;
              final y = (bbox['y'] ?? 0.0) as num;
              final w = (bbox['width'] ?? 0.0) as num;
              final h = (bbox['height'] ?? 0.0) as num;

              boxes.add(BoundingBox(
                label: name,
                confidence: conf.toDouble(),
                left: x.toDouble(),
                top: y.toDouble(),
                width: w.toDouble(),
                height: h.toDouble(),
              ));
            }
          }
        }
      }
    }

    if (boxes.isNotEmpty) {
      return boxes;
    }

    final trackedObjects = raw['scene_objects'] ?? raw['tracked_objects'] ?? raw['results']?['vision']?['objects'];
    if (trackedObjects is List) {
      for (var item in trackedObjects) {
        if (item is Map) {
          final name = item['class_name']?.toString() ?? item['label']?.toString() ?? item['object_id']?.toString() ?? item['name']?.toString() ?? 'object';
          final conf = (item['confidence'] ?? item['conf'] ?? 1.0) as num;
          
          final bbox = item['bbox_xyxy'] ?? item['bbox'] ?? item['box'];
          if (bbox is List && bbox.length == 4) {
            final x1 = (bbox[0] ?? 0.0) as num;
            final y1 = (bbox[1] ?? 0.0) as num;
            final x2 = (bbox[2] ?? 0.0) as num;
            final y2 = (bbox[3] ?? 0.0) as num;

            boxes.add(BoundingBox(
              label: name,
              confidence: conf.toDouble(),
              left: x1.toDouble(),
              top: y1.toDouble(),
              width: (x2 - x1).toDouble(),
              height: (y2 - y1).toDouble(),
            ));
          } else if (bbox is Map) {
            final x = (bbox['x'] ?? 0.0) as num;
            final y = (bbox['y'] ?? 0.0) as num;
            final w = (bbox['width'] ?? bbox['w'] ?? 0.0) as num;
            final h = (bbox['height'] ?? bbox['h'] ?? 0.0) as num;
            boxes.add(BoundingBox(
              label: name,
              confidence: conf.toDouble(),
              left: x.toDouble(),
              top: y.toDouble(),
              width: w.toDouble(),
              height: h.toDouble(),
            ));
          }
        }
      }
    }

    return boxes;
  }
}
