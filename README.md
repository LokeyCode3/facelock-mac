<div align="center">

<img src="assets/logo.svg" width="90" alt="FaceLock Mac Logo" style="margin-bottom: 20px; box-shadow: 0 10px 20px rgba(0,0,0,0.15); border-radius: 22px;"/>

# FaceLock Mac (Hey Mac)

**Your face is the password.**<br>
Unlock your Mac's lock screen, shield sensitive apps, and autofill website logins with a single look.

<br>

![macOS](https://img.shields.io/badge/macOS-14.0%2B-black?style=for-the-badge&logo=apple&logoColor=white)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-Native-0071E3?style=for-the-badge&logo=apple&logoColor=white)
![Privacy](https://img.shields.io/badge/100%25-On--Device-34C759?style=for-the-badge&logo=shield&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

</div>

<br>

---

## ⚡ 1-Click Terminal Install & Run

Copy and paste this single command into your macOS **Terminal** to clone, build, install into `/Applications`, and launch FaceLock immediately:

```bash
git clone https://github.com/LokeyCode3/facelock-mac.git && cd facelock-mac && ./scripts/build-app.sh && cp -R dist/HeyMac.app /Applications/ && open /Applications/HeyMac.app
```

> 💡 **Tip:** Once launched, click the **Hey Mac** icon in your macOS menu bar (top-right) and open **Settings** (`⌘,`) to set up your face profile.

---

## ✨ Features

FaceLock Mac bridges the gap between iPhone Face ID convenience and macOS desktop security.

* 🔑 **Face ID AutoFill & Password Vault:** Unlock and autofill website & app logins (e.g. Amazon, Google, GitHub) using face recognition. Features an encrypted local vault and a Spotlight-style quick picker palette (`⌥⌘F`).
* 🍏 **Apple Passwords Integration:** Directly import your exported passwords from the macOS Passwords app (`File → Export All Passwords… → Passwords.csv`) with 1 click.
* 🔓 **Zero-Touch Lock Screen Unlock:** Wake your Mac display, look at the camera, and you are instantly logged in without typing your password.
* 🛡️ **App-Level Shielding:** Protect sensitive apps (Messages, Notes, Mail, Slack). Unauthorized viewers see an obfuscated blur until verified by Face, Touch ID, or password.
* 🌫️ **Adaptive Privacy Blurring:** Choose your privacy obfuscation level—blur the entire display or strictly blur the locked application window.
* ⏱️ **Intelligent Relock Policies:** Configure relock rules per app (e.g. lock immediately on focus loss, or after 5–15 minutes of inactivity).
* 🏝️ **Dynamic Notch Island:** Fluid animated UI that drops down smoothly from the macOS notch to provide instant visual biometric feedback.
* 🔒 **Quit Protection:** Prevents unauthorized force-quitting or closing when protected applications are open.

---

## 🔒 Private & Secure by Design

Security and privacy are the core pillars of FaceLock Mac. The entire architecture operates on a local-only, zero-trust model:

* **100% On-Device Processing:** All facial recognition, feature extraction, and liveness classification run strictly on your Mac's Apple Neural Engine (ANE) via Apple Core ML. **No photos or biometric data ever leave your machine.**
* **Zero Photo Storage:** No photos of your face are ever saved to disk. FaceLock only stores a mathematical vector embedding of your facial structure, encrypted on disk with AES-GCM and protected by the **macOS Keychain**.
* **Anti-Spoofing & Liveness Detection:** Built-in neural network checks verify liveness in real-time to reject static photos and screens held in front of the webcam.

---

## 🛠️ Building & Development

### Prerequisites
* macOS Sonoma (14.0) or later
* Apple Silicon Mac (M1/M2/M3/M4)
* Swift 6.0+ / Xcode Command Line Tools

### Build via Terminal
```bash
# Clone the repository
git clone https://github.com/LokeyCode3/facelock-mac.git
cd facelock-mac

# Run test suite
swift test -Xswiftc -load-plugin-library -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib#TestingMacros

# Build release .app and DMG
./scripts/build-app.sh

# Launch the app
open dist/HeyMac.app
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
