import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const AttendanceTeacherApp());
}

class AttendanceTeacherApp extends StatelessWidget {
  const AttendanceTeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Teacher Attendance",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F7CFF),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const _StartupGate(),
    );
  }
}

/// Skips straight to the home screen if a teacher session was saved from a previous login.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _loading = true;
  bool _hasToken = false;
  String? _teacherId;
  String? _teacherName;
  List<String> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("teacher_token");
    if (token != null) ApiService.setAuthToken(token);
    setState(() {
      _teacherId = prefs.getString("teacher_id");
      _teacherName = prefs.getString("teacher_name");
      _courses = prefs.getStringList("teacher_courses") ?? [];
      _hasToken = token != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // A session saved before login started issuing tokens has no token to restore - treat it as
    // logged out rather than letting it call authenticated endpoints with nothing to send.
    if (_teacherId != null && _teacherName != null && _hasToken) {
      return HomeScreen(teacherId: _teacherId!, teacherName: _teacherName!, courses: _courses);
    }
    return const LoginScreen();
  }
}
