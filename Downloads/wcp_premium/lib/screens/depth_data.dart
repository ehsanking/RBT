// ════════════════════════════════════════════════════════════════
// depth_data.dart — two read-only "depth" data views that complete the
// settings+data pair for modules whose dashboards were action-only:
//   B2bCustomersScreen      (mod_b2b_customers)      — credit accounts
//   SubscriptionPlansScreen (mod_subscription_plans) — plans + MRR
// Backed by /app/b2b/customers · /app/subscription/plans.
// Reached from the gear/extra action on the B2B-approvals and
// subscription-members dashboards.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/icons.dart';
import '../nav/shell.dart';
import '../services/store_api.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';
import 'dashboards.dart' show statusPill;
import 'registry.dart';

void registerDepthDataScreens() {
  kScreens['mod_b2b_customers'] = (ctx, p) => const B2bCustomersScreen();
  kScreens['mod_subscription_plans'] = (ctx, p) =>
      const SubscriptionPlansScreen();
}

// Robust numeric parse — WordPress `$wpdb` returns numeric columns as
// STRINGS ("199000"), so a plain `as num` cast throws. Accept num|String|null.
num _n(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim()) ?? 0;
  return 0;
}

// Shared bits (file-local copies of the wave2 helpers) ────────────────
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
// B2B CUSTOMERS — credit accounts (limit / balance / available).
// ════════════════════════════════════════════════════════════════
class B2bCustomersScreen extends StatefulWidget {
  const B2bCustomersScreen({super.key});
  @override
  State<B2bCustomersScreen> createState() => _B2bCustomersScreenState();
}

class _B2bCustomersScreenState extends State<B2bCustomersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _totals = const {};

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
    } else {
      _loading = false;
      _error = 'برای دیدن حساب‌های عمده‌فروشی، فروشگاه را متصل کنید.';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final StoreResult r = await StoreApi.b2bCustomers();
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() {
        _loading = false;
        _error =
            (r.map['message'] ?? r.error ?? 'دریافت اطلاعات ناموفق بود.')
                .toString();
      });
      return;
    }
    setState(() {
      _items = r.map['items'] is List
          ? (r.map['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [];
      _totals = r.map['totals'] is Map
          ? Map<String, dynamic>.from(r.map['totals'])
          : const {};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final int count =
        _totals['count'] != null ? _n(_totals['count']).toInt() : _items.length;
    final num outstanding = _n(_totals['outstanding']);
    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'حساب‌های عمده‌فروشی',
            sub: 'اعتبار و بدهی مشتریان',
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
                                    child: _statCard(context, 'مشتری',
                                        Fmt.fa(count), 'users')),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(
                                        context,
                                        'مجموع بدهی',
                                        Fmt.tomanShort(outstanding),
                                        'wallet',
                                        color: outstanding > 0
                                            ? c.warning
                                            : c.success)),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            if (_items.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 28),
                                child: Center(
                                  child: Text(
                                      'هنوز حساب اعتباری عمده‌فروشی ثبت نشده است.',
                                      textAlign: TextAlign.center,
                                      style:
                                          TextStyle(fontSize: 13, color: c.tx3)),
                                ),
                              )
                            else
                              for (final m in _items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _accCard(context, m),
                                ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _accCard(BuildContext context, Map<String, dynamic> m) {
    final c = context.c;
    final int limit = _n(m['credit_limit']).toInt();
    final int bal = _n(m['balance']).toInt();
    final int avail = _n(m['available']).toInt();
    final int terms = _n(m['net_terms_days']).toInt();
    final String status = (m['status'] ?? 'active').toString();
    final double frac = limit > 0 ? (bal / limit).clamp(0.0, 1.0) : 0.0;
    final Color barColor =
        frac >= 0.9 ? c.error : (frac >= 0.6 ? c.warning : c.success);
    final ({Color fg, Color bg}) st = status == 'active'
        ? (fg: c.success, bg: c.successSoft)
        : (fg: c.tx3, bg: c.bg3);
    return WcpCard(
      pad: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((m['name'] ?? m['email'] ?? '—').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              statusPill(
                  status == 'active' ? 'فعال' : 'غیرفعال', st.fg, st.bg),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 7,
              backgroundColor: c.bg3,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _kv(context, 'سقف اعتبار', Fmt.toman(limit))),
            Expanded(
                child: _kv(context, 'بدهی', Fmt.toman(bal),
                    color: bal > 0 ? c.warning : null)),
            Expanded(
                child: _kv(context, 'قابل استفاده', Fmt.toman(avail),
                    color: c.success)),
          ]),
          if (terms > 0) ...[
            const SizedBox(height: 8),
            Text('مهلت تسویه: ${Fmt.fa(terms)} روز',
                style: TextStyle(fontSize: 11.5, color: c.tx3)),
          ],
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value, {Color? color}) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: c.tx3)),
        const SizedBox(height: 2),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SUBSCRIPTION PLANS — plans, prices, member counts, MRR.
// ════════════════════════════════════════════════════════════════
class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});
  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  num _mrr = 0;

  static const Map<String, String> _period = {
    'day': 'روزانه',
    'week': 'هفتگی',
    'month': 'ماهانه',
    'year': 'سالانه',
  };

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
    } else {
      _loading = false;
      _error = 'برای دیدن طرح‌های اشتراک، فروشگاه را متصل کنید.';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final StoreResult r = await StoreApi.subscriptionPlans();
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() {
        _loading = false;
        _error =
            (r.map['message'] ?? r.error ?? 'دریافت اطلاعات ناموفق بود.')
                .toString();
      });
      return;
    }
    setState(() {
      _items = r.map['items'] is List
          ? (r.map['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [];
      _mrr = _n(r.map['mrr']);
      _loading = false;
    });
  }

  String _periodLabel(Map<String, dynamic> p) {
    final String base = _period[(p['billing_period'] ?? 'month').toString()] ??
        'ماهانه';
    final int every = p['billing_interval'] != null
        ? _n(p['billing_interval']).toInt()
        : 1;
    if (every > 1) {
      final String unit = {
            'day': 'روز',
            'week': 'هفته',
            'month': 'ماه',
            'year': 'سال',
          }[(p['billing_period'] ?? 'month').toString()] ??
          'ماه';
      return 'هر ${Fmt.fa(every)} $unit';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final int totalMembers = _items.fold<int>(
        0, (s, p) => s + _n(p['member_count']).toInt());
    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'طرح‌های اشتراک',
            sub: 'قیمت، اعضا و درآمد ماهانه',
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
                                    child: _statCard(context, 'طرح',
                                        Fmt.fa(_items.length), 'tag')),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'کل اعضا',
                                        Fmt.fa(totalMembers), 'users')),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'درآمد ماهانه',
                                        Fmt.tomanShort(_mrr), 'coin',
                                        color: c.success)),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            if (_items.length >= 2 && totalMembers > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: WcpCard(
                                  pad: 14,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text('سهم اعضا از طرح‌ها',
                                          style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 12),
                                      WcpDonut(
                                        centerLabel: 'اعضا',
                                        data: [
                                          for (final p in _items)
                                            if (_n(p['member_count']) > 0)
                                              ChartDatum(
                                                  (p['name'] ?? '—').toString(),
                                                  _n(p['member_count'])
                                                      .toDouble()),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_items.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 28),
                                child: Center(
                                  child: Text(
                                      'هنوز طرح اشتراکی تعریف نشده است.',
                                      textAlign: TextAlign.center,
                                      style:
                                          TextStyle(fontSize: 13, color: c.tx3)),
                                ),
                              )
                            else
                              for (final p in _items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _planCard(context, p),
                                ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context, Map<String, dynamic> p) {
    final c = context.c;
    final num price = _n(p['price']);
    final int members = _n(p['member_count']).toInt();
    final int trial = _n(p['trial_days']).toInt();
    final String status = (p['status'] ?? 'active').toString();
    final ({Color fg, Color bg}) st = status == 'active'
        ? (fg: c.success, bg: c.successSoft)
        : (fg: c.tx3, bg: c.bg3);
    return WcpCard(
      pad: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text((p['name'] ?? '—').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            statusPill(
                status == 'active' ? 'فعال' : 'غیرفعال', st.fg, st.bg),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            WcpIcon('coin', size: 13, color: c.tx3),
            const SizedBox(width: 5),
            Text(price > 0 ? Fmt.toman(price) : 'رایگان',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text('· ${_periodLabel(p)}',
                style: TextStyle(fontSize: 12, color: c.tx3)),
            const Spacer(),
            WcpIcon('users', size: 13, color: c.accent),
            const SizedBox(width: 5),
            Text('${Fmt.fa(members)} عضو',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.accent)),
          ]),
          if (trial > 0) ...[
            const SizedBox(height: 8),
            Text('دوره آزمایشی: ${Fmt.fa(trial)} روز',
                style: TextStyle(fontSize: 11.5, color: c.tx3)),
          ],
        ],
      ),
    );
  }
}
