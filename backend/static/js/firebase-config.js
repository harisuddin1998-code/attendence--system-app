// Fill these in from Firebase Console -> Project settings -> General -> Your apps -> Web app.
// This is the same Firebase project whose service-account JSON the backend uses to send pushes.
const FIREBASE_CONFIG = {
  apiKey: "REPLACE_ME",
  authDomain: "REPLACE_ME.firebaseapp.com",
  projectId: "REPLACE_ME",
  storageBucket: "REPLACE_ME.appspot.com",
  messagingSenderId: "REPLACE_ME",
  appId: "REPLACE_ME",
};

// Firebase Console -> Project settings -> Cloud Messaging -> Web Push certificates.
const FIREBASE_VAPID_KEY = "REPLACE_ME";

firebase.initializeApp(FIREBASE_CONFIG);
