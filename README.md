# nine_mens_morris

# Nine Men's Morris - Flutter Game

A modern implementation of the classic Nine Men's Morris board game built with Flutter for cross-platform mobile and desktop support.

## Game Overview

Nine Men's Morris is a strategy board game for two players dating back to the Roman Empire. Players take turns placing and moving pieces to form "mills" (three pieces in a row) to capture opponent pieces.

## Features

- ✅ Classic Nine Men's Morris gameplay with authentic rules
- ✅ Cross-platform support (Windows, macOS, Linux, Android, iOS)
- ✅ Responsive design for mobile and desktop
- ✅ Three game phases: Placing, Moving, and Flying
- ✅ Visual feedback for valid moves and piece selection
- ✅ Mill detection and piece capture mechanics
- ✅ Game state tracking and win condition detection
- ✅ Clean, intuitive user interface

## How to Play

### Objective
Reduce your opponent to 2 pieces or block all their moves.

### Game Phases

1. **Placing Phase**: Take turns placing your 9 pieces on the board
2. **Moving Phase**: Move pieces to adjacent empty positions
3. **Flying Phase**: When you have 3 pieces left, move to any empty position

### Mills
Form a line of 3 pieces horizontally or vertically to capture an opponent's piece. You cannot capture pieces that are part of a mill unless all opponent pieces are in mills.

## Running the Game

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK
- Platform-specific requirements:
  - Windows: Visual Studio with C++ support
  - macOS: Xcode
  - Linux: GTK development libraries
  - Mobile: Android Studio/Xcode for respective platforms

### Quick Start

1. **Clone and setup:**
   ```bash
   git clone <your-repo>
   cd nine_mens_morris
   flutter pub get
   ```

2. **Run on different platforms:**
   
   **Desktop (Windows):**
   ```bash
   flutter run -d windows
   ```
   
   **Desktop (macOS):**
   ```bash
   flutter run -d macos
   ```
   
   **Desktop (Linux):**
   ```bash
   flutter run -d linux
   ```
   
   **Mobile (Android):**
   ```bash
   flutter run -d android
   ```
   
   **Mobile (iOS):**
   ```bash
   flutter run -d ios
   ```
   
   **Or simply:**
   ```bash
   flutter run
   ```
   (Flutter will prompt you to choose an available device)

3. **Build for release:**
   ```bash
   flutter build windows
   flutter build apk
   flutter build ios
   ```

## Development

### Project Structure
```
lib/
├── models/          # Game logic and data models
│   ├── game_model.dart
│   ├── piece.dart
│   └── position.dart
├── screens/         # UI screens
│   ├── home_screen.dart
│   └── game_screen.dart
├── widgets/         # Reusable UI components
│   ├── game_board.dart
│   ├── game_status.dart
│   └── piece_counter.dart
└── main.dart        # App entry point
```

### VS Code Tasks
The project includes pre-configured VS Code tasks:
- **Flutter Run**: Launch the app in debug mode
- Use `Ctrl+Shift+P` → "Tasks: Run Task" → "Flutter Run"

### Development Commands
```bash
# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Run tests
flutter test

# Format code
flutter format .

# Check for outdated packages
flutter pub outdated
```

## Game Architecture

The game follows clean architecture principles:

- **Models**: Pure Dart classes handling game logic
- **Widgets**: Reusable UI components
- **Screens**: Full-page views coordinating multiple widgets

### Key Components

- `GameModel`: Core game state and rule enforcement
- `GameBoard`: Custom-painted interactive board
- `Position`: Board position representation
- `Piece`: Game piece data structure

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow Flutter/Dart coding conventions
4. Add tests for new functionality
5. Submit a pull request

## License

This project is open source. See LICENSE file for details.

## Technical Notes

- Built with Flutter 3.x
- Uses CustomPainter for game board rendering
- Responsive design supports multiple screen sizes
- Touch and mouse input supported
- State management using StatefulWidget

---

**Enjoy playing Nine Men's Morris!** 🎲
