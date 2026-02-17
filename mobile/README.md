# mobile

A new Flutter project.

## Getting Started

## Install to Android via USB (uninstall old + install new)

From the repo root (PowerShell):

`./mobile_install_usb.ps1`

Options:

- Default behavior: updates in-place (no uninstall; keeps app data)
- Select build mode: `./mobile_install_usb.ps1 -Mode release` (or `debug`, `profile`)
- Clean rebuild: `./mobile_install_usb.ps1 -Clean`
- Force uninstall first (clears app data): `./mobile_install_usb.ps1 -UninstallFirst`
- Pick a specific device: `./mobile_install_usb.ps1 -DeviceId <adb-device-id>`
- Install a pre-built APK (skip build): `./mobile_install_usb.ps1 -ApkPath .\path\to\app-release.apk`
- Grant runtime permissions on install (Android 6+): `./mobile_install_usb.ps1 -GrantPermissions`
- Launch the app after install: `./mobile_install_usb.ps1 -Launch`

USB checklist (if device not detected / unauthorized):

- Enable Developer options → USB debugging
- Plug USB, unlock phone, accept “Allow USB debugging” (RSA fingerprint)
- Run `adb devices` and ensure the device state is `device` (not `unauthorized` / `offline`)

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
