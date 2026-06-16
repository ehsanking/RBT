// ════════════════════════════════════════════════════════════════
// module_config.dart — curated, grouped, schema-driven module settings.
//
// Mirrors a WC+ module's admin page faithfully (Persian labels, real
// field types, image upload, list-box pickers) via the server's
// GET/POST /app/module/{id}/settings (see SchemaForm for the contract).
// Declared `actions` (e.g. a test-connection button) POST to
// /app/module/{id}/action.
//
// Registered (route 'modcfg_<id>') for the curated modules and wired to
// the module cards in modules.dart so the merchant configures everything
// from the phone — no web panel.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens.dart';
import '../services/store_api.dart';
import '../nav/shell.dart';
import '../widgets/ui.dart';
import '../widgets/schema_form.dart';
import 'registry.dart';

/// Widgets-Hub / standalone modules with a curated editor, surfaced in
/// the modules screen's «قابلیت‌های فروشگاه» section (route 'modcfg_<id>').
const List<String> kCuratedModuleIds = <String>[
  'labels-buttons',
  'wishlist',
  'compare',
  'stock-reminder',
  'analytics-ga4',
  'multilingual',
  'age-verification',
  // Product Q&A is a standalone «store feature» (its own enable option
  // wooplus_product_qa_enabled, managed by the form's «فعال» field), NOT a
  // master-gate grid module — it isn't returned by /app/modules. Surface it
  // in the «قابلیت‌های فروشگاه» curated section (see kStoreFeatureModules).
  'product-qa',
  // AI + global SEO config (delegated server-side to /app/ai/* and the SEO
  // module's global settings via the generic /app/module/{id}/settings).
  'ai',
  'seo',
  // leftover store-feature module (no master toggle) — app-config wave 1.
  'notice-bar',
];

/// Master-gate GRID modules that now open the curated editor instead of
/// the generic flat one. Maps the grid id (key − `module_`, underscores)
/// → the server module id (dash form, matching the module directory).
const Map<String, String> kGridCuratedModules = <String, String>{
  'abandoned_cart': 'abandoned-cart',
  'subscription_profile': 'subscription-profile',
  'stop_sale': 'stop-sale',
  'social_tools': 'social-tools',
  'auth': 'auth',
  'b2b': 'b2b',
  // Grid ids come from the server module toggle keys minus the `module_`
  // prefix, so the installment card's id is `installment_gateway`
  // (module_installment_gateway), not `installment`. Keep both for safety
  // (server grid + any sample/fallback data).
  'installment_gateway': 'installment-gateway',
  'installment': 'installment-gateway',
  // #17 — بازارگاه‌ها (باسلام/دیجی‌کالا/دیوار/ترب/حساب‌فا): credentials,
  // enable toggles, real test-connection actions, Torob feed + regen.
  'marketplaces': 'marketplaces',
  // leftover modules — app-config wave 1 (grid master-toggle modules whose
  // schema is served by includes/modcfg/<id>.php via the curated filters).
  'chat': 'chat',
  'club': 'club',
  'coupon_builder': 'coupon-builder',
  'popup_builder': 'popup-builder',
  'forms': 'forms',
  // app-config wave 2.
  'landing_builder': 'landing-builder',
  'article_maker': 'article-maker',
  'shipping': 'shipping',
  'sales_manager': 'sales-manager',
  'ticketing': 'ticketing',
  'team_goals': 'team-goals',
  // app-config wave 3 (modules with genuine merchant settings; pure
  // dashboards/CRUD like product-changes, business-intelligence and
  // product-analytics were intentionally NOT given an empty config screen).
  'time_machine': 'time-machine',
  'audience': 'audience',
  'mini_app': 'mini-app',
  // app-config wave 4 (infra/AI modules with real merchant settings).
  'cache': 'cache',
  'pwa': 'pwa',
  'emergency': 'emergency',
  'footer_credit': 'footer-credit',
  'mobile_template': 'mobile-template',
  'ai_commerce': 'ai-commerce',
  'ai_field_genie': 'ai-field-genie',
  'ai_prompts': 'ai-prompts',
};

void registerModuleConfigScreen() {
  for (final String id in kCuratedModuleIds) {
    kScreens['modcfg_$id'] = (ctx, p) =>
        ModuleConfigScreen(id: (p['id'] as String?) ?? id, fallbackTitle: p['title'] as String?);
  }
  // Override the generic grid editor for these gate-listed modules.
  kGridCuratedModules.forEach((gridId, serverId) {
    kScreens['mod_$gridId'] =
        (ctx, p) => ModuleConfigScreen(id: serverId, fallbackTitle: p['title'] as String?);
  });
}

class ModuleConfigScreen extends StatefulWidget {
  const ModuleConfigScreen({super.key, required this.id, this.fallbackTitle});
  final String id;
  final String? fallbackTitle;

  @override
  State<ModuleConfigScreen> createState() => _ModuleConfigScreenState();
}

class _ModuleConfigScreenState extends State<ModuleConfigScreen> {
  final SchemaFormController _ctrl = SchemaFormController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _title = '';
  String _subtitle = '';
  List<Map<String, dynamic>> _groups = const [];
  List<Map<String, dynamic>> _actions = const [];

  // per-action inline result + busy.
  final Map<String, String> _actionResult = {};
  final Map<String, bool> _actionOk = {};
  final Set<String> _actionBusy = {};

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
    } else {
      _loading = false;
      _error = 'برای پیکربندیِ این ماژول، فروشگاه را متصل کنید.';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final StoreResult r = await StoreApi.moduleSchema(widget.id);
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false || (r.map['groups'] == null)) {
      setState(() {
        _loading = false;
        _error = r.map['available'] == false
            ? (r.map['message']?.toString() ?? 'این ماژول روی فروشگاه فعال نیست.')
            : (r.map['message']?.toString() ??
                r.error ??
                'دریافتِ تنظیمات ناموفق بود.');
      });
      return;
    }
    _ingest(r.map);
    setState(() => _loading = false);
  }

  void _ingest(Map<String, dynamic> m) {
    final groups = <Map<String, dynamic>>[
      for (final dynamic g in (m['groups'] as List? ?? const []))
        if (g is Map) Map<String, dynamic>.from(g),
    ];
    final actions = <Map<String, dynamic>>[
      for (final dynamic a in (m['actions'] as List? ?? const []))
        if (a is Map) Map<String, dynamic>.from(a),
    ];
    _ctrl.ingest(groups);
    _groups = groups;
    _actions = actions;
    _title = (m['title'] ?? widget.fallbackTitle ?? 'تنظیمات').toString();
    _subtitle = (m['subtitle'] ?? 'پیکربندیِ کامل از اپ').toString();
  }

  Future<void> _save() async {
    final nav = AppScope.of(context);
    setState(() => _saving = true);
    final StoreResult r =
        await StoreApi.moduleSchemaSave(widget.id, _ctrl.payload());
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.ok && r.map['groups'] != null) {
      setState(() => _ingest(r.map));
      nav.showToast('تنظیمات ذخیره شد', kind: 'success', icon: 'check');
    } else {
      nav.showToast(r.error ?? r.map['message']?.toString() ?? 'ذخیرهٔ تنظیمات ناموفق بود',
          kind: 'error', icon: 'alert');
    }
  }

  Future<void> _runAction(Map<String, dynamic> a) async {
    final String id = (a['id'] ?? '').toString();
    if (id.isEmpty) return;
    setState(() {
      _actionBusy.add(id);
      _actionResult.remove(id);
    });
    final StoreResult r = await StoreApi.moduleAction(widget.id, id);
    if (!mounted) return;
    final bool ok = r.ok && r.map['ok'] == true;
    final String msg = (r.map['message'] ?? r.map['reply'] ?? r.error ?? '').toString();
    setState(() {
      _actionBusy.remove(id);
      _actionOk[id] = ok;
      _actionResult[id] =
          msg.isNotEmpty ? msg : (ok ? 'انجام شد ✓' : 'عملیات ناموفق بود.');
    });
    // Some actions hand back a URL (the regenerated Torob feed, an OAuth
    // authorize page, ...) — open it in the external browser.
    final String url = (r.map['url'] ?? '').toString();
    if (ok && url.isNotEmpty) {
      final Uri? u = Uri.tryParse(url);
      if (u != null) {
        launchUrl(u, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: _title.isNotEmpty
                ? _title
                : (widget.fallbackTitle ?? 'تنظیمات'),
            sub: _subtitle.isNotEmpty ? _subtitle : 'پیکربندیِ کامل از اپ',
            onBack: () => AppScope.of(context).pop(),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.accent),
                    ),
                  )
                : (_error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13.5, color: c.tx2, height: 1.7)),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          SchemaForm(
                            controller: _ctrl,
                            groups: _groups,
                            onChanged: () => setState(() {}),
                          ),
                          if (_actions.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            for (final a in _actions) _actionCard(context, a),
                          ],
                          const SizedBox(height: 16),
                          WcpButton(
                            full: true,
                            size: 'lg',
                            icon: 'check',
                            label:
                                _saving ? 'در حال ذخیره…' : 'ذخیرهٔ تنظیمات',
                            onClick: _saving ? null : _save,
                          ),
                        ],
                      )),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext context, Map<String, dynamic> a) {
    final c = context.c;
    final String id = (a['id'] ?? '').toString();
    final String label = (a['label'] ?? 'اجرا').toString();
    final String route = (a['route'] ?? '').toString();
    final bool busy = _actionBusy.contains(id);
    final String? res = _actionResult[id];
    final bool ok = _actionOk[id] == true;
    // Navigation action (e.g. → a CRUD sub-screen) rather than a POST.
    if (route.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: WcpButton(
          full: true,
          variant: 'secondary',
          icon: (a['icon'] ?? 'list').toString(),
          label: label,
          onClick: () => AppScope.of(context).push(route, {'id': widget.id}),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: WcpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WcpButton(
              full: true,
              variant: 'secondary',
              icon: (a['icon'] ?? 'sparkles').toString(),
              label: busy ? 'در حال اجرا…' : label,
              onClick: busy ? null : () => _runAction(a),
            ),
            if (res != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ok ? c.successSoft : c.errorSoft,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: ok ? c.success : c.error, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(ok ? Icons.check_circle : Icons.error_outline,
                        size: 17, color: ok ? c.success : c.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(res,
                          style: TextStyle(
                              fontSize: 12.5, color: c.tx1, height: 1.7)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
