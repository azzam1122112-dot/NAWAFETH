# mobile

A new Flutter project.

## Getting Started

## Install to Android via USB (uninstall old + install new)

From the repo root (PowerShell):

`./mobile_install_usb.ps1`

Options:

- Select build mode: `./mobile_install_usb.ps1 -Mode release` (or `debug`, `profile`)
- Pick a specific device: `./mobile_install_usb.ps1 -DeviceId <adb-device-id>`
- Override package name (if you changed `applicationId`): `./mobile_install_usb.ps1 -PackageName com.nawafeth.app`

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
