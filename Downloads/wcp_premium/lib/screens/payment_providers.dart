// ════════════════════════════════════════════════════════════════
// payment_providers.dart — درگاه‌های پرداخت ووکامرس پلاس (settings + اعتبارها).
//
// Lists every WC+ Iranian payment provider and lets the merchant edit its
// CREDENTIALS (terminal / merchant id / API key …) + enable + «تست اتصال»
// from the app — full parity with the web panel, NOTHING dropped. Backed by:
//   GET  /app/payments/providers              → list + per-provider field schema
//   POST /app/payments/providers/{slug}       → save (shared saver, encrypts)
//   POST /app/payments/providers/{slug}/test  → test_credentials
//
// Secrets are never sent back to the app (value '' + has_value flag); the
// SchemaForm masks them and only POSTs a secret the user actually typed.
// Complex fields (card2card lists / province multi-select) show as a web-only
// note (type 'info'); every standard credential is editable here.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/icons.dart';
import '../nav/shell.dart';
import '../services/store_api.dart';
import '../theme/tokens.dart';
import '../widgets/schema_form.dart';
import '../widgets/ui.dart';
import 'registry.dart';

void registerPaymentProvidersScreen() {
  kScreens['mod_payments_providers'] =
      (ctx, p) => const PaymentProvidersScreen();
}

class PaymentProvidersScreen extends StatefulWidget {
  const PaymentProvidersScreen({super.key});
  @override
  State<PaymentProvidersScreen> createState() =>
      _PaymentProvidersScreenState();
}

class _PaymentProvidersScreenState extends State<PaymentProvidersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
    } else {
      _loading = false;
      _error = 'برای مدیریت درگاه‌ها، فروشگاه را متصل کنید.';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final StoreResult r = await StoreApi.paymentProviders();
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() {
        _loading = false;
        _error = (r.map['message'] ?? r.error ?? 'دریافت درگاه‌ها ناموفق بود.')
            .toString();
      });
      return;
    }
    final dynamic items = r.map['items'];
    setState(() {
      _items = items is List
          ? items
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const <Map<String, dynamic>>[];
      _loading = false;
    });
  }

  Future<void> _openEditor(Map<String, dynamic> p) async {
    final bool? saved = await AppScope.of(context).navigate.currentState!
        .push<bool>(MaterialPageRoute<bool>(
      builder: (_) => _ProviderEditorScreen(provider: p),
    ));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final int onCount = _items.where((p) => p['enabled'] == true).length;
    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'درگاه‌های پرداخت',
            sub: _loading
                ? null
                : '${Fmt.fa(onCount)} فعال از ${Fmt.fa(_items.length)}',
            onBack: () => AppScope.of(context).pop(),
          ),
          Expanded(
            child: _loading
                ? const SlowLoader()
                : _error != null
                    ? ListView(children: [
                        const SizedBox(height: 70),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: c.tx2, height: 1.8, fontSize: 13.5)),
                        ),
                      ])
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) => _card(ctx, _items[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext ctx, Map<String, dynamic> p) {
    final c = ctx.c;
    final bool enabled = p['enabled'] == true;
    final bool active = p['active'] == true;
    final String desc = (p['description'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WcpCard(
        pad: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openEditor(p),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: enabled ? c.successSoft : c.bg2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: WcpIcon('card',
                      size: 20, color: enabled ? c.success : c.tx3),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text((p['label'] ?? '').toString(),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, color: c.tx3, height: 1.5)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _pill(
                  enabled ? (active ? 'فعال' : 'فعال (ناقص)') : 'خاموش',
                  enabled ? (active ? c.success : c.warning) : c.tx3,
                  enabled
                      ? (active ? c.successSoft : c.warningSoft)
                      : c.bg3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
      );
}

// ════════════════════════════════════════════════════════════════
// Editor — reuses SchemaForm for the credential fields.
// ════════════════════════════════════════════════════════════════
class _ProviderEditorScreen extends StatefulWidget {
  const _ProviderEditorScreen({required this.provider});
  final Map<String, dynamic> provider;
  @override
  State<_ProviderEditorScreen> createState() => _ProviderEditorScreenState();
}

class _ProviderEditorScreenState extends State<_ProviderEditorScreen> {
  final SchemaFormController _ctrl = SchemaFormController();
  late List<Map<String, dynamic>> _groups;
  late bool _enabled;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.provider['enabled'] == true;
    final List<dynamic> fields =
        (widget.provider['fields'] as List?) ?? const <dynamic>[];
    _groups = <Map<String, dynamic>>[
      <String, dynamic>{
        'key': 'creds',
        'title': 'اعتبارها',
        'fields': fields
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      },
    ];
    _ctrl.ingest(_groups);
  }

  String get _slug => (widget.provider['slug'] ?? '').toString();

  Future<void> _save() async {
    final nav = AppScope.of(context);
    setState(() => _saving = true);
    final StoreResult r = await StoreApi.paymentProviderSave(
        _slug, _ctrl.payload(),
        enabled: _enabled);
    if (!mounted) return;
    setState(() => _saving = false);
    final bool ok = r.ok && r.map['ok'] == true;
    nav.showToast(
        (r.map['message'] ?? r.error ?? (ok ? 'ذخیره شد' : 'ذخیره ناموفق بود'))
            .toString(),
        kind: ok ? 'success' : 'error',
        icon: ok ? 'check' : 'alert');
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _test() async {
    final nav = AppScope.of(context);
    setState(() => _testing = true);
    final StoreResult r =
        await StoreApi.paymentProviderTest(_slug, _ctrl.payload());
    if (!mounted) return;
    setState(() => _testing = false);
    final bool ok = r.ok && r.map['ok'] == true;
    nav.showToast(
        (r.map['message'] ?? r.error ?? (ok ? 'اتصال موفق بود' : 'تست ناموفق بود'))
            .toString(),
        kind: ok ? 'success' : 'error',
        icon: ok ? 'check' : 'alert');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bool canTest = widget.provider['can_test'] == true;
    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: (widget.provider['label'] ?? 'درگاه پرداخت').toString(),
            sub: 'اعتبارها و فعال‌سازی',
            onBack: () => Navigator.of(context).pop(false),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                WcpCard(
                  pad: 14,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('فعال‌سازی درگاه',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('در صفحهٔ پرداخت فروشگاه نمایش داده شود',
                                style:
                                    TextStyle(fontSize: 11.5, color: c.tx3)),
                          ],
                        ),
                      ),
                      WcpSwitch(
                        on: _enabled,
                        onChange: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SchemaForm(controller: _ctrl, groups: _groups),
                const SizedBox(height: 20),
                if (canTest) ...[
                  WcpButton(
                    variant: 'secondary',
                    full: true,
                    disabled: _testing || _saving,
                    icon: 'online',
                    label: _testing ? 'در حال تست…' : 'تست اتصال',
                    onClick: _test,
                  ),
                  const SizedBox(height: 10),
                ],
                WcpButton(
                  variant: 'primary',
                  full: true,
                  disabled: _saving,
                  icon: 'check',
                  label: _saving ? 'در حال ذخیره…' : 'ذخیره',
                  onClick: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
