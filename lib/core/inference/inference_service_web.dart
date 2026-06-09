import 'dart:typed_data';

enum ModelFormat { tflite, onnx, pytorch, unknown }

class InferenceResult {
  final Map<String, dynamic> outputs;
  InferenceResult(this.outputs);
}

/// Web-friendly fallback inference service that returns placeholder outputs.
class InferenceService {
  InferenceService();

  Future<void> registerModel(String assetPath) async {
    // No-op on web; FFI-based runtimes are not available in web builds.
    return;
  }

  bool get hasModel => false;

  Future<InferenceResult> runInference({
    required Uint8List? imageBytes,
    required List<double>? audioFeatures,
    required Map<String, double>? gpsFeatures,
  }) async {
    final outputs = <String, dynamic>{};
    for (var i = 1; i <= 9; i++) {
      outputs['output$i'] = 0.0;
    }
    return InferenceResult(outputs);
  }
}
