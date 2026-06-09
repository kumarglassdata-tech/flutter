import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AudioClient {
  final String baseUrl;

  AudioClient({required this.baseUrl});

  Future<Map<String, dynamic>> sendAudio(Uint8List wavBytes) async {
    final uri = Uri.parse(baseUrl);
    
    final base64Audio = base64Encode(wavBytes);
    
    final requestBody = {
      'audio': base64Audio,
    };

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Audio server error: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to send audio: $e');
    }
  }
}
