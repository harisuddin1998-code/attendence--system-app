import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'dashboard_screen.dart';

const Map<String, String> _posePrompts = {
  "front": "Front (required) — look straight at the camera",
  "left": "Left profile (optional) — turn slightly left",
  "right": "Right profile (optional) — turn slightly right",
  "extra": "Extra angle (optional) — any other clear angle",
};

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _classController = TextEditingController();
  final _passwordController = TextEditingController();
  final _picker = ImagePicker();
  final _apiService = ApiService();

  final Map<String, File> _poses = {};
  bool _isSubmitting = false;
  String? _errorText;

  Future<void> _capture(String pose) async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90, preferredCameraDevice: CameraDevice.front);
    if (picked == null) return;
    setState(() => _poses[pose] = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_poses.containsKey("front")) {
      setState(() => _errorText = "Please capture the required front photo.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final student = await _apiService.register(
        fullName: _nameController.text.trim(),
        rollNumber: _rollController.text.trim(),
        className: _classController.text.trim(),
        password: _passwordController.text,
        poses: _poses,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("student_id", student.id);
      await prefs.setString("student_token", student.token);
      ApiService.setAuthToken(student.token);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => DashboardScreen(studentId: student.id)),
        (route) => false,
      );
    } catch (e) {
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _poseTile(String pose) {
    final file = _poses[pose];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: file == null
                  ? Container(color: Colors.grey.shade300, child: const Icon(Icons.face_retouching_natural, color: Colors.grey))
                  : Image.file(file, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_posePrompts[pose]!)),
          OutlinedButton(onPressed: () => _capture(pose), child: Text(file == null ? "Capture" : "Retake")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register my face")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Full name", border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rollController,
                  decoration: const InputDecoration(labelText: "Roll / ID number", border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _classController,
                  decoration: const InputDecoration(labelText: "Class name", hintText: "e.g. BSCS-5A", border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    hintText: "Used to log in and view your attendance later",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.length < 4) ? "At least 4 characters" : null,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Capture your face photos. The front photo is required; adding the others improves "
                  "recognition accuracy in group classroom photos.",
                ),
                const SizedBox(height: 16),
                ..._posePrompts.keys.map(_poseTile),
                if (_errorText != null)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_errorText!, style: const TextStyle(color: Colors.red))),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
