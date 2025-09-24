import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final res = await _client
        .get(_uri(path, query), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : json.decode(res.body);
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  Future<dynamic> post(String path, {Object? body, Map<String, String>? query}) async {
    final res = await _client
        .post(
          _uri(path, query),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: body == null ? null : json.encode(body),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : json.decode(res.body);
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }
}
