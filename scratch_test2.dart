import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://myna-sme-dev.glassdata.ai/api/release/process_frame');
  final request = http.MultipartRequest('POST', url);
  request.files.add(
    http.MultipartFile.fromBytes(
      'file',
      [255, 216, 255, 224, 0, 16],
      filename: 'frame.jpg',
    ),
  );
  request.fields['gps_hazard'] = 'false';

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);
  print('STATUS: ${response.statusCode}');
  print('BODY: ${response.body}');
}
