import 'package:flutter/material.dart';

import '../models/attendance_report.dart';
import '../services/api_service.dart';

class ReportScreen extends StatefulWidget {
  final AttendanceReport report;

  const ReportScreen({super.key, required this.report});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _apiService = ApiService();

  Widget _statChip(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Future<void> _identify(DetectedFace face) async {
    final rollController = TextEditingController(text: face.closestGuessRollNumber ?? "");

    final rollNumber = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Who is this?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 120,
                  child: Image.network(face.faceCropUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              if (face.closestGuessName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Closest guess: ${face.closestGuessName} (${face.closestGuessRollNumber})",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              TextField(
                controller: rollController,
                decoration: const InputDecoration(labelText: "Roll / ID number", border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(rollController.text.trim()),
                child: const Text("Confirm"),
              ),
            ],
          ),
        );
      },
    );

    if (rollNumber == null || rollNumber.isEmpty || !mounted) return;

    try {
      final identified = await _apiService.identifyFace(recordId: face.recordId, rollNumber: rollNumber);
      setState(() {
        face.studentId = identified.studentId;
        face.fullName = identified.fullName;
        face.rollNumber = identified.rollNumber;
        widget.report.totalStudentsRecognized += 1;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return Scaffold(
      appBar: AppBar(title: Text("${report.className} — ${report.sessionDate}")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statChip("Registered", "${report.totalRegisteredStudents}"),
                _statChip("Faces detected", "${report.totalFacesDetected}"),
                _statChip("Present", "${report.totalStudentsRecognized}"),
                _statChip("Unknown", "${report.unrecognizedFacesCount}"),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: report.detectedFaces.isEmpty
                ? const Center(child: Text("No faces were detected in these photos."))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: report.detectedFaces.length,
                    itemBuilder: (context, index) {
                      final face = report.detectedFaces[index];
                      return GestureDetector(
                        onTap: face.isIdentified ? null : () => _identify(face),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: face.faceCropUrl.isEmpty
                                        ? Container(color: Colors.grey.shade300)
                                        : Image.network(face.faceCropUrl, fit: BoxFit.cover),
                                  ),
                                ),
                                if (!face.isIdentified)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade700,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.edit, size: 12, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              face.fullName ?? "Unknown",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: face.isIdentified ? null : Colors.orange.shade700,
                                fontWeight: face.isIdentified ? null : FontWeight.bold,
                              ),
                            ),
                            Text(
                              face.rollNumber ?? (face.closestGuessName != null ? "Tap: ${face.closestGuessName}?" : "Tap to identify"),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
