// lib/screens/public_profile_screen.dart
// -----------------------------------------------------------------------------
// LinkLocker – Public Profile Screen (stub version)
// Displays user's public page based on their username.
// ----------------------------------------------------------------------------- 

import 'package:flutter/material.dart';

class PublicProfileScreen extends StatelessWidget {
  final String username;
  const PublicProfileScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('@$username')),
      body: Center(
        child: Text(
          'Public profile for @$username will appear here soon.',
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
