# Adey

Adey is a Flutter daycare management app for keeping track of children, attendance, billing, and day-to-day operations. It stores data locally and can synchronize mobile devices with a desktop installation over a local network.

## Features

- Register children and manage child and guardian information.
- Record attendance, fees, payments, and expenses.
- View dashboards and reports, and generate or print documents.
- Display dates using the Ethiopian or Gregorian calendar.
- Pair mobile devices with a desktop installation using a QR code or pairing details, then synchronize over the local network.
- Use the mobile app on Android and iOS, and the desktop app on Windows, macOS, and Linux.

## Requirements

- Flutter with Dart 3.3 or later.
- The platform toolchain required by Flutter for your target device (for example, Android Studio for Android or Xcode for iOS and macOS).

## Getting started

From the project root:

```sh
flutter pub get
flutter run
```

To choose a specific target, list available devices with `flutter devices`, then pass its device ID to `flutter run -d <device-id>`. For example, on Windows:

```sh
flutter run -d windows
```

## Desktop and mobile synchronization

The desktop app runs the sync server, and mobile apps connect to it over the same local network. Open **Settings** on desktop to enable the server and show its pairing QR code; on mobile, scan the code from **Settings** to pair. The server uses port `8080` by default.

## Data and privacy

App records are stored in a local SQLite database. Daycare records can contain sensitive information about children and guardians; protect devices and backups that contain this data. Do not commit databases, credentials, signing keys, or other private data to the repository.

## Development checks

```sh
flutter analyze
flutter test
```

## License

No license has been specified yet. Add a `LICENSE` file before distributing the project publicly.
