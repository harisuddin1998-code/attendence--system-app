import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/attendance_report.dart';
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

class TeacherAccount {
  final String id;
  final String name;
  final String teachingId;
  final String email;
  final List<String> courses;

  TeacherAccount({
    required this.id,
    required this.name,
    required this.teachingId,
    required this.email,
    required this.courses,
  });

  factory TeacherAccount.fromJson(Map<String, dynamic> json) => TeacherAccount(
        id: json["id"],
        name: json["name"],
        teachingId: json["teaching_id"] ?? "",
        email: json["email"],
        courses: (json["courses"] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class ApiService {
  static Future<http.Client>? _clientFuture;

  Future<http.Client> _client() {
    _clientFuture ??= createTrustedHttpClient();
    return _clientFuture!;
  }

  Uri _uri(String path) => Uri.parse("${ApiConfig.baseUrl}$path");

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(body["error"]?.toString() ?? "Something went wrong.");
    }
    return body;
  }

  Future<TeacherAccount> login(String email, String password) async {
    final client = await _client();
    final response = await client.post(
      _uri("/api/teachers/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    return TeacherAccount.fromJson(_decodeOrThrow(response));
  }

  Future<TeacherAccount> register({
    required String name,
    required String teachingId,
    required String email,
    required String password,
    required List<String> courses,
  }) async {
    final client = await _client();
    final response = await client.post(
      _uri("/api/teachers/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "teaching_id": teachingId,
        "email": email,
        "password": password,
        "courses": courses,
      }),
    );
    return TeacherAccount.fromJson(_decodeOrThrow(response));
  }

  Future<AttendanceReport> markAttendance({
    required String teacherId,
    required String className,
    required File leftImage,
    required File rightImage,
  }) async {
    final client = await _client();
    final request = http.MultipartRequest("POST", _uri("/api/attendance/mark"))
      ..fields["teacher_id"] = teacherId
      ..fields["class_name"] = className
      ..files.add(await http.MultipartFile.fromPath("left_image", leftImage.path))
      ..files.add(await http.MultipartFile.fromPath("right_image", rightImage.path));

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return AttendanceReport.fromJson(_decodeOrThrow(response));
  }
}
