import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'capture_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final List<String> courses;

  const HomeScreen({super.key, required this.teacherId, required this.teacherName, this.courses = const []});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _classController = TextEditingController();
  String? _selectedCourse;

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ApiService.setAuthToken(null);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _startAttendance() {
    final className = widget.courses.isNotEmpty ? (_selectedCourse ?? "") : _classController.text.trim();
    if (className.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(teacherId: widget.teacherId, className: className),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStart = widget.courses.isNotEmpty ? _selectedCourse != null : true;

    return Scaffold(
      appBar: AppBar(
        title: Text("Hi, ${widget.teacherName}"),
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text("Mark attendance", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              "Pick the class, then capture the left half and right half of the classroom. "
              "Faces will be recognized automatically against registered students.",
            ),
            const SizedBox(height: 20),
            if (widget.courses.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedCourse,
                decoration: const InputDecoration(labelText: "Class / course", border: OutlineInputBorder()),
                items: widget.courses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (value) => setState(() => _selectedCourse = value),
              )
            else
              TextField(
                controller: _classController,
                decoration: const InputDecoration(
                  labelText: "Class name",
                  hintText: "e.g. BSCS-5A",
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: canStart ? _startAttendance : null,
              icon: const Icon(Icons.camera_alt),
              label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("Start attendance capture")),
            ),
          ],
        ),
      ),
    );
  }
}
