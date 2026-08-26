import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/student_models.dart';
import 'trusted_http_client.dart';

/// Use "http://10.0.2.2:5000" instead to reach a local Flask dev server from the Android emulator.
class ApiConfig {
  static const String baseUrl = "https://attendance-backend-c91g.onrender.com";
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static Future<http.Client>? _clientFuture;

  // Shared across every ApiService instance so a token set once at login/registration is used
  // everywhere without having to thread it through every screen.
  static String? _authToken;

  static void setAuthToken(String? token) => _authToken = token;

  Future<http.Client> _client() {
    _clientFuture ??= createTrustedHttpClient();
    return _clientFuture!;
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse("${ApiConfig.baseUrl}$path").replace(queryParameters: query);

  Map<String, String> get _authHeader =>
      _authToken != null ? {"Authorization": "Bearer $_authToken"} : {};

  dynamic _decodeOrThrow(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = (body is Map && body["error"] != null) ? body["error"].toString() : "Something went wrong.";
      throw ApiException(message);
    }
    return body;
  }

  Future<StudentProfile> login(String rollNumber, String password) async {
    final client = await _client();
    final response = await client.post(
      _uri("/api/students/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"roll_number": rollNumber, "password": password}),
    );
    return StudentProfile.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<void> updateFcmToken(String studentId, String token) async {
    final client = await _client();
    await client.post(
      _uri("/api/students/$studentId/fcm-token"),
      headers: {"Content-Type": "application/json", ..._authHeader},
      body: jsonEncode({"token": token}),
    );
  }

  Future<List<AttendanceHistoryEntry>> getAttendanceHistory(String studentId) async {
    final client = await _client();
    final response = await client.get(_uri("/api/students/$studentId/attendance"), headers: _authHeader);
    final data = _decodeOrThrow(response) as List;
    return data.map((e) => AttendanceHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// poses: keys among "front" (required), "left", "right", "extra".
  Future<StudentProfile> register({
    required String fullName,
    required String rollNumber,
    required String className,
    required String password,
    required Map<String, File> poses,
  }) async {
    final client = await _client();
    final request = http.MultipartRequest("POST", _uri("/api/students/register"))
      ..fields["full_name"] = fullName
      ..fields["roll_number"] = rollNumber
      ..fields["class_name"] = className
      ..fields["password"] = password;

    for (final entry in poses.entries) {
      request.files.add(await http.MultipartFile.fromPath("photo_${entry.key}", entry.value.path));
    }

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return StudentProfile.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }
}
