import 'package:firebase_core/firebase_core.dart';

/// Manually filled in from the Firebase Console (Project settings -> General -> Your apps).
/// apiKey / projectId / messagingSenderId / storageBucket are shared with every app in this
/// Firebase project (see backend/static/js/firebase-config.js for the web app's copy) - only
/// appId is specific to this Android app registration.
///
/// To get appId: Firebase Console -> Project settings -> General -> Your apps -> Add app ->
/// Android -> package name "com.attendancesystem.attendance_student_app" -> register (no need
/// to download google-services.json) -> copy the "App ID" shown for it.
class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyCG1q3_NUslk9-0l8Koyb2UgBHenyxAua0",
    appId: "1:341852806639:android:c60bec9fdb54137eb6aa1a",
    messagingSenderId: "341852806639",
    projectId: "attendence-37c8e",
    storageBucket: "attendence-37c8e.firebasestorage.app",
  );
}
