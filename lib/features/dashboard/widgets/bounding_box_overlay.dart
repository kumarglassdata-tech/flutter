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

  const BoundingBoxOverlay({
    super.key,
    required this.lastContextOutput,
    this.imageSize,
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

    // Determine reference resolution
    double refWidth = imageSize?.width ?? 640.0;
    double refHeight = imageSize?.height ?? 480.0;
    
    if (imageSize == null) {
      for (final box in boxes) {
        if (box.left + box.width > refWidth) {
          refWidth = box.left + box.width;
        }
        if (box.top + box.height > refHeight) {
          refHeight = box.top + box.height;
        }
      }
    }

    return CustomPaint(
      painter: BoundingBoxPainter(
        boxes: boxes,
        refWidth: refWidth,
        refHeight: refHeight,
      ),
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

    // Format 2: tracked_objects
    final trackedObjects = raw['tracked_objects'];
    if (trackedObjects is List) {
      for (var item in trackedObjects) {
        if (item is Map) {
          final name = item['label']?.toString() ?? item['object_id']?.toString() ?? 'object';
          final conf = (item['confidence'] ?? 1.0) as num;
          final bbox = item['bbox_xyxy'];
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
          }
        }
      }
    }

    return boxes;
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<BoundingBox> boxes;
  final double refWidth;
  final double refHeight;

  BoundingBoxPainter({
    required this.boxes,
    required this.refWidth,
    required this.refHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / refWidth;
    final scaleY = size.height / refHeight;

    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF) // Neon Cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    final fillPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    for (var box in boxes) {
      final rect = Rect.fromLTWH(
        box.left * scaleX,
        box.top * scaleY,
        box.width * scaleX,
        box.height * scaleY,
      );

      // Draw box glow, border, and fill
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), glowPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), fillPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

      // Draw label capsule
      final textSpan = TextSpan(
        text: '${box.label.replaceAll('[COCO] ', '').replaceAll('[RF] ', '')} (${(box.confidence * 100).toStringAsFixed(0)}%)',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelHeight = textPainter.height + 6;
      final labelWidth = textPainter.width + 12;

      // Position label above the box (or inside if top-edge overflow)
      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - labelHeight >= 0 ? rect.top - labelHeight : rect.top,
        labelWidth,
        labelHeight,
      );

      final labelBackgroundPaint = Paint()
        ..color = const Color(0xFF00E5FF) // Neon Cyan
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          labelRect,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
          bottomLeft: Radius.zero,
        ),
        labelBackgroundPaint,
      );

      textPainter.paint(
        canvas,
        Offset(labelRect.left + 6, labelRect.top + 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.boxes != boxes ||
        oldDelegate.refWidth != refWidth ||
        oldDelegate.refHeight != refHeight;
  }
}
