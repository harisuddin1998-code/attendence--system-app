// Fill these in from Firebase Console -> Project settings -> General -> Your apps -> Web app.
// This is the same Firebase project whose service-account JSON the backend uses to send pushes.
const FIREBASE_CONFIG = {
  apiKey: "AIzaSyCG1q3_NUslk9-0l8Koyb2UgBHenyxAua0",
  authDomain: "attendence-37c8e.firebaseapp.com",
  projectId: "attendence-37c8e",
  storageBucket: "attendence-37c8e.firebasestorage.app",
  messagingSenderId: "341852806639",
  appId: "1:341852806639:web:3abf2b2e3b931cc7b6aa1a",
  measurementId: "G-D0VMRFC2CJ",
};

// Firebase Console -> Project settings -> Cloud Messaging -> Web Push certificates.
const FIREBASE_VAPID_KEY = "BFPgrY33tI73sBYzljD7dtO6xD0cW-3rtMFLf8rsCA8WH-LHCGzakK5L35lCcOUPaHQXrj7600O0gYUpUrLoyNU";

firebase.initializeApp(FIREBASE_CONFIG);
