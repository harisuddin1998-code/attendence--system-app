class StudentProfile {
  final String id;
  final String fullName;
  final String rollNumber;
  final String className;
  final String photoUrl;

  StudentProfile({
    required this.id,
    required this.fullName,
    required this.rollNumber,
    required this.className,
    required this.photoUrl,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        id: json["id"],
        fullName: json["full_name"],
        rollNumber: json["roll_number"],
        className: json["class_name"],
        photoUrl: json["photo_url"] ?? "",
      );
}

class AttendanceHistoryEntry {
  final String faceCropUrl;
  final double? confidence;
  final DateTime markedAt;
  final String className;
  final String sessionDate;

  AttendanceHistoryEntry({
    required this.faceCropUrl,
    required this.confidence,
    required this.markedAt,
    required this.className,
    required this.sessionDate,
  });

  factory AttendanceHistoryEntry.fromJson(Map<String, dynamic> json) {
    final session = json["attendance_sessions"] as Map<String, dynamic>? ?? {};
    return AttendanceHistoryEntry(
      faceCropUrl: json["face_crop_url"] ?? "",
      confidence: (json["confidence"] as num?)?.toDouble(),
      markedAt: DateTime.parse(json["marked_at"]),
      className: session["class_name"] ?? "",
      sessionDate: session["session_date"]?.toString() ?? "",
    );
  }
}
