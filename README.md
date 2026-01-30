# Club Blackout App

This is the host companion app for the Club Blackout social deduction game.
Built with Flutter and Material 3.

## Project Structure

*   `lib/models`: Data models for Role and Player.
*   `lib/logic`: Game Engine and State management.
*   `lib/data`: JSON handling and repositories.
*   `lib/ui`: Screens and Widgets.
*   `assets`: Contains images, icons, and data.

## Features

*   **Role Management**: Roles loaded from `assets/data/roles.json`.
*   **Game Loop**: Lobby -> Setup -> Night -> Day phases.
*   **Dynamic Theme**: Neon colors based on role types.

## How to Run

1.  Ensure you have Flutter installed.
2.  Run `flutter pub get`.
3.  Run `flutter run`.

## Android Build (Gradle)

This project uses the Gradle wrapper under `android/`.

### Verify the Gradle version

- Check the wrapper version: `cd android` then run `./gradlew.bat --version`.
- The wrapper download is configured in `android/gradle/wrapper/gradle-wrapper.properties`.

### If VS Code reports the wrong Gradle version

Sometimes VS Code/Java/Gradle tooling can show a stale error like “Current version is 8.9” even when the wrapper is already on the correct version.

Try, in order:

1. Run **Developer: Reload Window**.
2. Run **Java: Clean Java Language Server Workspace** (then reload).
3. Run **Gradle: Refresh Gradle Project**.
4. If it still persists, stop daemons + clear the Android project cache:
	- `cd android; ./gradlew.bat --stop`
	- delete `android/.gradle/`
	- run `cd android; ./gradlew.bat :app:tasks`

## Customization

To modify roles, edit `assets/data/roles.json`.
To change game logic, modify `lib/logic/game_engine.dart`.

## Local Verification

From project root:

- `flutter analyze`
- `flutter test -r expanded`
- `flutter run`

## Club Blackout (Flutter)

### Local setup
- `flutter pub get`
- `flutter analyze`
- `flutter test -r expanded`
- `flutter run`

### Build APK
From the project root:

- `flutter pub get`
- `flutter analyze`
- `flutter build apk --debug`
- `flutter build apk --release`

Outputs:
- `build/app/outputs/flutter-apk/app-debug.apk`
- `build/app/outputs/flutter-apk/app-release.apk`

### Notes
- Night actions are recorded by script-step id and canonicalized by the engine before resolution.

## Can we extract `game_engine.dart` from a release APK?

Not as source.

In a Flutter **release** build, Dart is compiled AOT into native code (typically `lib/<abi>/libapp.so`). The APK will not contain `lib/logic/game_engine.dart` text.

### What you *can* extract from the APK
- **Android resources/manifest/assets**: yes (e.g. with `apktool`).
- **Java/Kotlin code**: yes (e.g. with `jadx`), if present.
- **Dart game logic**: only as compiled native code; recovery to readable Dart is generally incomplete and unreliable.

### Best practice (if this is your app)
- Keep `game_engine.dart` in version control (Git) and treat the APK as an artifact.
- For release debugging/symbolication, build with symbols:
  - `flutter build apk --release --split-debug-info=./symbols`
  - (optional) `--obfuscate` (makes reverse engineering harder, but you must keep the split-debug-info output)
- Use the generated symbols to symbolicate crash stacks (rather than trying to reconstruct source from the APK).

## Device debugging (ADB)

Prereqs:
- `adb` on PATH
- Device connected with USB debugging enabled
- `adb devices` shows a device in `device` state

Run:
- Analyzer only: `powershell -ExecutionPolicy Bypass -File .\analyze.ps1 -AnalyzeOnly`
- ADB capture only: `powershell -ExecutionPolicy Bypass -File .\analyze.ps1 -AdbOnly -ClearLogcat -Minutes 3 -Package "<your.package.id>"`

When a bug happens, share `logs\logcat_*.txt` around the exception.
