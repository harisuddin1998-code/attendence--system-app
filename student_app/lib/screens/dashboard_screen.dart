import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_models.dart';
import '../services/api_service.dart';
import 'welcome_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String studentId;

  const DashboardScreen({super.key, required this.studentId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _apiService = ApiService();
  List<AttendanceHistoryEntry> _history = [];
  bool _isLoading = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final history = await _apiService.getAttendanceHistory(widget.studentId);
      setState(() => _history = history);
    } catch (e) {
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Attendance"),
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout))],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorText != null
                ? ListView(children: [const SizedBox(height: 80), Center(child: Text(_errorText!))])
                : _history.isEmpty
                    ? ListView(children: const [SizedBox(height: 80), Center(child: Text("No attendance recorded yet."))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final entry = _history[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: entry.faceCropUrl.isNotEmpty ? NetworkImage(entry.faceCropUrl) : null,
                              child: entry.faceCropUrl.isEmpty ? const Icon(Icons.person) : null,
                            ),
                            title: Text("${entry.className} — ${entry.sessionDate}"),
                            subtitle: Text("Marked present at ${entry.markedAt.toLocal()}"),
                          );
                        },
                      ),
      ),
    );
  }
}
