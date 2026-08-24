import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/dashboard_screen.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const AttendanceStudentApp());
}

class AttendanceStudentApp extends StatelessWidget {
  const AttendanceStudentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Student Attendance",
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

/// Skips straight to the dashboard if a student session was saved from a previous lookup.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _loading = true;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentId = prefs.getString("student_id");
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_studentId != null) {
      return DashboardScreen(studentId: _studentId!);
    }
    return const WelcomeScreen();
  }
}
