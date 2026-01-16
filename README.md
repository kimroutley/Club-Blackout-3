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

## Customization

To modify roles, edit `assets/data/roles.json`.
To change game logic, modify `lib/logic/game_engine.dart`.
