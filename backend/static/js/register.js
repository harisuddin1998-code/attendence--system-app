const video = document.getElementById("video");
const canvas = document.getElementById("canvas");
const captureBtn = document.getElementById("capture-btn");
const posePrompt = document.getElementById("pose-prompt");
const poseThumbs = document.getElementById("pose-thumbs");
const extraPoseActions = document.getElementById("extra-pose-actions");
const submitBtn = document.getElementById("submit-btn");
const statusMsg = document.getElementById("status-msg");
const form = document.getElementById("register-form");

const POSE_PROMPTS = {
  front: "Look straight at the camera",
  left: "Turn your head slightly to show your left profile",
  right: "Turn your head slightly to show your right profile",
  extra: "Any other clear angle (e.g. slightly tilted up/down)",
};

const capturedBlobs = { front: null, left: null, right: null, extra: null };
let activePose = "front";

async function startCamera() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "user" } });
    video.srcObject = stream;
  } catch (err) {
    setStatus("Camera access denied. Please allow camera permission to register your face.", true);
  }
}

function setStatus(message, isError = false) {
  statusMsg.textContent = message;
  statusMsg.className = "status " + (isError ? "error" : "success");
}

function renderThumbs() {
  poseThumbs.innerHTML = "";
  for (const pose of ["front", "left", "right", "extra"]) {
    if (!capturedBlobs[pose]) continue;
    const wrapper = document.createElement("div");
    wrapper.className = "pose-thumb";
    const img = document.createElement("img");
    img.src = URL.createObjectURL(capturedBlobs[pose]);
    const label = document.createElement("span");
    label.textContent = pose;
    wrapper.append(img, label);
    poseThumbs.appendChild(wrapper);
  }
}

function refreshExtraPoseButtons() {
  for (const btn of extraPoseActions.querySelectorAll("button")) {
    btn.disabled = !!capturedBlobs[btn.dataset.pose];
  }
}

function goToCaptureMode(pose) {
  activePose = pose;
  posePrompt.textContent = POSE_PROMPTS[pose];
  video.classList.remove("hidden");
  captureBtn.classList.remove("hidden");
  extraPoseActions.classList.add("hidden");
}

captureBtn.addEventListener("click", () => {
  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;
  canvas.getContext("2d").drawImage(video, 0, 0);

  canvas.toBlob((blob) => {
    capturedBlobs[activePose] = blob;
    renderThumbs();
    refreshExtraPoseButtons();
    submitBtn.disabled = !capturedBlobs.front;

    video.classList.add("hidden");
    captureBtn.classList.add("hidden");
    extraPoseActions.classList.remove("hidden");
    posePrompt.textContent = capturedBlobs.front
      ? "Front photo captured. Add more angles for better accuracy, or register now."
      : "Please capture the required front photo.";
  }, "image/jpeg", 0.92);
});

extraPoseActions.addEventListener("click", (event) => {
  const pose = event.target.dataset.pose;
  if (pose) goToCaptureMode(pose);
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!capturedBlobs.front) {
    setStatus("Please capture the required front photo first.", true);
    return;
  }

  submitBtn.disabled = true;
  setStatus("Registering...");

  const formData = new FormData(form);
  for (const pose of ["front", "left", "right", "extra"]) {
    if (capturedBlobs[pose]) {
      formData.append(`photo_${pose}`, capturedBlobs[pose], `${pose}.jpg`);
    }
  }

  try {
    const response = await fetch("/api/students/register", { method: "POST", body: formData });
    const data = await response.json();

    if (!response.ok) {
      setStatus(data.error || "Registration failed.", true);
      submitBtn.disabled = false;
      return;
    }

    setStatus(`Registered successfully as ${data.full_name} (${data.poses_registered} photo(s) saved). You can now check your attendance on the dashboard.`);
    form.reset();
    for (const pose of Object.keys(capturedBlobs)) capturedBlobs[pose] = null;
    renderThumbs();
    refreshExtraPoseButtons();
    submitBtn.disabled = true;
    goToCaptureMode("front");
  } catch (err) {
    setStatus("Network error. Please try again.", true);
    submitBtn.disabled = false;
  }
});

startCamera();
