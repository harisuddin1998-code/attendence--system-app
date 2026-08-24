import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'report_screen.dart';

class CaptureScreen extends StatefulWidget {
  final String teacherId;
  final String className;

  const CaptureScreen({super.key, required this.teacherId, required this.className});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  final _apiService = ApiService();

  File? _leftImage;
  File? _rightImage;
  bool _isSubmitting = false;
  String? _errorText;

  Future<void> _capture(bool isLeft) async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked == null) return;
    setState(() {
      if (isLeft) {
        _leftImage = File(picked.path);
      } else {
        _rightImage = File(picked.path);
      }
    });
  }

  Future<void> _submit() async {
    if (_leftImage == null || _rightImage == null) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final report = await _apiService.markAttendance(
        teacherId: widget.teacherId,
        className: widget.className,
        leftImage: _leftImage!,
        rightImage: _rightImage!,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ReportScreen(report: report)));
    } catch (e) {
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _slot(String label, File? file, VoidCallback onCapture) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
              child: file == null
                  ? const Center(child: Icon(Icons.camera_alt_outlined, size: 36, color: Colors.grey))
                  : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(file, fit: BoxFit.cover)),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onCapture, child: Text(file == null ? "Capture" : "Retake")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _leftImage != null && _rightImage != null && !_isSubmitting;

    return Scaffold(
      appBar: AppBar(title: Text(widget.className)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Stand at the front of the class. Capture the left half of the room, then the right half, "
              "so every student is covered across the two photos.",
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _slot("Left side", _leftImage, () => _capture(true)),
                const SizedBox(width: 16),
                _slot("Right side", _rightImage, () => _capture(false)),
              ],
            ),
            const SizedBox(height: 24),
            if (_errorText != null)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_errorText!, style: const TextStyle(color: Colors.red))),
            FilledButton.icon(
              onPressed: canSubmit ? _submit : null,
              icon: _isSubmitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_isSubmitting ? "Recognizing faces..." : "Submit & mark attendance"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
