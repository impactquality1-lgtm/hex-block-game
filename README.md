# Hex Blocks

A hex-grid block puzzle game built with Flutter. Drag pieces from the tray
onto the hexagon board (or tap a piece, then tap a cell). Fill a full line in
any of the three hex directions and it clears. Score for every cell placed,
100 points per line cleared, plus a combo bonus for clearing 2+ lines at once.
The game ends when none of your three tray pieces fits anywhere.

Board: a hexagon of radius 4, 61 cells. No extra packages, no server, no
accounts — the whole game is `lib/main.dart` (UI) and `lib/hex.dart`
(board math and rules).

## Run it on your Mac

Prerequisites: the Flutter SDK installed and on your PATH. Check with:

```sh
flutter --version
```

If Flutter is not installed yet, install it from https://flutter.dev
and follow its macOS setup, then restart your terminal.

Then, from this folder:

```sh
flutter pub get
flutter run
```

Pick a target when prompted: macOS desktop is the quickest first run
(`flutter run -d macos`), or an iOS simulator / a connected Android device
for a phone-sized test. The layout is portrait-phone shaped, so a phone
simulator shows it best.

## Files

- `pubspec.yaml` — project definition, no third-party dependencies
- `lib/main.dart` — UI: board, tray, drag + tap placement, scoring, game over
- `lib/hex.dart` — hex grid math (axial coordinates), pieces, line clearing
- `analysis_options.yaml` — lint rules

## Things to try next

- Tune the piece pool in `lib/hex.dart` (`allPieces`) if the game feels
  too easy or too hard.
- Change the board size by changing `HexGame.radius` (5 = 91 cells).
- Add sound, a daily puzzle, or saved best score — all marked as easy
  follow-ups, not in this first version.
