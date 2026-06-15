import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://myna-sme-dev.glassdata.ai/api/release').replace(queryParameters: {'text': 'organic_milk_1l'});
  print('Testing GET ' + url.toString());
  final response = await http.get(url, headers: {'Content-Type': 'application/json'});
  print('Status: ' + response.statusCode.toString());
  print('Body: ' + response.body);
}
