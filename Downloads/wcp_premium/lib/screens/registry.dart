// ════════════════════════════════════════════════════════════════
// registry.dart — the screen route registry.
//
// HOW TO REGISTER A SCREEN (read this — every screen agent must follow it):
//
//   1. In your screen file (e.g. lib/screens/home.dart) define a top-level
//      `void registerHomeScreen() { ... }` that adds your route(s) to `kScreens`:
//
//        void registerHomeScreen() {
//          kScreens['home'] = (ctx, p) => const HomeScreen();
//          kScreens['orderDetail'] = (ctx, p) => OrderDetailScreen(id: p['id'] as String);
//        }
//
//   2. Call that `registerXxxScreen()` from `registerAllScreens()` at the
//      bottom of THIS file. `AppShell` invokes `registerAllScreens()` exactly
//      once on startup (before the first frame builds its tab navigators), so
//      every route must be present by then.
//
//   Keys are screen names exactly as referenced by
//   `AppScope.of(context).push('<name>', {...})` and by the tab ids
//   (home / orders / modules / products / more) used as each tab's root route.
//
//   `kScreens` is a plain growable map — multiple screen files add to it
//   without colliding as long as their keys differ. Resolving an unknown key
//   falls back to the "صفحه در دست ساخت" placeholder built in shell.dart, so a
//   missing registration degrades gracefully instead of crashing.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

// Every screen file contributes one or more routes via its own
// `registerXxxScreen()` function. Keep these imports 1:1 with the calls in
// `registerAllScreens()` below.
import 'account.dart';
import 'assistant.dart';
import 'business_intelligence.dart';
import 'chat.dart';
import 'commerce.dart';
import 'content.dart';
import 'customers.dart';
import 'dashboards.dart';
import 'booking_services.dart';
import 'payment_providers.dart';
import 'audience.dart';
import 'wave2_stats.dart';
import 'wave2c_stats.dart';
import 'depth_data.dart';
import 'engagement.dart';
import 'forms.dart';
import 'health_security.dart';
import 'abandoned_cart.dart';
import 'home.dart';
import 'launch.dart';
import 'module_config.dart';
import 'module_extra.dart';
import 'notice_bars.dart';
import 'stop_sale_rules.dart';
import 'team_goals.dart';
import 'module_pages.dart';
import 'module_settings.dart';
import 'modules.dart';
import 'more.dart';
import 'order_create.dart';
import 'orders.dart';
import 'paylink.dart';
import 'product_analytics.dart';
import 'product_changes.dart';
import 'product_create.dart';
import 'products.dart';
import 'states.dart';
import 'support.dart';
import 'team.dart';
import 'utility.dart';

/// Route name → builder. Screen files contribute entries via their own
/// `registerXxxScreen()` functions (wired up in [registerAllScreens]).
final Map<String, Widget Function(BuildContext, Map<String, dynamic>)>
    kScreens = <String, Widget Function(BuildContext, Map<String, dynamic>)>{};

/// Called once by `AppShell` at startup. Screen agents append a single line
/// here per screen file: `registerHomeScreen();`, `registerOrdersScreen();`, …
/// Keep it idempotent — it may be called more than once during hot-reload
/// (every `registerXxxScreen()` just reassigns its keys in [kScreens]).
void registerAllScreens() {
  // Order matters only where two files register the SAME key: the LAST writer
  // wins. `registerModulePagesScreen()` and `registerModuleExtraScreen()`
  // intentionally run AFTER `registerModulesScreen()` so their rich `mod_*`
  // overrides (wallet/loyalty/coupon/divar/basalam + giftcard/popup/lockdown/
  // cache/seo) replace the generic settings pages it registers for every id.
  registerLaunchScreen();
  registerHomeScreen();
  registerOrdersScreen();
  registerOrderCreateScreen();
  registerProductsScreen();
  registerProductCreateScreen();
  registerContentScreen();
  registerCustomersScreen();
  registerModulesScreen();
  // After registerModulesScreen so the rich mod_* overrides win over the
  // generic ones it registers for every module id.
  registerModulePagesScreen();
  registerModuleExtraScreen();
  registerModuleSettingsScreen();
  // Curated grouped-schema editors (route 'modcfg_<id>') for the
  // store-feature/widgets-hub modules surfaced in the modules screen.
  registerModuleConfigScreen();
  // Notice-bar CRUD (route 'mod_notice_bar') — overrides the generic editor.
  registerNoticeBarsScreen();
  // Stop-sale per-rule CRUD (route 'mod_stop_sale_rules').
  registerStopSaleRulesScreen();
  // Bulk product price/stock editor (route 'mod_product_changes') — overrides
  // the generic placeholder registered by registerModulePagesScreen above.
  registerProductChangesScreen();
  // Abandoned-cart follow-up list + quick-CALL (route 'mod_abandoned_cart')
  // — overrides the generic settings editor from kGridCuratedModules.
  registerAbandonedCartScreen();
  // Payment-links CRUD (route 'modcfg_paylink', reached from the store-feature
  // row id 'paylink') — registered here since 'paylink' is NOT in
  // kCuratedModuleIds, so this is its only registration.
  registerPaylinkScreen();
  // Form-builder list + submissions (route 'mod_forms') — overrides the
  // generic settings editor from kGridCuratedModules ('forms').
  registerFormsScreen();
  // Operational dashboards: booking/rma/campaign/affiliate/subscription/b2b
  // (routes 'modcfg_bookings' … reached from the store-feature rows).
  registerDashboardsScreen();
  // Booking SERVICES full CRUD (route 'mod_booking_services').
  registerBookingServicesScreen();
  // Payment providers (WC+ Iranian gateways) credentials (route 'mod_payments_providers').
  registerPaymentProvidersScreen();
  // Audience analytics DATA dashboard (route 'mod_audience' + settings gear).
  // Registered AFTER registerModuleConfigScreen so the data view wins the key.
  registerAudienceScreen();
  // Wave-2 data views: auth stats, popup stats, attribution (data wins key).
  registerWave2StatsScreens();
  // Wave-2 2C data views: mini-app stats, social-tools send log.
  registerWave2cStatsScreens();
  // Depth data views: B2B credit accounts + subscription plans/MRR.
  registerDepthDataScreens();
  // Product-analytics dashboard (route 'mod_product_analytics').
  registerProductAnalyticsScreen();
  // Business-intelligence snapshot (route 'mod_business_intelligence').
  registerBusinessIntelligenceScreen();
  // Health & security audit (route 'mod_health_security').
  registerHealthSecurityScreen();
  // Team-goals CRUD + workflow (route 'mod_team_goals' / 'team_goal').
  registerTeamGoalsScreen();
  registerUtilityScreen();
  registerMoreScreen();
  registerAccountScreen();
  registerSupportScreen();
  registerChatScreen();
  registerTeamScreen();
  registerCommerceScreens();
  registerAssistantScreen();
  registerEngagementScreen();
  registerStatesScreen();
}
