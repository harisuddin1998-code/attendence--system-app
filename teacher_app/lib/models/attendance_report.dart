class RecognizedStudent {
  final String studentId;
  final String fullName;
  final String rollNumber;
  final double confidence;
  final String faceCropUrl;
  final String sourceImage;

  RecognizedStudent({
    required this.studentId,
    required this.fullName,
    required this.rollNumber,
    required this.confidence,
    required this.faceCropUrl,
    required this.sourceImage,
  });

  factory RecognizedStudent.fromJson(Map<String, dynamic> json) => RecognizedStudent(
        studentId: json["student_id"],
        fullName: json["full_name"],
        rollNumber: json["roll_number"],
        confidence: (json["confidence"] as num).toDouble(),
        faceCropUrl: json["face_crop_url"] ?? "",
        sourceImage: json["source_image"] ?? "",
      );
}

class AttendanceReport {
  final String sessionId;
  final String className;
  final String sessionDate;
  final int totalRegisteredStudents;
  final int totalFacesDetected;
  final int totalStudentsRecognized;
  final int unrecognizedFacesCount;
  final List<RecognizedStudent> recognized;

  AttendanceReport({
    required this.sessionId,
    required this.className,
    required this.sessionDate,
    required this.totalRegisteredStudents,
    required this.totalFacesDetected,
    required this.totalStudentsRecognized,
    required this.unrecognizedFacesCount,
    required this.recognized,
  });

  factory AttendanceReport.fromJson(Map<String, dynamic> json) => AttendanceReport(
        sessionId: json["session_id"],
        className: json["class_name"],
        sessionDate: json["session_date"].toString(),
        totalRegisteredStudents: json["total_registered_students"],
        totalFacesDetected: json["total_faces_detected"],
        totalStudentsRecognized: json["total_students_recognized"],
        unrecognizedFacesCount: json["unrecognized_faces_count"],
        recognized: (json["recognized"] as List)
            .map((e) => RecognizedStudent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
