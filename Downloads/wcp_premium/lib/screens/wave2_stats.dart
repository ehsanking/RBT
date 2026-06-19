// ════════════════════════════════════════════════════════════════
// wave2_stats.dart — three Wave-2 data views (charts), all reusing charts.dart:
//   AuthStatsScreen    (mod_auth)           — OTP/verify message sends
//   PopupStatsScreen   (mod_popup_builder)  — popup display/click/conversion
//   AttributionScreen  (mod_attribution)    — order-source (attribution) rollup
// Backed by /app/auth/stats · /app/popups · /app/attribution.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/icons.dart';
import '../nav/shell.dart';
import '../services/store_api.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';
import 'module_config.dart';
import 'registry.dart';

void registerWave2StatsScreens() {
  kScreens['mod_auth'] = (ctx, p) => const AuthStatsScreen();
  kScreens['mod_auth_settings'] = (ctx, p) =>
      const ModuleConfigScreen(id: 'auth', fallbackTitle: 'احراز هویت');
  kScreens['mod_popup_builder'] = (ctx, p) => const PopupStatsScreen();
  kScreens['mod_popup_builder_settings'] = (ctx, p) =>
      const ModuleConfigScreen(id: 'popup-builder', fallbackTitle: 'پاپ‌آپ‌ساز');
  kScreens['mod_attribution'] = (ctx, p) => const AttributionScreen();
}

// Shared bits ───────────────────────────────────────────────────────
Widget _statCard(BuildContext ctx, String label, String value, String icon,
    {Color? color}) {
  final c = ctx.c;
  return WcpCard(
    pad: 12,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        WcpIcon(icon, size: 16, color: color ?? c.accent),
        const SizedBox(height: 8),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10.5, color: c.tx3)),
      ],
    ),
  );
}

Widget _chartCard(BuildContext ctx, String title, Widget chart) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WcpCard(
        pad: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            chart,
          ],
        ),
      ),
    );

Widget _errBody(BuildContext ctx, String msg) {
  final c = ctx.c;
  return ListView(children: [
    const SizedBox(height: 70),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.tx2, height: 1.8, fontSize: 13.5)),
    ),
  ]);
}

// ════════════════════════════════════════════════════════════════
// AUTH — OTP / verification message sends.
// ════════════════════════════════════════════════════════════════
class AuthStatsScreen extends StatefulWidget {
  const AuthStatsScreen({super.key});
  @override
  State<AuthStatsScreen> createState() => _AuthStatsScreenState();
}

class _AuthStatsScreenState extends State<AuthStatsScreen> {
  int _days = 30;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _totals = const {};
  List<Map<String, dynamic>> _byGateway = const [];
  List<double> _daySeries = const [];

  static const Map<int, String> _periods = {7: '۷ روز', 30: '۳۰ روز', 90: '۹۰ روز'};
  static const Map<String, String> _gw = {
    'sms': 'پیامک',
    'email': 'ایمیل',
    'whatsapp': 'واتساپ',
    'bale': 'بله',
    'telegram': 'تلگرام',
  };

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
    } else {
      _loading = false;
      _error = 'برای دیدن آمار، فروشگاه را متصل کنید.';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final StoreResult r = await StoreApi.authStats(days: _days);
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() {
        _loading = false;
        _error = (r.map['message'] ?? r.error ?? 'دریافت آمار ناموفق بود.').toString();
      });
      return;
    }
    final Map s = r.map['stats'] is Map ? r.map['stats'] : const {};
    final List byDay = s['by_day'] is List ? s['by_day'] : const [];
    final List byGw = s['by_gateway'] is List ? s['by_gateway'] : const [];
    setState(() {
      _totals = s['totals'] is Map ? Map<String, dynamic>.from(s['totals']) : const {};
      _daySeries = byDay
          .whereType<Map>()
          .map((e) => ((e['total'] as num?) ?? 0).toDouble())
          .toList();
      _byGateway =
          byGw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final int total = (_totals['total'] as num?)?.toInt() ?? 0;
    final int sent = (_totals['sent'] as num?)?.toInt() ?? 0;
    final int failed = (_totals['failed'] as num?)?.toInt() ?? 0;
    final num rate = (_totals['success_rate'] as num?) ?? 0;
    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'احراز هویت',
            sub: 'آمار ارسال کد تایید',
            onBack: () => AppScope.of(context).pop(),
            actions: [
              IconBtnRaw(
                onClick: () => AppScope.of(context).push('mod_auth_settings'),
                child: const WcpIcon('settings', size: 20),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const SlowLoader()
                : _error != null
                    ? _errBody(context, _error!)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            Row(children: [
                              for (final e in _periods.entries) ...[
                                if (e.key != _periods.keys.first)
                                  const SizedBox(width: 8),
                                Expanded(
                                  child: WcpChip(
                                    active: _days == e.key,
                                    onClick: () {
                                      if (_days == e.key) return;
                                      setState(() => _days = e.key);
                                      _load();
                                    },
                                    child: Text(e.value),
                                  ),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 14),
                            IntrinsicHeight(
                              child: Row(children: [
                                Expanded(
                                    child: _statCard(context, 'کل ارسال',
                                        Fmt.fa(total), 'send')),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'موفق',
                                        Fmt.fa(sent), 'check',
                                        color: c.success)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'ناموفق',
                                        Fmt.fa(failed), 'alert',
                                        color: c.error)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'نرخ موفقیت',
                                        '${Fmt.fa(rate.round())}٪', 'gauge')),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            if (_daySeries.length >= 2)
                              _chartCard(context, 'روند روزانه ارسال',
                                  WcpLine(values: _daySeries)),
                            if (_byGateway.isNotEmpty)
                              WcpCard(
                                pad: 0,
                                child: Column(children: [
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                                    child: Text('بر حسب درگاه',
                                        style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  for (int i = 0; i < _byGateway.length; i++) ...[
                                    if (i > 0) Divider(height: 1, color: c.line),
                                    _gwRow(context, _byGateway[i]),
                                  ],
                                ]),
                              ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _gwRow(BuildContext context, Map<String, dynamic> g) {
    final c = context.c;
    final String gw = (g['gateway'] ?? '').toString();
    final int tot = (g['total'] as num?)?.toInt() ?? 0;
    final num rate = (g['success_rate'] as num?) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Text(_gw[gw] ?? gw,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text('${Fmt.fa(tot)} ارسال',
            style: TextStyle(fontSize: 11.5, color: c.tx3)),
        const SizedBox(width: 10),
        Text('${Fmt.fa(rate.round())}٪',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: rate >= 80
                    ? c.success
                    : (rate >= 40 ? c.warning : c.error))),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// POPUPS — display / click / conversion.
// ════════════════════════════════════════════════════════════════
class PopupStatsScreen extends StatefulWidget {
  const PopupStatsScreen({super.key});
  @override
  State<PopupStatsScreen> createState() => _PopupStatsScreenState();
}

class _PopupStatsScreenState extends State<PopupStatsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _totals = const {};
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
    } else {
      _loading = false;
      _error = 'برای دیدن آمار، فروشگاه را متصل کنید.';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final StoreResult r = await StoreApi.popups();
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() {
        _loading = false;
        _error = (r.map['message'] ?? r.error ?? 'دریافت آمار ناموفق بود.').toString();
      });
      return;
    }
    setState(() {
      _totals = r.map['totals'] is Map
          ? Map<String, dynamic>.from(r.map['totals'])
          : const {};
      _items = r.map['items'] is List
          ? (r.map['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final int d = (_totals['display'] as num?)?.toInt() ?? 0;
    final int k = (_totals['click'] as num?)?.toInt() ?? 0;
    final int v = (_totals['conversion'] as num?)?.toInt() ?? 0;
    final num cr = (_totals['cr'] as num?) ?? 0;
    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'پاپ‌آپ‌ها',
            sub: 'نمایش، کلیک و تبدیل',
            onBack: () => AppScope.of(context).pop(),
            actions: [
              IconBtnRaw(
                onClick: () =>
                    AppScope.of(context).push('mod_popup_builder_settings'),
                child: const WcpIcon('settings', size: 20),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const SlowLoader()
                : _error != null
                    ? _errBody(context, _error!)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            IntrinsicHeight(
                              child: Row(children: [
                                Expanded(
                                    child: _statCard(context, 'نمایش',
                                        Fmt.fa(d), 'eye')),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'کلیک',
                                        Fmt.fa(k), 'chart')),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'تبدیل',
                                        Fmt.fa(v), 'check',
                                        color: c.success)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'نرخ تبدیل',
                                        '${Fmt.fa(cr.round())}٪', 'gauge')),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            if (d > 0)
                              _chartCard(
                                  context,
                                  'قیف عملکرد',
                                  WcpBars(data: [
                                    ChartDatum('نمایش', d.toDouble()),
                                    ChartDatum('کلیک', k.toDouble()),
                                    ChartDatum('تبدیل', v.toDouble()),
                                  ])),
                            if (_items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                      'هنوز پاپ‌آپی ساخته نشده یا آماری ثبت نشده است.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12.5, color: c.tx3)),
                                ),
                              )
                            else
                              WcpCard(
                                pad: 0,
                                child: Column(children: [
                                  for (int i = 0; i < _items.length; i++) ...[
                                    if (i > 0) Divider(height: 1, color: c.line),
                                    _popupRow(context, _items[i]),
                                  ],
                                ]),
                              ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _popupRow(BuildContext context, Map<String, dynamic> p) {
    final c = context.c;
    final int d = (p['display'] as num?)?.toInt() ?? 0;
    final int v = (p['conversion'] as num?)?.toInt() ?? 0;
    final num cr = (p['cr'] as num?) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Text((p['title'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text('${Fmt.fa(d)} نمایش · ${Fmt.fa(v)} تبدیل',
            style: TextStyle(fontSize: 11, color: c.tx3)),
        const SizedBox(width: 8),
        Text('${Fmt.fa(cr.round())}٪',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: c.accent)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ATTRIBUTION — order-source rollup.
// ════════════════════════════════════════════════════════════════
class AttributionScreen extends StatefulWidget {
  const AttributionScreen({super.key});
  @override
  State<AttributionScreen> createState() => _AttributionScreenState();
}

class _AttributionScreenState extends State<AttributionScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _rep = const {};

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
    } else {
      _loading = false;
      _error = 'برای دیدن منبع سفارش‌ها، فروشگاه را متصل کنید.';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final StoreResult r = await StoreApi.attribution();
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() {
        _loading = false;
        _error = (r.map['message'] ?? r.error ?? 'دریافت اطلاعات ناموفق بود.').toString();
      });
      return;
    }
    setState(() {
      _rep = r.map;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final int orders = (_rep['total_orders'] as num?)?.toInt() ?? 0;
    final num revenue = (_rep['total_revenue'] as num?) ?? 0;
    final int tagged = (_rep['tagged_orders'] as num?)?.toInt() ?? 0;
    final int coverage = orders > 0 ? ((tagged / orders) * 100).round() : 0;
    final List channels = _rep['channels'] is List ? _rep['channels'] : const [];
    final Map devices = _rep['devices'] is Map ? _rep['devices'] : const {};
    final List campaigns = _rep['campaigns'] is List ? _rep['campaigns'] : const [];

    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'منبع سفارش‌ها',
            sub: 'سهم هر کانال از فروش',
            onBack: () => AppScope.of(context).pop(),
          ),
          Expanded(
            child: _loading
                ? const SlowLoader()
                : _error != null
                    ? _errBody(context, _error!)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            IntrinsicHeight(
                              child: Row(children: [
                                Expanded(
                                    child: _statCard(context, 'سفارش',
                                        Fmt.fa(orders), 'orders')),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'درآمد',
                                        Fmt.tomanShort(revenue), 'coin')),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'پوشش منبع',
                                        '${Fmt.fa(coverage)}٪', 'tag')),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            if (channels.isNotEmpty)
                              _chartCard(
                                  context,
                                  'سهم کانال‌ها (بر اساس سفارش)',
                                  WcpDonut(
                                    centerLabel: 'کانال‌ها',
                                    data: [
                                      for (final ch in channels.take(7))
                                        ChartDatum(
                                            (ch['label'] ?? ch['key'] ?? '')
                                                .toString(),
                                            ((ch['orders'] as num?) ?? 0)
                                                .toDouble()),
                                    ],
                                  )),
                            if (devices.isNotEmpty &&
                                devices.values.any((v) => (v as num? ?? 0) > 0))
                              _chartCard(
                                  context,
                                  'دستگاه',
                                  WcpDonut(
                                    size: 140,
                                    data: [
                                      for (final e in devices.entries)
                                        ChartDatum(_dev(e.key.toString()),
                                            ((e.value as num?) ?? 0).toDouble()),
                                    ],
                                  )),
                            if (campaigns.isNotEmpty)
                              WcpCard(
                                pad: 0,
                                child: Column(children: [
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                                    child: Text('کمپین‌ها',
                                        style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  for (int i = 0;
                                      i < campaigns.length;
                                      i++) ...[
                                    if (i > 0) Divider(height: 1, color: c.line),
                                    _campRow(
                                        context,
                                        Map<String, dynamic>.from(
                                            campaigns[i] as Map)),
                                  ],
                                ]),
                              ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _dev(String k) {
    switch (k) {
      case 'Mobile':
        return 'موبایل';
      case 'Tablet':
        return 'تبلت';
      case 'Desktop':
        return 'دسکتاپ';
      default:
        return 'نامشخص';
    }
  }

  Widget _campRow(BuildContext context, Map<String, dynamic> m) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Text((m['campaign'] ?? '—').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text('${Fmt.fa((m['orders'] as num?)?.toInt() ?? 0)} سفارش',
            style: TextStyle(fontSize: 11.5, color: c.tx3)),
        const SizedBox(width: 10),
        Text(Fmt.tomanShort((m['revenue'] as num?) ?? 0),
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
