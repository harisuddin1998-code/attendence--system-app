import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';

// Must be a top-level function - FCM calls this in a separate isolate when a message arrives
// while the app is backgrounded or terminated. It doesn't need to do anything: the backend sends
// a `notification` payload, which Android displays via the system tray on its own in that case.
// The handler just needs to exist for background delivery to be registered at all.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  await NotificationService.instance.init();
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
  bool _hasToken = false;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("student_token");
    if (token != null) ApiService.setAuthToken(token);
    setState(() {
      _studentId = prefs.getString("student_id");
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
    if (_studentId != null && _hasToken) {
      return DashboardScreen(studentId: _studentId!);
    }
    return const WelcomeScreen();
  }
}
