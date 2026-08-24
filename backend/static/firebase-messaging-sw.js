importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

// Keep this in sync with static/js/firebase-config.js (service workers can't import that file directly).
firebase.initializeApp({
  apiKey: "REPLACE_ME",
  authDomain: "REPLACE_ME.firebaseapp.com",
  projectId: "REPLACE_ME",
  storageBucket: "REPLACE_ME.appspot.com",
  messagingSenderId: "REPLACE_ME",
  appId: "REPLACE_ME",
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
