import 'package:flutter/material.dart';

import '../models/attendance_report.dart';

class ReportScreen extends StatelessWidget {
  final AttendanceReport report;

  const ReportScreen({super.key, required this.report});

  Widget _statChip(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                _statChip("Unmatched", "${report.unrecognizedFacesCount}"),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: report.recognized.isEmpty
                ? const Center(child: Text("No registered students were recognized in these photos."))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: report.recognized.length,
                    itemBuilder: (context, index) {
                      final student = report.recognized[index];
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: student.faceCropUrl.isEmpty
                                  ? Container(color: Colors.grey.shade300)
                                  : Image.network(student.faceCropUrl, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(student.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                          Text(student.rollNumber, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
