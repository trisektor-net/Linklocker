// =============================================================================
// LinkLocker – Monitoring bootstrap (Sentry optional, safe if missing DSN)
// =============================================================================
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> initMonitoring() async {
  final dsn = dotenv.env['SENTRY_DSN'];

  // Safe check — skips initialization if DSN is empty or undefined
  if (dsn == null || dsn.isEmpty) {
    if (kDebugMode) {
      debugPrint('[Monitoring] No SENTRY_DSN found – skipping Sentry init.');
    }
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate = 0.2;
      options.enableAutoPerformanceTracing = true;
      options.attachThreads = true;
      options.sendDefaultPii = false; // Privacy-first
    },
    appRunner: () => debugPrint('[Monitoring] Sentry initialized successfully.'),
  );
}
