// lib/main.dart
    import 'package:flutter/material.dart';
    import 'screens/home_screen.dart';

    void main() {
      runApp(const MyApp());
    }

    class MyApp extends StatelessWidget {
      const MyApp({super.key});

      @override
      Widget build(BuildContext context) {
        return MaterialApp(
          title: 'Medien Explorer',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            // Flat UI Look - Weniger Schatten, flachere Farben
            cardTheme: CardTheme(
              elevation: 0, // Flach
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Leichte Rundung
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          home: HomeScreen(),
        );
      }
    }
