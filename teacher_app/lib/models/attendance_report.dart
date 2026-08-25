class DetectedFace {
  final String recordId;
  final String faceCropUrl;
  final String sourceImage;
  String? studentId;
  String? fullName;
  String? rollNumber;
  double? confidence;
  final String? closestGuessName;
  final String? closestGuessRollNumber;
  final double? closestGuessDistance;

  DetectedFace({
    required this.recordId,
    required this.faceCropUrl,
    required this.sourceImage,
    this.studentId,
    this.fullName,
    this.rollNumber,
    this.confidence,
    this.closestGuessName,
    this.closestGuessRollNumber,
    this.closestGuessDistance,
  });

  bool get isIdentified => studentId != null;

  factory DetectedFace.fromJson(Map<String, dynamic> json) => DetectedFace(
        recordId: json["record_id"],
        faceCropUrl: json["face_crop_url"] ?? "",
        sourceImage: json["source_image"] ?? "",
        studentId: json["student_id"],
        fullName: json["full_name"],
        rollNumber: json["roll_number"],
        confidence: (json["confidence"] as num?)?.toDouble(),
        closestGuessName: json["closest_guess_name"],
        closestGuessRollNumber: json["closest_guess_roll_number"],
        closestGuessDistance: (json["closest_guess_distance"] as num?)?.toDouble(),
      );
}

class AttendanceReport {
  final String sessionId;
  final String className;
  final String sessionDate;
  final int totalRegisteredStudents;
  final int totalFacesDetected;
  int totalStudentsRecognized;
  final List<DetectedFace> detectedFaces;

  AttendanceReport({
    required this.sessionId,
    required this.className,
    required this.sessionDate,
    required this.totalRegisteredStudents,
    required this.totalFacesDetected,
    required this.totalStudentsRecognized,
    required this.detectedFaces,
  });

  int get unrecognizedFacesCount => detectedFaces.where((f) => !f.isIdentified).length;

  factory AttendanceReport.fromJson(Map<String, dynamic> json) => AttendanceReport(
        sessionId: json["session_id"],
        className: json["class_name"],
        sessionDate: json["session_date"].toString(),
        totalRegisteredStudents: json["total_registered_students"],
        totalFacesDetected: json["total_faces_detected"],
        totalStudentsRecognized: json["total_students_recognized"],
        detectedFaces: (json["detected_faces"] as List)
            .map((e) => DetectedFace.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
