import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';

class VideoDecoder {
  html.VideoElement? _video;
  html.CanvasElement? _canvas;
  double _duration = 0.0;
  double _currentTime = 0.0;
  String? _objectUrl;

  Future<void> loadVideo(Uint8List bytes, {String? fileName}) async {
    try {
      if (_objectUrl != null) {
        html.Url.revokeObjectUrl(_objectUrl!);
        _objectUrl = null;
      }
      if (_video != null) {
        _video!.remove();
        _video = null;
      }
      
      String mimeType = 'video/mp4';
      if (fileName != null) {
        final ext = fileName.split('.').last.toLowerCase();
        if (ext == 'webm') {
          mimeType = 'video/webm';
        } else if (ext == 'ogg' || ext == 'ogv') {
          mimeType = 'video/ogg';
        } else if (ext == 'mov') {
          mimeType = 'video/quicktime';
        } else if (ext == 'avi') {
          mimeType = 'video/x-msvideo';
        }
      }
      
      final blob = html.Blob([bytes], mimeType);
      _objectUrl = html.Url.createObjectUrl(blob);
      
      final video = html.VideoElement()
        ..src = _objectUrl!
        ..muted = true
        ..autoplay = false
        ..preload = 'auto'
        ..setAttribute('playsinline', 'true');
      
      video.style.display = 'none';
      html.document.body?.append(video);
      video.load();
      
      // Wait for metadata to load with a 5-second timeout
      await video.onLoadedMetadata.first.timeout(const Duration(seconds: 5), onTimeout: () {
        print('VideoDecoder: onLoadedMetadata timed out after 5s');
        return html.Event('timeout');
      });
      
      _video = video;
      _duration = video.duration.toDouble();
      if (_duration == 0.0 || _duration.isNaN) {
        _duration = 30.0; // Fallback duration
      }
      _currentTime = 0.0;
      
      _canvas = html.CanvasElement(
        width: video.videoWidth > 0 ? video.videoWidth : 640,
        height: video.videoHeight > 0 ? video.videoHeight : 480,
      );
      print('VideoDecoder: Video loaded successfully. Duration: $_duration, Size: ${video.videoWidth}x${video.videoHeight}');
    } catch (e, stack) {
      print('VideoDecoder loadVideo error: $e\n$stack');
    }
  }

  Future<Uint8List?> getNextFrame() async {
    final video = _video;
    final canvas = _canvas;
    if (video == null || canvas == null) {
      print('VideoDecoder getNextFrame: video or canvas is null');
      return null;
    }

    if (_currentTime >= _duration) {
      _currentTime = 0.0; // Loop playback
    }

    try {
      video.currentTime = _currentTime;
      // Wait for seek with a 1.5-second timeout
      await video.onSeeked.first.timeout(const Duration(milliseconds: 1500), onTimeout: () {
        print('VideoDecoder: seek to $_currentTime timed out');
        return html.Event('timeout');
      });
      
      final ctx = canvas.context2D;
      ctx.drawImage(video, 0, 0);
      
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
      final commaIndex = dataUrl.indexOf(',');
      if (commaIndex == -1) return null;
      
      final base64Str = dataUrl.substring(commaIndex + 1);
      final frameBytes = base64Decode(base64Str);
      
      _currentTime += 3.0; // Advance timestamp for next frame
      return frameBytes;
    } catch (e, stack) {
      print('VideoDecoder getNextFrame error: $e\n$stack');
      return null;
    }
  }

  void dispose() {
    try {
      if (_video != null) {
        _video!.remove();
        _video = null;
      }
      if (_objectUrl != null) {
        html.Url.revokeObjectUrl(_objectUrl!);
        _objectUrl = null;
      }
    } catch (_) {}
    _video = null;
    _canvas = null;
  }
}
