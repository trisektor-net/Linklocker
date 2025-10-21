// =============================================================================
// LinkLocker – main.dart (Final Zero-Error Version)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth_screen.dart';
import 'screens/link_editor_screen.dart';
import 'screens/public_profile_screen.dart';
import 'screens/analytics_screen.dart';
import 'widgets/cookie_consent.dart';
import 'services/monitoring.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: 'assets/.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize optional monitoring (Sentry, etc.)
  await initMonitoring();

  runApp(const LinkLockerApp());
}

class LinkLockerApp extends StatelessWidget {
  const LinkLockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: '/editor',
          builder: (context, state) => const LinkEditorScreen(),
        ),
        GoRoute(
          path: '/u/:username',
          builder: (context, state) {
            final username = state.pathParameters['username']!;
            return PublicProfileScreen(username: username);
          },
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'LinkLocker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) => Stack(
        children: [
          Positioned.fill(child: child ?? const SizedBox.shrink()),
          const CookieConsentBanner(),
        ],
      ),
    );
  }
}
