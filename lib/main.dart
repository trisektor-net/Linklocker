// lib/main.dart
// =============================================================================
// LinkLocker – Main Entry
// dotenv initialized before Supabase (works on Web, iOS, Android, macOS)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/link_editor_screen.dart';
import 'screens/public_profile_screen.dart';

Future<void> main() async {
  // 1️⃣ Required for async initialization before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // 2️⃣ Load environment variables from assets/.env
  try {
    await dotenv.load(fileName: 'assets/.env');
    debugPrint('✅ .env successfully loaded from assets.');
  } catch (e) {
    debugPrint('⚠️ Failed to load .env, using fallback values. Error: $e');
  }

  // 3️⃣ Safe fallback values (used if .env is missing or fails to load)
  const fallbackUrl = 'https://nsdlwuarzvkprhlvmnmz.supabase.co';
  const fallbackAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5zZGx3dWFyenZrcHJobHZtbm16Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjQwNjYsImV4cCI6MjA3NjM0MDA2Nn0.VjaQfQN1ttuiOv7UnWzpqZ4BJpuJUeWZFGe3wYIMXjY';

  // 4️⃣ Read from dotenv if available, else fallback
  final supabaseUrl = dotenv.maybeGet('SUPABASE_URL') ?? fallbackUrl;
  final supabaseAnonKey =
      dotenv.maybeGet('SUPABASE_ANON_KEY') ?? fallbackAnonKey;

  // 5️⃣ Initialize Supabase AFTER dotenv values are known
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // 6️⃣ Finally, launch the app
  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// Root widget
// -----------------------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'LinkLocker',
      home: AuthScreen(), // starting screen
    );
  }
}