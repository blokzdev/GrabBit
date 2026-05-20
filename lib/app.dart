import 'package:flutter/material.dart';
import 'package:grabbit/features/library/presentation/library_screen.dart';

class GrabBitApp extends StatelessWidget {
  const GrabBitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrabBit',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const LibraryScreen(),
    );
  }
}
