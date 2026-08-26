import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _teachingIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _coursesController = TextEditingController();
  final _apiService = ApiService();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _errorText;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final account = _isRegisterMode
          ? await _apiService.register(
              name: _nameController.text.trim(),
              teachingId: _teachingIdController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
              courses: _coursesController.text
                  .split(",")
                  .map((c) => c.trim())
                  .where((c) => c.isNotEmpty)
                  .toList(),
            )
          : await _apiService.login(_emailController.text.trim(), _passwordController.text);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("teacher_id", account.id);
      await prefs.setString("teacher_name", account.name);
      await prefs.setStringList("teacher_courses", account.courses);
      await prefs.setString("teacher_token", account.token);
      ApiService.setAuthToken(account.token);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(teacherId: account.id, teacherName: account.name, courses: account.courses),
        ),
      );
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
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 40),
                Text(
                  _isRegisterMode ? "Create teacher account" : "Teacher login",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                if (_isRegisterMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Full name", border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _teachingIdController,
                      decoration: const InputDecoration(labelText: "Teaching ID", border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _coursesController,
                      decoration: const InputDecoration(
                        labelText: "Courses (comma separated)",
                        hintText: "e.g. BSCS-5A, BSIT-3B",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.length < 6) ? "At least 6 characters" : null,
                  ),
                ),
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_errorText!, style: const TextStyle(color: Colors.red)),
                  ),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isRegisterMode ? "Register" : "Login"),
                ),
                TextButton(
                  onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
                  child: Text(_isRegisterMode ? "Already have an account? Login" : "New teacher? Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
