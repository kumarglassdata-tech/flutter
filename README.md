# smartglass_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## Inference Integration (Current Status)

- The project includes a placeholder `InferenceService` at `lib/core/inference/inference_service.dart` that returns nine placeholder outputs (`output1`..`output9`).
- Camera, audio (simulated), and GPS (simulated) telemetry are wired into `SessionProvider` and updated into `SessionState.modelOutputs` once per second.
- Image preprocessing is stubbed in `lib/core/inference/preprocessors.dart` and offloaded with `compute()` when available.

## Quick Commands

- Run the app (debug):

```bash
flutter run
```

- Run unit tests:

```bash
flutter test
```

- Run a simple inference benchmark script (Dart VM):

```bash
dart run tool/benchmark_inference.dart
```

## Next Steps to enable real inference

1. Provide a trained model (TFLite / ONNX / PyTorch) and the expected input preprocessing (image size, normalization, audio features). Place the model under `assets/models/` or `lib/assets/`.
2. I will integrate an inference runtime (e.g., `tflite_flutter` for TFLite or `onnxruntime` for ONNX), add dependencies to `pubspec.yaml`, and implement `InferenceService.registerModel` and `runInference`.
3. Replace the placeholder preprocessors with real image decoding/resizing and MFCC/spectrogram extraction for audio.
4. Tune performance: quantize model, run in isolates, or use platform-specific delegates (NNAPI/Metal/EdgeTPU).

If you want, I can integrate a specific runtime now — tell me the model format or upload the model file and I'll proceed.
