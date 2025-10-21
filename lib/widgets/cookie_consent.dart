// =============================================================================
// LinkLocker – Cookie Consent Banner (Flutter 3.35+ compatible)
// =============================================================================
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CookieConsentBanner extends StatefulWidget {
  const CookieConsentBanner({super.key});
  @override
  State<CookieConsentBanner> createState() => _CookieConsentBannerState();
}

class _CookieConsentBannerState extends State<CookieConsentBanner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _checkConsent();
  }

  Future<void> _checkConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final given = prefs.getBool('cookie_consent') ?? false;
    if (!given) setState(() => _visible = true);
  }

  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cookie_consent', true);
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final bg = const Color(0xFF212121).withValues(alpha: 0.95); // ✅ Updated
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Material(
          elevation: 6,
          color: bg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'We use cookies to improve your experience. By continuing, you agree.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: _accept,
                  child: const Text('Accept', style: TextStyle(color: Colors.indigoAccent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}