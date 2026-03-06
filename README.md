# Sound_hub — Flutter Windows App

A Windows desktop soundboard application converted from the original React/TypeScript web app.

## Features

- Import and play audio files (MP3, WAV, OGG, FLAC, AAC, M4A)
- Drag & drop files directly onto the window
- Mark sounds as favorites
- Per-sound volume control
- Custom keyboard shortcuts per sound
- Category filtering
- Search sounds by name or category
- Drag-to-reorder sounds in the list
- Dark/light mode
- Simultaneous playback toggle
- Persistent storage (SQLite + local file copies)

## Setup & Build

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install/windows) (stable channel, ≥ 3.0)
- Windows 10 or later (64-bit)
- Visual Studio 2022 with "Desktop development with C++" workload

### Steps

1. **Create a new Flutter Windows project** and replace the `lib/` folder and `pubspec.yaml`:

   ```bash
   flutter create sound_hub
   cd sound_hub
   # Replace lib/ and pubspec.yaml with the files from this zip
   ```

2. **Get dependencies:**

   ```bash
   flutter pub get
   ```

3. **Run in debug mode:**

   ```bash
   flutter run -d windows
   ```

4. **Build a release executable:**

   ```bash
   flutter build windows --release
   ```

   The output will be at:
   `build\windows\x64\runner\Release\sound_hub.exe`

## Project Structure

```
lib/
├── main.dart                     # App entry, theme, preferences
├── models/
│   └── sound_item.dart           # SoundItem data model
├── services/
│   ├── database_service.dart     # SQLite storage + file management
│   └── audio_service.dart        # Audio playback (audioplayers)
├── providers/
│   └── sounds_provider.dart      # ChangeNotifier state management
├── screens/
│   └── home_screen.dart          # Main screen UI
└── widgets/
    ├── sound_card.dart            # Individual sound card
    ├── rename_dialog.dart         # Rename dialog
    ├── delete_dialog.dart         # Delete confirmation
    ├── settings_dialog.dart       # App settings
    └── shortcut_dialog.dart       # Keyboard shortcut capture
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `sqflite_common_ffi` | SQLite database for sound metadata |
| `path_provider` | App documents directory |
| `audioplayers` | Audio playback |
| `file_picker` | Native file open dialog |
| `shared_preferences` | Settings persistence |
| `uuid` | Unique sound IDs |
| `provider` | State management |
| `desktop_drop` | Drag & drop file support |
| `path` | File path utilities |

## Data Storage

Sound metadata is stored in SQLite at:
`%USERPROFILE%\Documents\Soundboard\Soundboard.db`

Audio files are copied to:
`%USERPROFILE%\Documents\Soundboard\sounds\`

## Keyboard Shortcuts

Global shortcuts work as long as the app window is focused and no dialog is open. To assign a shortcut, hover over a sound card and click the keyboard icon, then press any key combination.

Examples: `F1`, `Ctrl+1`, `Alt+Shift+P`
