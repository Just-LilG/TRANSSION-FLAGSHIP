# ⚡ Advanced System Control & WebUI Module

![Magisk](https://img.shields.io/badge/Magisk-Module-00AF9C?style=for-the-badge&logo=magisk)
![Version](https://img.shields.io/badge/Version-v1.0.0-blue?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Stable-success?style=for-the-badge)

## 📖 Overview
This is a comprehensive system modification module designed to inject custom assets, override default system properties, and provide a seamless web-based control interface. Built for performance and customizability, this module targets system-level optimization, allowing for advanced thermal control, display metric adjustments, and UI refinements without modifying the physical system partition.

## ✨ Core Features

*   **Local Web Dashboard (`/webroot`):** Hosts a lightweight local HTML/JS interface accessible directly from your device. Use it to toggle module features, monitor bridge events, and configure system variables on the fly.
*   **Performance & Prop Injection (`system.prop`):** Safely overrides standard system properties to optimize memory management and unlock high-framerate rendering (e.g., forcing 120 FPS / 144 FPS profiles in supported apps).
*   **Typography & Asset Override (`/system`):** Systemlessly replaces default UI assets, including custom `NotoColorEmoji.ttf` implementations for a cleaner, unified aesthetic across the OS.
*   **Automated Boot Scripts (`/common`):** Utilizes `post-fs-data.sh` and `service.sh` execution loops to ensure all modifications are applied cleanly during the boot sequence before the UI initializes.

## 📱 Compatibility

*   **Root Solutions:** Magisk (v24.0+), KernelSU, and APatch.
*   **Architecture:** ARM64 devices.
*   **OS/ROMs:** Fully tested and compatible with AOSP-based custom ROMs (e.g., Project Infinity, AxionOS, Lunaris AOSP) as well as heavily modified stock frameworks.

## ⚙️ Installation Instructions

1. Download the latest `.zip` release.
2. Open your root manager (Magisk / KernelSU / APatch).
3. Navigate to the **Modules** tab.
4. Select **Install from storage** and choose the downloaded `.zip` file.
5. Wait for the flashing process to complete and verify the installer log outputs.
6. **Reboot** your device to apply all system changes.

### Termux Installation / Update (Advanced)
If you prefer managing your modules via command-line, you can execute the flash directly via a root shell in Termux:
```bash
su -c magisk --install-module /sdcard/Download/YourModuleName.zip
