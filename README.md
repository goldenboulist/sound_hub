# Sound Hub

![App Logo](assets/image.png)

A professional Windows desktop soundboard application built with Flutter, designed for seamless audio management and playback.

## Overview

Sound Hub is a feature-rich soundboard application that allows users to organize, manage, and play audio files with an intuitive interface. Originally converted from a React/TypeScript web application, this Flutter implementation provides native Windows performance with enhanced functionality.

## Key Features

### Audio Management
- **Multi-format Support**: Import and play MP3, WAV, OGG, FLAC, AAC, M4A files
- **Drag & Drop Interface**: Simply drag audio files directly onto the application window
- **Persistent Storage**: Automatic database storage with local file copies
- **Search Functionality**: Quick search by sound name or category

### Playback Controls
- **Individual Volume Control**: Adjust volume levels per sound
- **Simultaneous Playback**: Toggle multiple sounds playing at once
- **Keyboard Shortcuts**: Assign custom hotkeys for instant sound playback
- **Favorites System**: Mark frequently used sounds for quick access

### User Experience
- **Dark/Light Theme**: Switch between visual themes
- **Category Filtering**: Organize sounds by custom categories
- **Drag-to-Reorder**: Customize sound list arrangement
- **Responsive Design**: Modern, clean interface optimized for desktop use

## Technical Architecture

### Development Stack
- **Framework**: Flutter 3.0+
- **Language**: Dart
- **Database**: SQLite with sqflite_common_ffi
- **Audio Engine**: audioplayers package
- **State Management**: Provider pattern

### Project Structure

```
lib/
├── main.dart                     # Application entry point and theme configuration
├── models/
│   └── sound_item.dart           # SoundItem data model with SQLite integration
├── services/
│   ├── database_service.dart     # Database operations and file management
│   └── audio_service.dart        # Audio playback control and management
├── providers/
│   └── sounds_provider.dart      # State management with ChangeNotifier
├── screens/
│   └── home_screen.dart          # Primary user interface
└── widgets/
    ├── sound_card.dart            # Individual sound display component
    ├── rename_dialog.dart         # Sound renaming interface
    ├── delete_dialog.dart         # Deletion confirmation dialog
    ├── settings_dialog.dart       # Application configuration
    └── shortcut_dialog.dart       # Keyboard shortcut assignment
```

## Installation Guide

### System Requirements
- **Operating System**: Windows 10 (64-bit) or later
- **Development Environment**: Flutter SDK (stable channel, version 3.0 or higher)
- **Build Tools**: Visual Studio 2022 with "Desktop development with C++" workload

### Build Instructions

1. **Environment Setup**
   ```bash
   flutter doctor
   flutter config --enable-windows-desktop
   ```

2. **Project Initialization**
   ```bash
   flutter create sound_hub
   cd sound_hub
   ```

3. **Dependency Installation**
   ```bash
   flutter pub get
   ```

4. **Development Run**
   ```bash
   flutter run -d windows
   ```

5. **Release Build**
   ```bash
   flutter build windows --release
   ```

The compiled executable will be generated at:
`build\windows\x64\runner\Release\sound_hub.exe`

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `sqflite_common_ffi` | ^2.3.2 | SQLite database for metadata storage |
| `path_provider` | ^2.1.2 | Application directory access |
| `audioplayers` | ^6.0.0 | Cross-platform audio playback |
| `file_picker` | ^10.3.10 | Native file selection dialogs |
| `shared_preferences` | ^2.2.2 | User settings persistence |
| `uuid` | ^4.4.0 | Unique identifier generation |
| `provider` | ^6.1.2 | Reactive state management |
| `desktop_drop` | ^0.7.0 | Drag-and-drop functionality |
| `path` | ^1.9.0 | File path manipulation |
| `flutter_audio_output` | ^0.0.4 | Audio device selection |
| `flutter_svg` | ^2.2.3 | Scalable vector graphics support |

## Data Storage

### Database Location
Sound metadata and configuration are stored in SQLite at:
`%USERPROFILE%\Documents\Soundboard\Soundboard.db`

### Audio Files
Imported audio files are automatically copied to:
`%USERPROFILE%\Documents\Soundboard\sounds\`

## Usage Guide

### Adding Sounds
1. Click the "Import" button or drag audio files onto the application
2. Files are automatically processed and added to your sound library
3. Assign categories, keyboard shortcuts, and volume levels as needed

### Keyboard Shortcuts
- **Assignment**: Hover over any sound card and click the keyboard icon
- **Supported Combinations**: Single keys (F1-F12), modifiers (Ctrl, Alt, Shift)
- **Global Activation**: Shortcuts work when the application window is focused
- **Examples**: `F1`, `Ctrl+1`, `Alt+Shift+P`

### Organization Features
- **Categories**: Create custom categories to group related sounds
- **Favorites**: Mark frequently used sounds for quick access
- **Search**: Use the search bar to filter sounds by name or category
- **Reordering**: Drag sound cards to customize their display order

## Performance Considerations

- **Memory Management**: Audio files are loaded on-demand to minimize memory usage
- **Database Optimization**: SQLite indexing ensures fast search and retrieval
- **Concurrent Playback**: Engineered for smooth simultaneous audio playback
- **File Caching**: Intelligent caching reduces load times for frequently accessed sounds

## Contributing

This project maintains a clean, modular architecture suitable for contributions. Key areas for enhancement include:

- Additional audio format support
- Cloud synchronization capabilities
- Advanced audio effects and processing
- Plugin system for custom functionality

## License

This project is provided as-is for educational and personal use. Please ensure compliance with audio file licensing when using copyrighted material.

## Version History

- **v1.0.0**: Initial release with core soundboard functionality
- Windows desktop optimization
- SQLite database integration
- Keyboard shortcut system
- Theme support (dark/light modes)
