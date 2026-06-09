import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

enum ModelFormat { tflite, onnx, pytorch, unknown }

class InferenceResult {
  final Map<String, dynamic> outputs;
  InferenceResult(this.outputs);
}

class InferenceService {
  Interpreter? _interpreter;

  InferenceService();

  Future<void> registerModel(String assetPath) async {
    try {
      _interpreter = await Interpreter.fromAsset(assetPath);
    } catch (e) {
      _interpreter = null;
    }
  }

  bool get hasModel => _interpreter != null;

  List<double> _preprocessImage(Uint8List bytes, int targetW, int targetH) {
    final image = img.decodeImage(bytes);
    if (image == null) return List<double>.filled(targetW * targetH * 3, 0.0);
    final resized = img.copyResize(image, width: targetW, height: targetH);
    final out = <double>[];
    for (var y = 0; y < targetH; y++) {
      for (var x = 0; x < targetW; x++) {
        final p = resized.getPixel(x, y);
        out.add((p.r / 255.0));
        out.add((p.g / 255.0));
        out.add((p.b / 255.0));
      }
    }
    return out;
  }

  Future<InferenceResult> runInference({
    required Uint8List? imageBytes,
    required List<double>? audioFeatures,
    required Map<String, double>? gpsFeatures,
  }) async {
    if (_interpreter == null) {
      final outputs = <String, dynamic>{};
      for (var i = 1; i <= 9; i++) {
        outputs['output$i'] = 0.0;
      }
      return InferenceResult(outputs);
    }

    final inputTensors = _interpreter!.getInputTensors();
    if (inputTensors.isEmpty) {
      return InferenceResult({});
    }
    final inShape = inputTensors.first.shape;
    int w = 224, h = 224;
    if (inShape.length >= 3) {
      h = inShape[inShape.length - 3];
      w = inShape[inShape.length - 2];
    }

    final input = imageBytes == null ? null : _preprocessImage(imageBytes, w, h);
    final inputBuffer = Float32List.fromList(input ?? List.filled(w * h * 3, 0.0));
    final outputTensors = _interpreter!.getOutputTensors();
    final outShape = outputTensors.isNotEmpty ? outputTensors.first.shape : [1, 9];
    final outLen = outShape.reduce((a, b) => a * b);
    final outputBuffer = List.filled(outLen, 0.0).cast<double>();

    try {
      _interpreter!.run(inputBuffer.buffer.asFloat32List(), outputBuffer);
    } catch (e) {
      final outputs = <String, dynamic>{};
      for (var i = 1; i <= 9; i++) {
        outputs['output$i'] = 0.0;
      }
      return InferenceResult(outputs);
    }

    final outputs = <String, dynamic>{};
    for (var i = 0; i < outLen; i++) {
      outputs['output${i + 1}'] = outputBuffer[i].toDouble();
    }
    return InferenceResult(outputs);
  }
}
