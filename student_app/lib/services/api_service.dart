import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/student_models.dart';

/// Change this to your deployed backend, e.g. "https://yourusername.pythonanywhere.com".
/// Use "http://10.0.2.2:5000" to reach a Flask dev server on your PC from the Android emulator.
class ApiConfig {
  static const String baseUrl = "https://REPLACE_WITH_YOUR_PYTHONANYWHERE_DOMAIN.pythonanywhere.com";
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse("${ApiConfig.baseUrl}$path").replace(queryParameters: query);

  dynamic _decodeOrThrow(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = (body is Map && body["error"] != null) ? body["error"].toString() : "Something went wrong.";
      throw ApiException(message);
    }
    return body;
  }

  Future<StudentProfile> lookupByRollNumber(String rollNumber) async {
    final response = await http.get(_uri("/api/students/lookup", {"roll_number": rollNumber}));
    return StudentProfile.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<List<AttendanceHistoryEntry>> getAttendanceHistory(String studentId) async {
    final response = await http.get(_uri("/api/students/$studentId/attendance"));
    final data = _decodeOrThrow(response) as List;
    return data.map((e) => AttendanceHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// poses: keys among "front" (required), "left", "right", "extra".
  Future<StudentProfile> register({
    required String fullName,
    required String rollNumber,
    required String className,
    required Map<String, File> poses,
  }) async {
    final request = http.MultipartRequest("POST", _uri("/api/students/register"))
      ..fields["full_name"] = fullName
      ..fields["roll_number"] = rollNumber
      ..fields["class_name"] = className;

    for (final entry in poses.entries) {
      request.files.add(await http.MultipartFile.fromPath("photo_${entry.key}", entry.value.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return StudentProfile.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }
}
