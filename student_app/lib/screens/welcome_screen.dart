import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _rollController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _errorText;

  Future<void> _lookup() async {
    final rollNumber = _rollController.text.trim();
    if (rollNumber.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final student = await _apiService.lookupByRollNumber(rollNumber);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("student_id", student.id);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DashboardScreen(studentId: student.id)));
    } catch (e) {
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              const SizedBox(height: 40),
              Text("My Attendance", style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text("Already registered your face? Enter your roll number to view your attendance."),
              const SizedBox(height: 20),
              TextField(
                controller: _rollController,
                decoration: const InputDecoration(labelText: "Roll / ID number", border: OutlineInputBorder()),
              ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_errorText!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isLoading ? null : _lookup,
                child: _isLoading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("View my attendance"),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text("New here? Register your face once so teachers can mark you present."),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text("Register my face"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
