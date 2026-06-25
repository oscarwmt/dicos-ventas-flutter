import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'session_manager.dart';

class ApiService {
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final url = '${ApiConfig.baseUrl}/$endpoint';

    _logRequest(method: 'GET', endpoint: endpoint, url: url, token: token);

    final response = await http.get(Uri.parse(url), headers: _headers(token));

    _logResponse(method: 'GET', endpoint: endpoint, response: response);

    return _processResponse(response, prefs);
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final url = '${ApiConfig.baseUrl}/$endpoint';

    _logRequest(
      method: 'POST',
      endpoint: endpoint,
      url: url,
      token: token,
      body: body,
    );

    final response = await http.post(
      Uri.parse(url),
      headers: _headers(token),
      body: json.encode(body),
    );

    _logResponse(method: 'POST', endpoint: endpoint, response: response);

    return _processResponse(response, prefs);
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final url = '${ApiConfig.baseUrl}/$endpoint';

    _logRequest(
      method: 'PUT',
      endpoint: endpoint,
      url: url,
      token: token,
      body: body,
    );

    final response = await http.put(
      Uri.parse(url),
      headers: _headers(token),
      body: json.encode(body),
    );

    _logResponse(method: 'PUT', endpoint: endpoint, response: response);

    return _processResponse(response, prefs);
  }

  static Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'x-access-token': token,
    };
  }

  static Future<Map<String, dynamic>> _processResponse(
    http.Response response,
    SharedPreferences prefs,
  ) async {
    Map<String, dynamic> data = {};

    try {
      data = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = {
        'ok': false,
        'error': 'Respuesta inválida del servidor',
        'raw': response.body,
      };
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        await SessionManager.logout();
      }

      throw Exception(data['error'] ?? 'Error del servidor');
    }

    return data;
  }

  static void _logRequest({
    required String method,
    required String endpoint,
    required String url,
    required String token,
    Map<String, dynamic>? body,
  }) {
    debugPrint('==============================');
    debugPrint('$method: $endpoint');
    debugPrint('URL: $url');
    debugPrint('TOKEN LENGTH: ${token.length}');
    debugPrint(
      'TOKEN START: ${token.length > 20 ? token.substring(0, 20) : token}',
    );

    if (body != null) {
      debugPrint('BODY $method: ${json.encode(body)}');
    }

    debugPrint('==============================');
  }

  static void _logResponse({
    required String method,
    required String endpoint,
    required http.Response response,
  }) {
    debugPrint('STATUS $method $endpoint: ${response.statusCode}');
    debugPrint('BODY $method $endpoint: ${response.body}');
  }
}
