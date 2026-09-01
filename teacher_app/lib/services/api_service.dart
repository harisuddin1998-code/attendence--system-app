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
  final String token;

  TeacherAccount({
    required this.id,
    required this.name,
    required this.teachingId,
    required this.email,
    required this.courses,
    required this.token,
  });

  factory TeacherAccount.fromJson(Map<String, dynamic> json) => TeacherAccount(
        id: json["id"],
        name: json["name"],
        teachingId: json["teaching_id"] ?? "",
        email: json["email"],
        courses: (json["courses"] as List?)?.map((e) => e.toString()).toList() ?? [],
        token: json["token"],
      );
}

class ApiService {
  static Future<http.Client>? _clientFuture;

  // Shared across every ApiService instance so a token set once at login/startup is used
  // everywhere without having to thread it through every screen.
  static String? _authToken;

  static void setAuthToken(String? token) => _authToken = token;

  Future<http.Client> _client() {
    _clientFuture ??= createTrustedHttpClient();
    return _clientFuture!;
  }

  Uri _uri(String path) => Uri.parse("${ApiConfig.baseUrl}$path");

  Map<String, String> get _authHeader =>
      _authToken != null ? {"Authorization": "Bearer $_authToken"} : {};

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    final raw = response.body.trim();
    if (raw.isEmpty) {
      throw ApiException("Server returned an empty response.");
    }
    if (raw.startsWith("<")) {
      throw ApiException("Backend returned HTML instead of JSON. Check the server logs.");
    }

    try {
      final body = jsonDecode(raw);
      if (body is! Map<String, dynamic>) {
        throw ApiException("Unexpected server response format.");
      }
      if (response.statusCode >= 400) {
        throw ApiException(body["error"]?.toString() ?? "Something went wrong.");
      }
      return body;
    } on FormatException {
      throw ApiException("Invalid server response. Please try again.");
    }
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
    // teacher_id is no longer sent - the backend identifies the teacher from the Bearer token
    // instead of trusting a client-supplied field.
    final request = http.MultipartRequest("POST", _uri("/api/attendance/mark"))
      ..headers.addAll(_authHeader)
      ..fields["class_name"] = className
      ..files.add(await http.MultipartFile.fromPath("left_image", leftImage.path))
      ..files.add(await http.MultipartFile.fromPath("right_image", rightImage.path));

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return AttendanceReport.fromJson(_decodeOrThrow(response));
  }

  Future<DetectedFace> identifyFace({required String recordId, required String rollNumber}) async {
    final client = await _client();
    final response = await client.post(
      _uri("/api/attendance/records/$recordId/identify"),
      headers: {"Content-Type": "application/json", ..._authHeader},
      body: jsonEncode({"roll_number": rollNumber}),
    );
    final body = _decodeOrThrow(response);
    return DetectedFace(
      recordId: body["record_id"],
      faceCropUrl: "",
      sourceImage: "",
      studentId: body["student_id"],
      fullName: body["full_name"],
      rollNumber: body["roll_number"],
    );
  }
}
