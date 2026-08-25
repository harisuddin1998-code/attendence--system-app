importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

// Keep this in sync with static/js/firebase-config.js (service workers can't import that file directly).
firebase.initializeApp({
  apiKey: "AIzaSyCG1q3_NUslk9-0l8Koyb2UgBHenyxAua0",
  authDomain: "attendence-37c8e.firebaseapp.com",
  projectId: "attendence-37c8e",
  storageBucket: "attendence-37c8e.firebasestorage.app",
  messagingSenderId: "341852806639",
  appId: "1:341852806639:web:3abf2b2e3b931cc7b6aa1a",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body, image } = payload.notification || {};
  const faceCropUrl = image || payload.data?.face_crop_url || undefined;

  self.registration.showNotification(title || "Attendance", {
    body: body || "You have a new attendance update.",
    icon: faceCropUrl || "/static/icon.png",
    image: faceCropUrl,
  });
});
