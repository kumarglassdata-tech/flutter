import 'dart:io';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoDecoder {
  String? _tempFilePath;
  int _currentTimeMs = 0;

  Future<void> loadVideo(Uint8List bytes, {String? fileName}) async {
    try {
      await dispose(); // Clean up any existing file
      
      final tempDir = Directory.systemTemp;
      final name = fileName ?? 'temp_video.mp4';
      final file = File('${tempDir.path}/$name');
      await file.writeAsBytes(bytes);
      _tempFilePath = file.path;
      _currentTimeMs = 0;
      print('VideoDecoder (Mobile): Saved temporary video to $_tempFilePath');
    } catch (e, stack) {
      print('VideoDecoder (Mobile) loadVideo error: $e\n$stack');
    }
  }

  Future<Uint8List?> getNextFrame() async {
    if (_tempFilePath == null) {
      print('VideoDecoder (Mobile) getNextFrame: no loaded video');
      return null;
    }

    try {
      Uint8List? frameBytes = await VideoThumbnail.thumbnailData(
        video: _tempFilePath!,
        imageFormat: ImageFormat.JPEG,
        timeMs: _currentTimeMs,
        maxWidth: 640,
        quality: 75,
      );

      if (frameBytes == null && _currentTimeMs > 0) {
        // Wrap around to start if we got null (possibly EOF)
        print('VideoDecoder (Mobile) getNextFrame: EOF or null frame at $_currentTimeMs ms, wrapping around to 0 ms');
        _currentTimeMs = 0;
        frameBytes = await VideoThumbnail.thumbnailData(
          video: _tempFilePath!,
          imageFormat: ImageFormat.JPEG,
          timeMs: _currentTimeMs,
          maxWidth: 640,
          quality: 75,
        );
      }

      _currentTimeMs += 3000; // Advance timestamp for next frame
      return frameBytes;
    } catch (e, stack) {
      print('VideoDecoder (Mobile) getNextFrame error: $e\n$stack');
      // On error, let's try wrapping around to 0 just in case it was a seek error
      if (_currentTimeMs > 0) {
        try {
          _currentTimeMs = 0;
          return await VideoThumbnail.thumbnailData(
            video: _tempFilePath!,
            imageFormat: ImageFormat.JPEG,
            timeMs: _currentTimeMs,
            maxWidth: 640,
            quality: 75,
          );
        } catch (_) {}
      }
      return null;
    }
  }

  Future<void> dispose() async {
    if (_tempFilePath != null) {
      try {
        final file = File(_tempFilePath!);
        if (await file.exists()) {
          await file.delete();
          print('VideoDecoder (Mobile): Cleaned up $_tempFilePath');
        }
      } catch (e) {
        print('VideoDecoder (Mobile) dispose error: $e');
      }
      _tempFilePath = null;
    }
  }
}
