import 'dart:html' as html;

class WebVadService {
  html.SpeechRecognition? _recognition;
  bool _isListening = false;

  void Function()? onSpeechStart;
  void Function()? onSpeechEnd;

  void initialize() {
    try {
      _recognition = html.SpeechRecognition();
      _recognition!.continuous = true;
      _recognition!.interimResults = false;
      
      _recognition!.onSpeechStart.listen((_) {
        if (onSpeechStart != null) onSpeechStart!();
      });

      _recognition!.onSpeechEnd.listen((_) {
        if (onSpeechEnd != null) onSpeechEnd!();
      });

      _recognition!.onEnd.listen((_) {
        if (_isListening) {
          try {
            _recognition?.start();
          } catch (e) {}
        }
      });
    } catch (e) {
      print('Web Speech API not supported: \');
    }
  }

  void start() {
    _isListening = true;
    try {
      _recognition?.start();
    } catch (e) {}
  }

  void stop() {
    _isListening = false;
    try {
      _recognition?.stop();
    } catch (e) {}
  }
}
