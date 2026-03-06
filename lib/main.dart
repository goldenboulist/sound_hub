import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/sounds_provider.dart';
import 'screens/home_screen.dart';
import 'services/audio_service.dart';

void main() {
  // Required for sqflite on desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  runApp(
    ChangeNotifierProvider(
      create: (_) => SoundsProvider(),
      child: const SoundboardApp(),
    ),
  );
}

class SoundboardApp extends StatefulWidget {
  const SoundboardApp({super.key});

  @override
  State<SoundboardApp> createState() => _SoundboardAppState();
}

class _SoundboardAppState extends State<SoundboardApp> {
  bool _darkMode = true;
  bool _allowMultiple = false;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _prefs = prefs;
      _darkMode = prefs.getBool('sb-dark-mode') ?? true;
      _allowMultiple = prefs.getBool('sb-allow-multiple') ?? false;
    });
    AudioService.instance.setAllowMultiple(_allowMultiple);
  }

  void _setDarkMode(bool value) {
    setState(() => _darkMode = value);
    _prefs?.setBool('sb-dark-mode', value);
  }

  void _setAllowMultiple(bool value) {
    setState(() => _allowMultiple = value);
    _prefs?.setBool('sb-allow-multiple', value);
    AudioService.instance.setAllowMultiple(value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sound_hub',
      debugShowCheckedModeBanner: false,
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: HomeScreen(
        darkMode: _darkMode,
        allowMultiple: _allowMultiple,
        onDarkModeChanged: _setDarkMode,
        onAllowMultipleChanged: _setAllowMultiple,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            // ── Accent ──────────────────────────────
            primary: Color(0xFF18DCB5),
            onPrimary: Color(0xFF080A0C),
            primaryContainer: Color(0xFF0D3D32),
            onPrimaryContainer: Color(0xFF18DCB5),
            // ── Secondary (same teal family) ────────
            secondary: Color(0xFF18DCB5),
            onSecondary: Color(0xFF080A0C),
            secondaryContainer: Color(0xFF0D3D32),
            onSecondaryContainer: Color(0xFF18DCB5),
            // ── Tertiary ────────────────────────────
            tertiary: Color(0xFF18DCB5),
            onTertiary: Color(0xFF080A0C),
            tertiaryContainer: Color(0xFF0D3D32),
            onTertiaryContainer: Color(0xFF18DCB5),
            // ── Error ───────────────────────────────
            error: Color(0xFFFF5555),
            onError: Color(0xFFFFFFFF),
            errorContainer: Color(0xFF4D1B1B),
            onErrorContainer: Color(0xFFFF8080),
            // ── Surfaces ────────────────────────────
            surface: Color(0xFF111218),           // main bg / header
            onSurface: Color(0xFFE7EBEF),         // primary text
            surfaceContainerLowest: Color(0xFF0D0F13),
            surfaceContainerLow: Color(0xFF111218),
            surfaceContainer: Color(0xFF16181F),  // card bg
            surfaceContainerHigh: Color(0xFF1C1F27),
            surfaceContainerHighest: Color(0xFF23262F), // search / inactive chips
            onSurfaceVariant: Color(0xFF8B909A),  // muted text / icons
            // ── Outline ─────────────────────────────
            outline: Color(0xFF3D4250),
            outlineVariant: Color(0xFF272B34),    // subtle borders
            // ── Misc ────────────────────────────────
            shadow: Colors.black,
            scrim: Colors.black,
            inverseSurface: Color(0xFFE7EBEF),
            onInverseSurface: Color(0xFF111218),
            inversePrimary: Color(0xFF0FAD8D),
          )
        : ColorScheme.fromSeed(
            seedColor: const Color(0xFF18DCB5),
            brightness: Brightness.light,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0D0F13) : const Color(0xFFF5F7FA),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
      ),
    );
  }
}
