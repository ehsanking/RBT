// ════════════════════════════════════════════════════════════════
// main.dart — entry point.
//
// Subscription state is loaded from shared_preferences BEFORE the first
// frame so `Subs.active` / `Subs.until` are synchronous everywhere (the
// paywall gate in the launch flow reads them with no awaits / no
// FutureBuilder). `ensureInitialized()` is required to touch plugins
// (shared_preferences) before runApp.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/native.dart';
import 'core/pricing.dart';
import 'core/subs.dart';
import 'services/portal_api.dart';
import 'services/store_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Synchronous-everywhere state, loaded from cache BEFORE the first frame.
  await Subs.load();
  await Pricing.load();
  await PortalApi.init();  // saved subscription bearer token (central panel).
  await StoreApi.init();   // saved store credentials (merchant's WC+ site).

  // Demo build only: auto-connect to a preset store supplied at compile time
  // (`--dart-define=WPP_DEMO_URL=... WPP_DEMO_CK=... WPP_DEMO_CS=...`) so the
  // inner screens show REAL store data without the manual Connect flow. No
  // credentials are hard-coded in source; a normal build (no defines) is unaffected.
  const String demoUrl = String.fromEnvironment('WPP_DEMO_URL');
  if (demoUrl.isNotEmpty && !StoreApi.hasStore) {
    await StoreApi.connect(
      url: demoUrl,
      ck: const String.fromEnvironment('WPP_DEMO_CK'),
      cs: const String.fromEnvironment('WPP_DEMO_CS'),
    );
  }

  // Best-effort: pull the connected store's display name (WP REST root) so the
  // dashboard header + settings show the REAL store name instead of a sample.
  // Non-blocking — fires and forgets; screens read StoreApi.storeName when set.
  if (StoreApi.hasStore) {
    StoreApi.fetchStoreInfo();
  }

  // Refresh live pricing + subscription status from the panel in the
  // BACKGROUND — never block startup. The cached values render immediately;
  // these calls update Pricing/Subs when they land, and the paywall +
  // subscription screen also re-fetch on demand.
  PortalApi.fetchPricing();
  if (PortalApi.hasToken) PortalApi.fetchStatus();

  // Restore a Cafe Bazaar (Poolakey) subscription on cold start — queries the
  // Bazaar billing service for owned subscriptions and unlocks if active.
  // Best-effort + non-blocking; a no-op on builds without Bazaar.
  PortalApi.syncBazaar();

  // Ask for the runtime permissions the app needs up-front (notifications on
  // Android 13+). Best-effort + non-blocking — the OS dialog appears over the
  // first frame; a denial never crashes anything.
  Native.requestStartupPermissions();

  // FCM (BATCH 5): once connected to a store, register this device's token with
  // the merchant WP -> central relay so it gets content-free background push on
  // new chat messages. Fully defensive — fires and forgets; never blocks
  // startup and never crashes when FCM/token is unavailable.
  if (StoreApi.hasStore) {
    _registerFcmDevice();
  }

  runApp(const WcpApp());
}

/// Best-effort: fetch the native FCM token and register it with the connected
/// store. Skips silently when no token (FCM unavailable) or on any error.
Future<void> _registerFcmDevice() async {
  try {
    final String? token = await Native.fcmToken();
    if (token == null || token.isEmpty) return;
    await StoreApi.chatRegisterDevice(token);
  } catch (_) {
    // ignore — push is best-effort; the app still polls for chat changes.
  }
}
