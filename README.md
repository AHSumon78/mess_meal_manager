# Mess Meal Manager

A Flutter app for managing shared mess meals, member payments, and daily expenses. Keep records locally, calculate meal bills, share PDF reports, and back up the database to Google Drive.

## Features

- **Member management:** Maintain members and view individual meal and payment records.
- **Meal tracking:** Record breakfast, lunch, and dinner counts by member and date.
- **Manager ledger:** Track expenses and member payments.
- **Flexible billing:** Choose fixed meal prices or expense-based billing with configurable meal weights.
- **Dashboard:** Review meal costs and financial summaries.
- **PDF reports:** Generate and share individual member and monthly reports.
- **Google Drive backup:** Back up and restore the local database from Settings.
- **Local storage:** Store members, meals, expenses, and payments in SQLite, with billing preferences saved separately using SharedPreferences.

## Getting started

### Requirements

- Flutter SDK with Dart compatible with `^3.8.1`, as specified in `pubspec.yaml`.
- Android SDK and an Android emulator or connected device for Android development.
- macOS with Xcode for iOS development.

### Run locally

```sh
git clone https://github.com/AHSumon78/mess_meal_manager.git
cd mess_meal_manager
flutter pub get
flutter run
```

If multiple devices are connected, use `flutter devices` and then `flutter run -d <device-id>`.

### Build an Android APK

```sh
flutter build apk --release
```

The generated APK is located at `build/app/outputs/flutter-apk/app-release.apk`.

The repository includes desktop and web runner folders, but their presence does not establish platform support. The current implementation uses `dart:io`, SQLite, and native sign-in integrations; verify compatibility before targeting additional platforms.

## Using the app

1. Open **Members** and add the people in your mess.
2. Open **Settings** and select a billing mode, meal prices, or meal weights.
3. Use **Add Meals** to enter breakfast, lunch, and dinner counts.
4. Record expenses and member payments in **Ledger**.
5. Review summaries on **Home**, or open member details and share PDF reports.
6. Sign in from **Settings** to use Google Drive backup and restore.

## Billing modes

### Fixed rate

Each member's meal cost uses the configured price for each meal type:

```text
Meal cost = breakfast count × breakfast rate
          + lunch count × lunch rate
          + dinner count × dinner rate
```

Default rates are 10 for breakfast, 40 for lunch, and 40 for dinner.

### Expense based

Meal weights determine each member's share of a day's recorded expenses:

```text
Weighted meals = breakfast count × breakfast weight
               + lunch count × lunch weight
               + dinner count × dinner weight

Daily member cost = daily expenses × member's daily weighted meals
                   / all members' daily weighted meals
```

Default weights are 0.5 for breakfast and 1.0 each for lunch and dinner. The date-based billing calculation skips days with no positive total weighted meals. Period costs sum the daily costs.

## Google Drive backup

The app uses Google Sign-In and the Drive API with the `drive.file` scope. A working Google OAuth configuration for the target platform is required for this integration.

Backups are stored as `meal_manager_backup.db` inside a `MessMealManagerApp` folder in the signed-in account's Google Drive. Creating another backup updates the existing file. Restore replaces the local database, and the app asks you to restart afterward.

Billing settings are stored separately in SharedPreferences and are not included in the database backup.

## Project structure

```text
lib/
  main.dart                 App entry point and navigation
  models/                   Members, meals, expenses, payments, and settings
  screens/                  Dashboard, meal entry, ledger, members, and settings
  services/                 SQLite storage, billing, preferences, and Drive access
assets/
  fonts/                    Hind Siliguri fonts used in reports
  icon.png                  App icon source
test/
  widget_test.dart          Starter widget test
```

## Main packages

| Purpose | Packages |
| --- | --- |
| Local data | `sqflite`, `path`, `shared_preferences` |
| Google Drive integration | `google_sign_in`, `googleapis` |
| Reports and sharing | `pdf`, `share_plus`, `path_provider` |
| Formatting and identifiers | `intl`, `uuid` |

## Development checks

```sh
flutter analyze
flutter test
```

The existing widget test is the default Flutter counter test and has not been adapted to this app. It should be replaced with relevant app tests before treating the test suite as validation of meal management features.
