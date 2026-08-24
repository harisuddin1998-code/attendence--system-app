const lookupForm = document.getElementById("lookup-form");
const profileEl = document.getElementById("profile");
const statusMsg = document.getElementById("status-msg");
const notifStatus = document.getElementById("notif-status");
const historyList = document.getElementById("history-list");

function setStatus(message, isError = false) {
  statusMsg.textContent = message;
  statusMsg.className = "status " + (isError ? "error" : "success");
}

async function registerForPush(studentId) {
  if (!("Notification" in window) || !("serviceWorker" in navigator)) {
    notifStatus.textContent = "Push notifications are not supported in this browser.";
    return;
  }

  try {
    const permission = await Notification.requestPermission();
    if (permission !== "granted") {
      notifStatus.textContent = "Notifications are off. Enable them in your browser to get attendance alerts.";
      return;
    }

    const registration = await navigator.serviceWorker.register("/firebase-messaging-sw.js");
    const messaging = firebase.messaging();
    const token = await messaging.getToken({ vapidKey: FIREBASE_VAPID_KEY, serviceWorkerRegistration: registration });

    if (token) {
      await fetch(`/api/students/${studentId}/fcm-token`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token }),
      });
      notifStatus.textContent = "Push notifications enabled.";
    }
  } catch (err) {
    notifStatus.textContent = "Could not enable push notifications.";
  }
}

async function loadHistory(studentId) {
  const response = await fetch(`/api/students/${studentId}/attendance`);
  const records = await response.json();

  historyList.innerHTML = "";
  if (records.length === 0) {
    historyList.innerHTML = "<li>No attendance recorded yet.</li>";
    return;
  }

  for (const record of records) {
    const li = document.createElement("li");
    const session = record.attendance_sessions || {};
    li.innerHTML = `
      <img src="${record.face_crop_url || ""}" alt="" />
      <div>
        <div>${session.class_name || ""} &middot; ${session.session_date || ""}</div>
        <div class="hint">Marked present at ${new Date(record.marked_at).toLocaleString()}</div>
      </div>
    `;
    historyList.appendChild(li);
  }
}

lookupForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const rollNumber = new FormData(lookupForm).get("roll_number");
  setStatus("Looking up...");

  try {
    const response = await fetch(`/api/students/lookup?roll_number=${encodeURIComponent(rollNumber)}`);
    const student = await response.json();

    if (!response.ok) {
      setStatus(student.error || "Student not found.", true);
      profileEl.classList.add("hidden");
      return;
    }

    document.getElementById("profile-photo").src = student.photo_url || "";
    document.getElementById("profile-name").textContent = student.full_name;
    document.getElementById("profile-class").textContent = student.class_name;
    profileEl.classList.remove("hidden");
    setStatus("");

    await registerForPush(student.id);
    await loadHistory(student.id);
  } catch (err) {
    setStatus("Network error. Please try again.", true);
  }
});
