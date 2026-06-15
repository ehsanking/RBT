// ════════════════════════════════════════════════════════════════
// home.dart — Dashboard tab (KPIs, sales chart, alerts, analytics,
// heatmap, store health). Ported pixel-perfect from screens-home.jsx.
//
// Local-only widgets that the JSX pulls from charts.jsx / states.jsx
// (Sparkline · LineChart · Donut · Heatmap · DashSkeleton) are ported
// privately here — they are not part of the shared ui.dart contract.
//
// Route registered: 'home' → HomeScreen (the tab-root key).
// Navigation targets used by the dashboard (search / notifications /
// customers / supportHub / tickets / comments / qna / mod_wallet /
// mod_coupon / assistant / mod_cache) are owned by other screen files;
// unknown ones degrade to the shell's "صفحه در دست ساخت" placeholder.
// ════════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/icons.dart';
import '../core/jalali.dart';
import '../data/models.dart';
import '../data/sample.dart';
import '../data/woo_map.dart';
import '../nav/shell.dart';
import '../services/store_api.dart';
import '../theme/tokens.dart';
import '../widgets/jalali_range_picker.dart';
import '../widgets/ui.dart';
import 'registry.dart';

/// Local-midnight ISO «YYYY-MM-DDTHH:MM:SS» for the WC analytics after/before
/// params (no timezone suffix — WC treats it as site-local).
String _isoLocal(DateTime d) {
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${p2(d.month)}-${p2(d.day)}'
      'T${p2(d.hour)}:${p2(d.minute)}:${p2(d.second)}';
}

// ════════════════════════════════════════════════════════════════
// HomeScreen — the dashboard.
// ════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _range = 'week';
  // Manual date range from the Jalali picker (ISO strings). When both are set
  // and `_range == 'custom'`, `_loadData` uses these instead of a preset.
  String? _customAfter;
  String? _customBefore;
  String? _customLabel; // «۱ تیر تا ۱۵ تیر ۱۴۰۵» for the chip/toast.
  // Skeleton stays up until the FIRST real fetch resolves — no sample flash.
  late bool _loading;
  // null = data ok; 'net' = fetch failed; 'store' = no store connected.
  String? _error;
  // «مرکز هشدار» needs a real alerts feed; kept off (never a sample) until one
  // is wired, so the dashboard never shows fabricated alerts.
  final bool _showAlerts = false;

  // Live dashboard data — seeded with the sample set so the screen looks
  // right offline / before the first fetch resolves, then swapped for the
  // connected store's analytics when available.
  List<Kpi> _kpis = sampleKpis;
  SalesChart _chart = sampleSalesChart;
  num _salesTotal = 184500000;
  double _salesDelta = 12.4;
  List<TopProduct> _top = sampleTopProducts;

  // Extended analytics (heatmap / category / device / health) — seeded with
  // the sample set, swapped for the BI endpoint's data when reachable.
  List<List<double>> _heatmap = sampleHeatmap;
  List<CategoryShare> _categoryShare = sampleCategoryShare;
  List<DeviceSplit> _deviceSplit = sampleDeviceSplit;
  List<StoreHealth> _health = sampleStoreHealth;

  // Support-shortcut badge counts — sample seed, replaced with the real
  // open-ticket / pending-Q&A figures from appOverview() when connected.
  // (Comments has no overview field, so it stays 0 when connected.)
  int _supTickets = 0;
  int _supComments = 0;
  int _supQna = 0;

  static const List<({String value, String label})> _ranges = [
    (value: 'today', label: 'امروز'),
    (value: 'week', label: 'هفته'),
    (value: 'month', label: 'ماه'),
    (value: 'year', label: 'سال'),
  ];

  @override
  void initState() {
    super.initState();
    // No sample flash: show the skeleton until the first REAL fetch resolves.
    _loading = StoreApi.hasStore;
    if (!StoreApi.hasStore) _error = 'store';
    _loadData(initial: true);
  }

  /// Pull live dashboard analytics from the connected store and replace the
  /// sample KPIs / sales chart / top products. Best-effort: a missing store
  /// or any failed call leaves the sample data in place (no error surfaced —
  /// the dashboard always shows *something*).
  Future<void> _loadData({bool initial = false}) async {
    if (!StoreApi.hasStore) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'store';
        });
      }
      return;
    }
    final ({
      String after,
      String before,
      String prevAfter,
      String prevBefore,
      String interval,
    }) r;
    if (_range == 'custom' && _customAfter != null && _customBefore != null) {
      // Manual range (Jalali picker). Previous window = the same-length span
      // immediately before it, so the KPI delta arrows stay meaningful.
      final DateTime a = DateTime.parse(_customAfter!);
      final DateTime b = DateTime.parse(_customBefore!);
      final Duration span = b.difference(a);
      final DateTime pa = a.subtract(span + const Duration(seconds: 1));
      r = (
        after: _customAfter!,
        before: _customBefore!,
        prevAfter: _isoLocal(pa),
        prevBefore: _customAfter!,
        interval: 'day',
      );
    } else {
      r = StoreApi.periodRange(_range);
    }

    final List<StoreResult> res = await Future.wait(<Future<StoreResult>>[
      StoreApi.revenueStats(
          after: r.after, before: r.before, interval: r.interval),
      StoreApi.revenueStats(
          after: r.prevAfter, before: r.prevBefore, interval: r.interval),
      StoreApi.customersStats(
          after: r.after, before: r.before, interval: r.interval),
      StoreApi.customersStats(
          after: r.prevAfter, before: r.prevBefore, interval: r.interval),
      StoreApi.productsTotal(),
      StoreApi.topProductsReport(after: r.after, before: r.before),
      StoreApi.dashboardExtras(_range),
      StoreApi.appOverview(),
    ]);
    if (!mounted) return;

    // Support-shortcut badges from the WC+ overview (open tickets +
    // pending Q&A). Comments has no overview field → 0 when connected.
    final StoreResult ov = res[7];
    if (ov.ok && ov.map['available'] != false) {
      final Map<String, dynamic> m = ov.map;
      final Map<String, dynamic> tk = m['tickets'] is Map
          ? Map<String, dynamic>.from(m['tickets'] as Map)
          : const <String, dynamic>{};
      final Map<String, dynamic> qa = m['qa'] is Map
          ? Map<String, dynamic>.from(m['qa'] as Map)
          : const <String, dynamic>{};
      _supTickets = int.tryParse('${tk['open']}') ?? 0;
      _supQna = int.tryParse('${qa['pending']}') ?? 0;
      _supComments = 0;
    }

    final StoreResult cur = res[0];
    if (!cur.ok) {
      // Always clear the loading skeleton (set when the range was switched);
      // on the very first load surface an error (never a sample), on a
      // range-change failure keep whatever data is already on screen.
      if (mounted) {
        setState(() {
          _loading = false;
          if (initial) _error = 'net';
        });
      }
      return;
    }

    final DashboardData d = dashboardFromWoo(
      cur: cur.map,
      prev: res[1].ok ? res[1].map : const <String, dynamic>{},
      custCur: res[2].ok ? res[2].map : const <String, dynamic>{},
      custPrev: res[3].ok ? res[3].map : const <String, dynamic>{},
      productCount: res[4].ok ? res[4].total : 0,
      topRows: res[5].ok ? res[5].list : const <Map<String, dynamic>>[],
    );

    // Extended analytics from the WC+ BI endpoint (res[6]). Independent
    // best-effort: each list only replaces its sample when the endpoint
    // returns data, so a missing endpoint / empty section keeps the sample.
    final StoreResult ex = res[6];
    final List<List<double>> heat =
        ex.ok ? heatmapFromWoo(ex.map['heatmap']) : const <List<double>>[];
    final List<CategoryShare> cats =
        ex.ok ? categorySharesFromWoo(ex.map['category']) : const <CategoryShare>[];
    final List<DeviceSplit> devs =
        ex.ok ? deviceSplitsFromWoo(ex.map['device']) : const <DeviceSplit>[];
    final List<StoreHealth> health =
        ex.ok ? storeHealthFromWoo(ex.map['health']) : const <StoreHealth>[];

    // Real store display name (WP REST root) for the dashboard header / switcher.
    await StoreApi.fetchStoreInfo();
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = null;
      _kpis = d.kpis;
      _salesTotal = d.salesTotal;
      _salesDelta = d.salesDelta;
      _chart = d.chart;
      _top = d.top;
      // Extended analytics take whatever the BI endpoint returned — empty when
      // unavailable, so the matching section is HIDDEN (see build) instead of
      // ever falling back to a sample.
      _heatmap = heat;
      _categoryShare = cats;
      _deviceSplit = devs;
      _health = health;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    if (_loading) {
      return Scaffold(
        backgroundColor: c.bg0,
        body: const _DashSkeleton(),
      );
    }

    // Connected-but-failed / not-connected → a clear message + retry, NEVER a
    // sample dashboard (production rule: no fake data ever shown).
    if (_error != null) {
      final bool noStore = _error == 'store';
      return Scaffold(
        backgroundColor: c.bg0,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.error.withAlpha(0x1F),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    noStore ? Icons.link_off_rounded : Icons.wifi_off_rounded,
                    color: c.error,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  noStore
                      ? 'به فروشگاهی متصل نیستید'
                      : 'دریافت اطلاعات ناموفق بود',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  noStore
                      ? 'برای نمایش داشبورد، ابتدا فروشگاه را متصل کنید.'
                      : 'اتصال اینترنت یا فروشگاه برقرار نشد. دوباره تلاش کنید.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.7, color: c.tx3),
                ),
                const SizedBox(height: 20),
                _Tap(
                  onTap: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _loadData(initial: true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'تلاش مجدد',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header (sticky, blurred over bg0) ──────────────────
          _Header(),
          // ── Scrolling content ──────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _gapCol([
                    // Range filter row.
                    Row(
                      children: [
                        Expanded(
                          child: Segmented(
                            options: _ranges,
                            value: _range,
                            onChange: (v) {
                              if (v == _range) return;
                              // Show the same loading skeleton as the first load
                              // while the new period's data is fetched, so the
                              // dashboard never shows stale numbers for the just-
                              // tapped range.
                              setState(() {
                                _range = v;
                                _loading = true;
                                _error = null;
                              });
                              _loadData();
                            },
                            full: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconBtn(
                          name: 'calendar',
                          onClick: () async {
                            final (DateTime, DateTime)? range =
                                await showJalaliRangePicker(context);
                            if (range == null || !mounted) return;
                            final List<int> ja = Jalali.toJalali(
                                range.$1.year, range.$1.month, range.$1.day);
                            final List<int> jb = Jalali.toJalali(
                                range.$2.year, range.$2.month, range.$2.day);
                            if (!context.mounted) return;
                            setState(() {
                              _range = 'custom';
                              _customAfter = _isoLocal(range.$1);
                              _customBefore = _isoLocal(range.$2);
                              _customLabel =
                                  '${Fmt.fa(ja[2])} ${Jalali.months[ja[1] - 1]} تا '
                                  '${Fmt.fa(jb[2])} ${Jalali.months[jb[1] - 1]} ${Fmt.fa(jb[0])}';
                              _loading = true;
                              _error = null;
                            });
                            AppScope.of(context).showToast(
                              'بازه: $_customLabel',
                              kind: 'info',
                              icon: 'calendar',
                            );
                            _loadData();
                          },
                        ),
                      ],
                    ),

                    // KPI grid (2 columns, gap 11).
                    _kpiGrid(context),

                    // Sales chart card.
                    _salesCard(context),

                    // Alert center — only when a real alerts feed is wired.
                    if (_showAlerts) _alertCenter(context),

                    // Support & engagement shortcut.
                    _supportShortcut(context),

                    // Shortcuts grid.
                    _shortcuts(context),

                    // Top products — only when there are real sales to list.
                    if (_top.isNotEmpty) _topProducts(context),

                    // Category + device split — only when the BI endpoint
                    // returned real data (hidden otherwise, never a sample).
                    if (_categoryShare.isNotEmpty || _deviceSplit.isNotEmpty)
                      _splitRow(context),

                    // Heatmap — only when real activity data is available.
                    if (_heatmap.isNotEmpty)
                      WcpCard(
                        pad: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHead(title: 'ساعات پرفروش (۷×۲۴)'),
                            _Heatmap(data: _heatmap),
                          ],
                        ),
                      ),

                    // Store health — only when the BI endpoint returned it.
                    if (_health.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _storeHealth(context),
                      ),
                  ], 18),
                  // Bottom breathing room above the tab bar. The shell now folds
                  // the tab-bar reserve (kTabBarReserve = 66) into the injected
                  // `padding.bottom`, so this is just home's extra visual gap on
                  // top of that — keeping the same overall spacing as before.
                  SizedBox(
                    height: 26 + MediaQuery.of(context).padding.bottom,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI grid ───────────────────────────────────────────────────
  Widget _kpiGrid(BuildContext context) {
    VoidCallback tapFor(Kpi k) {
      final scope = AppScope.of(context);
      switch (k.id) {
        case 'customers':
          return () => scope.push('customers');
        case 'orders':
          return () => scope.goTab('orders');
        case 'active':
          return () => scope.goTab('products');
        default:
          // Sales/revenue KPI → the orders tab (where the revenue originates).
          return () => scope.goTab('orders');
      }
    }

    return _Grid2(
      gap: 11,
      children: [
        for (final k in _kpis) _KpiCard(k: k, onClick: tapFor(k)),
      ],
    );
  }

  // ── Sales chart ────────────────────────────────────────────────
  Widget _salesCard(BuildContext context) {
    final c = context.c;
    return WcpCard(
      pad: 16,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فروش این هفته',
                        style: TextStyle(fontSize: 13, color: c.tx3),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          Fmt.toman(_salesTotal),
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Delta(value: _salesDelta, size: 13),
              ],
            ),
          ),
          // Legend.
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                _legendItem(c.accent, 'دورهٔ جاری', c.tx2),
                const SizedBox(width: 16),
                _legendItem(c.tx3, 'دورهٔ قبل', c.tx3),
              ],
            ),
          ),
          _LineChart(
            labels: _chart.labels,
            current: _chart.current,
            previous: _chart.previous,
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color swatch, String label, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: swatch,
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11.5, color: textColor)),
      ],
    );
  }

  // ── Alert center ───────────────────────────────────────────────
  Widget _alertCenter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHead(
          title: 'مرکز هشدار',
          action: 'همه',
          onAction: () => AppScope.of(context).push('notifications'),
        ),
        _gapCol([
          for (final a in sampleAlerts) _AlertCard(alert: a),
        ], 9),
      ],
    );
  }

  // ── Support & engagement shortcut ──────────────────────────────
  Widget _supportShortcut(BuildContext context) {
    final c = context.c;
    final scope = AppScope.of(context);

    final int supportTotal = _supTickets + _supComments + _supQna;
    final items = [
      (label: 'تیکت باز', count: _supTickets, go: 'tickets'),
      (label: 'نظر جدید', count: _supComments, go: 'comments'),
      (label: 'پرسش', count: _supQna, go: 'qna'),
    ];

    return WcpCard(
      pad: 0,
      onClick: () => scope.push('supportHub'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top row.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              child: Row(
                children: [
                  // Inbox chip with floating error badge.
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.accentSoft,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: WcpIcon('inbox', size: 23, color: c.accentText),
                        ),
                        Positioned(
                          top: -5,
                          left: -5,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.error,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: c.bg1, width: 2),
                            ),
                            child: Text(
                              Fmt.fa(supportTotal),
                              style: const TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'پشتیبانی و تعامل',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'تیکت باز، نظر و پرسش در انتظار پاسخ',
                            style: TextStyle(fontSize: 12, color: c.tx3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 13),
                  WcpIcon('chevronL', size: 18, color: c.tx3),
                ],
              ),
            ),
            // Footer stat row (3 cells split by dividers).
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.line, width: 1)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _Tap(
                          onTap: () => scope.push(items[i].go),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: i > 0
                                    ? BorderSide(color: c.line, width: 1)
                                    : BorderSide.none,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 11),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  Fmt.fa(items[i].count),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: c.accentText,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  items[i].label,
                                  style:
                                      TextStyle(fontSize: 11, color: c.tx3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shortcuts grid (4 columns) ─────────────────────────────────
  Widget _shortcuts(BuildContext context) {
    final c = context.c;
    final scope = AppScope.of(context);

    final shortcuts = <({String icon, String label, Color color, VoidCallback go})>[
      (icon: 'orders', label: 'سفارش‌ها', color: c.info, go: () => scope.goTab('orders')),
      (icon: 'wallet', label: 'کیف پول', color: c.accent, go: () => scope.push('mod_wallet')),
      (icon: 'coupon', label: 'تخفیف', color: c.warning, go: () => scope.push('mod_coupon')),
      (icon: 'sparkles', label: 'دستیار', color: c.success, go: () => scope.push('assistant')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHead(title: 'میانبرها'),
        _Grid(
          columns: 4,
          gap: 10,
          children: [
            for (final s in shortcuts)
              _Tap(
                onTap: s.go,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.bg1,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s.color.withAlpha(0x22),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: WcpIcon(s.icon, size: 21, color: s.color),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: c.tx2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Top products card ──────────────────────────────────────────
  Widget _topProducts(BuildContext context) {
    final c = context.c;
    final top4 = _top.take(4).toList();
    return WcpCard(
      pad: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHead(
            title: 'پرفروش‌ترین‌ها',
            action: 'همهٔ محصولات',
            onAction: () => AppScope.of(context).goTab('products'),
          ),
          _gapCol([
            for (var i = 0; i < top4.length; i++)
              Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      Fmt.fa(i + 1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: i == 0 ? c.accentText : c.tx3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Avatar(name: top4[i].name, sq: true, size: 40, color: _hex(top4[i].img)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          top4[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${Fmt.fa(top4[i].sold)} فروش',
                          style: TextStyle(fontSize: 11.5, color: c.tx3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    Fmt.tomanShort(top4[i].revenue),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.tx2,
                    ),
                  ),
                ],
              ),
          ], 13),
        ],
      ),
    );
  }

  // ── Category split + device split (2 columns) ──────────────────
  Widget _splitRow(BuildContext context) {
    final c = context.c;
    return _Grid2(
      gap: 11,
      children: [
        // Category share (donut).
        WcpCard(
          pad: 15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'سهم دسته‌بندی',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
              Center(
                child: _Donut(
                  data: [
                    for (final cs in _categoryShare)
                      (value: cs.value, color: _hex(cs.color)),
                  ],
                  size: 120,
                  sw: 18,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Fmt.fa(5),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('دسته',
                          style: TextStyle(fontSize: 10, color: c.tx3)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _gapCol([
                  for (final cs in _categoryShare.take(3))
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _hex(cs.color),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cs.name,
                            style: TextStyle(fontSize: 11.5, color: c.tx2),
                          ),
                        ),
                        Text(
                          '${Fmt.fa(cs.value)}٪',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                ], 5),
              ),
            ],
          ),
        ),

        // Device split (bars) + online pill.
        WcpCard(
          pad: 15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'تفکیک دستگاه',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
              _gapCol([
                for (final d in _deviceSplit)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                d.label,
                                style:
                                    TextStyle(fontSize: 12, color: c.tx2),
                              ),
                            ),
                            Text(
                              '${Fmt.fa(d.value)}٪',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Bar(value: d.value.toDouble(), color: _hex(d.color), h: 7),
                    ],
                  ),
              ], 14),
            ],
          ),
        ),
      ],
    );
  }

  // ── Store health (2 columns) ───────────────────────────────────
  Widget _storeHealth(BuildContext context) {
    final c = context.c;
    return WcpCard(
      pad: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHead(
            title: 'سلامت فروشگاه',
            action: 'جزئیات',
            onAction: () => AppScope.of(context).push('mod_cache'),
          ),
          _Grid2(
            gap: 11,
            children: [
              for (final h in _health)
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Ring(
                        value: h.score.toDouble(),
                        size: 44,
                        sw: 5,
                        color: h.status == 'good' ? c.success : c.warning,
                        child: WcpIcon(
                          h.icon,
                          size: 17,
                          color: h.status == 'good' ? c.success : c.warning,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              h.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              h.detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: c.tx3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Header — store switcher button + search + bell (sticky, blurred).
// JSX: paddingTop calc(sa-top+8), pad calc(sa-top+8) 18 14, bg0, blur12.
// ════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final topPad = MediaQuery.of(context).padding.top;
    final scope = AppScope.of(context);

    final bar = Container(
      padding: EdgeInsets.fromLTRB(18, topPad + 8, 18, 14),
      color: c.bg0,
      child: Row(
        children: [
          // Store switcher trigger.
          Expanded(
            child: _Tap(
              onTap: () => _openStoreSwitcher(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Avatar(
                    name: StoreApi.storeName ?? StoreApi.siteHost ?? 'فروشگاه شما',
                    imageUrl: StoreApi.storeLogo, // site_icon_url → real logo, falls back to initials
                    sq: true,
                    size: 42,
                    color: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'فروشگاه فعال',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    TextStyle(fontSize: 11.5, color: c.tx3),
                              ),
                            ),
                            const SizedBox(width: 3),
                            WcpIcon('chevronD', size: 13, color: c.tx3),
                          ],
                        ),
                        Text(
                          StoreApi.storeName ?? StoreApi.siteHost ?? 'فروشگاه شما',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.tx1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 11),
          // Theme switch — the «پوسته» settings row points here («از کنترل
          // بالای صفحه قابل تغییر است»). Shows sun in dark mode, moon in light.
          IconBtn(
            name: Theme.of(context).brightness == Brightness.dark
                ? 'sun'
                : 'moon',
            onClick: () => scope.toggleTheme(),
          ),
          const SizedBox(width: 11),
          IconBtn(name: 'search', onClick: () => scope.push('search')),
          const SizedBox(width: 11),
          IconBtn(
            name: 'bell',
            onClick: () => scope.push('notifications'),
          ),
        ],
      ),
    );

    // backdropFilter: blur(12) — pinned header sits atop scrolled content.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: bar,
      ),
    );
  }

  void _openStoreSwitcher(BuildContext context) {
    showWcpSheet<void>(
      context,
      title: 'فروشگاه‌های من',
      child: _StoreSwitcherBody(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// StoreSwitcher — bottom-sheet body listing STORES + add button.
// ════════════════════════════════════════════════════════════════
class _StoreSwitcherBody extends StatefulWidget {
  @override
  State<_StoreSwitcherBody> createState() => _StoreSwitcherBodyState();
}

class _StoreSwitcherBodyState extends State<_StoreSwitcherBody> {
  String _hostOf(String url) =>
      url.replaceFirst(RegExp(r'^https?://'), '').replaceAll('/', '');

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final scope = AppScope.of(context);
    final List<Map<String, dynamic>> stores = StoreApi.stores;
    final String? activeUrl = StoreApi.siteUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in stores) ...[
          () {
            final String url = (s['url'] ?? '').toString();
            final bool active = url == activeUrl;
            final String host = _hostOf(url);
            final String name = (s['name'] ?? '').toString().trim().isNotEmpty
                ? (s['name'] as String)
                : (active
                    ? (StoreApi.storeName ?? host)
                    : (host.isNotEmpty ? host : 'فروشگاه'));
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Tap(
                onTap: active
                    ? () => Navigator.of(context).pop()
                    : () async {
                        await StoreApi.switchTo(url);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: active ? c.accentSoft : c.bg1,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: active ? c.accentLine : c.line, width: 1),
                  ),
                  child: Row(
                    children: [
                      Avatar(name: name, imageUrl: active ? StoreApi.storeLogo : null, sq: true, size: 46, color: const Color(0xFF7C3AED)),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                            if (host.isNotEmpty)
                              Text(host,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, color: c.tx3)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (active)
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: c.accent, shape: BoxShape.circle),
                          child: const WcpIcon('check',
                              size: 15, sw: 2.5, color: Color(0xFFFFFFFF)),
                        )
                      else
                        IconBtn(
                          name: 'trash',
                          onClick: () async {
                            await StoreApi.removeStore(url);
                            if (mounted) setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          }(),
        ],
        const SizedBox(height: 2),
        WcpButton(
          label: 'افزودن فروشگاه',
          variant: 'soft',
          icon: 'plus',
          full: true,
          onClick: () {
            Navigator.of(context).pop();
            scope.push('addStore');
          },
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// KpiCard — chip + delta + big number + label + sparkline.
// JSX: Card pad 14. icon box 34×34 r11 accentSoft/accentText icon 19.
// value fs21 w800 mt12 (-.02em). label fs12 tx3 mt2. sparkline mt8.
// ════════════════════════════════════════════════════════════════
class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.k, required this.onClick});
  final Kpi k;
  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final up = k.delta >= 0;
    return WcpCard(
      pad: 14,
      onClick: onClick,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: WcpIcon(k.icon, size: 19, color: c.accentText),
              ),
              const Spacer(),
              Delta(value: k.delta),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              k.kind == 'money' ? Fmt.tomanShort(k.value) : Fmt.fa(k.value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.42, // -.02em of 21
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              k.label,
              style: TextStyle(fontSize: 12, color: c.tx3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Sparkline(
              data: k.spark,
              fill: true,
              w: 120,
              h: 26,
              color: up ? c.accent : c.error,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AlertCard — soft-tinted icon chip + title/detail + colored action.
// JSX: Card pad13 row gap12. chip 40×40 r12 soft/c icon21. title fs14
// w700. detail fs12 tx3 ellipsis. action fs12 w700 c nowrap.
// a1→products, else→orders.
// ════════════════════════════════════════════════════════════════
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = c.kind(alert.type); // error|warning|info
    final soft = c.kindSoft(alert.type);
    return WcpCard(
      pad: 13,
      onClick: () => AppScope.of(context)
          .push(alert.id == 'a1' ? 'products' : 'orders'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: WcpIcon(alert.icon, size: 21, color: col),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alert.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  alert.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(fontSize: 12, color: c.tx3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            alert.action,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: col,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Sparkline — area-fill + line + end dot. Ported from charts.jsx.
//   pts: x = i/(n-1)*w ; y = h - ((v-min)/rng)*(h-4) - 2
//   line stroke 2 round; area = line + L(w,h) L(0,h) Z ; gradient .28→0
// ════════════════════════════════════════════════════════════════
class _Sparkline extends StatelessWidget {
  const _Sparkline({
    required this.data,
    this.color,
    this.w = 70,
    this.h = 28,
    this.fill = false,
  });

  final List<int> data;
  final Color? color;
  final double w;
  final double h;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final col = color ?? context.c.accent;
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _SparklinePainter(data: data, color: col, fill: fill),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.data,
    required this.color,
    required this.fill,
  });

  final List<int> data;
  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (data.isEmpty) return;

    int maxV = data.first, minV = data.first;
    for (final v in data) {
      if (v > maxV) maxV = v;
      if (v < minV) minV = v;
    }
    final rng = (maxV - minV) == 0 ? 1 : (maxV - minV);
    final n = data.length;

    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(
          n == 1 ? 0 : i / (n - 1) * w,
          h - ((data[i] - minV) / rng) * (h - 4) - 2,
        ),
    ];

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      line.lineTo(pts[i].dx, pts[i].dy);
    }

    if (fill) {
      final area = Path.from(line)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(0x47), color.withAlpha(0)], // .28 → 0
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(area, areaPaint);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(line, stroke);

    canvas.drawCircle(
      pts.last,
      2.6,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color || old.fill != fill || !_sameList(old.data, data);
}

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ════════════════════════════════════════════════════════════════
// LineChart — dual-series area + line (current vs previous).
// Ported from charts.jsx. viewBox w320 h170, padX8 padTop14 padBot26.
//   max = max(all)*1.12, min=0
//   gridlines at .25/.5/.75/1 (dash 2 4, line color)
//   previous: tx3 dashed 4 4 sw2 opacity .7
//   current : accent sw2.6 round + dots (last r4 w/ 2px bg1 stroke)
//   labels  : fs10 tx3 centered at y=h-6
// ════════════════════════════════════════════════════════════════
class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.labels,
    required this.current,
    required this.previous,
  });

  final List<String> labels;
  final List<int> current;
  final List<int> previous;
  final double height = 170;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // viewBox is 320×170; render full-width preserving the aspect ratio
    // (JSX svg width=100%, height follows viewBox).
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = w * (height / 320);
        return SizedBox(
          width: w,
          height: h,
          child: CustomPaint(
            painter: _LineChartPainter(
              labels: labels,
              current: current,
              previous: previous,
              vbW: 320,
              vbH: height,
              accent: c.accent,
              tx3: c.tx3,
              line: c.line,
              bg1: c.bg1,
            ),
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.labels,
    required this.current,
    required this.previous,
    required this.vbW,
    required this.vbH,
    required this.accent,
    required this.tx3,
    required this.line,
    required this.bg1,
  });

  final List<String> labels;
  final List<int> current;
  final List<int> previous;
  final double vbW;
  final double vbH;
  final Color accent;
  final Color tx3;
  final Color line;
  final Color bg1;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale the 320×vbH viewBox onto the actual size.
    final sx = size.width / vbW;
    final sy = size.height / vbH;
    canvas.save();
    canvas.scale(sx, sy);

    const padX = 8.0, padTop = 14.0, padBot = 26.0;
    final h = vbH;
    final w = vbW;

    final all = <int>[...current, ...previous];
    var maxAll = all.isEmpty ? 0 : all.first;
    for (final v in all) {
      if (v > maxAll) maxAll = v;
    }
    final maxV = maxAll * 1.12;
    const minV = 0.0;
    final span = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    double xAt(int i) =>
        padX + (current.length <= 1 ? 0 : i / (current.length - 1)) * (w - padX * 2);
    double yAt(num v) => padTop + (1 - (v - minV) / span) * (h - padTop - padBot);

    // Gridlines (dashed 2 4).
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line;
    for (final g in const [0.25, 0.5, 0.75, 1.0]) {
      final y = padTop + g * (h - padTop - padBot);
      _dashedLine(
          canvas, Offset(padX, y), Offset(w - padX, y), gridPaint, 2, 4);
    }

    // Current area fill (accent .30 → 0).
    final areaPath = Path()..moveTo(xAt(0), yAt(current.first));
    for (var i = 1; i < current.length; i++) {
      areaPath.lineTo(xAt(i), yAt(current[i]));
    }
    areaPath
      ..lineTo(xAt(current.length - 1), yAt(0))
      ..lineTo(xAt(0), yAt(0))
      ..close();
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent.withAlpha(0x4D), accent.withAlpha(0)], // .30 → 0
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(areaPath, areaPaint);

    // Previous line (dashed 4 4, tx3, sw2, opacity .7).
    final prevPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = tx3.withAlpha(0xB3); // opacity .7
    for (var i = 0; i < previous.length - 1; i++) {
      _dashedLine(
        canvas,
        Offset(xAt(i), yAt(previous[i])),
        Offset(xAt(i + 1), yAt(previous[i + 1])),
        prevPaint,
        4,
        4,
      );
    }

    // Current line (accent, sw2.6, round).
    final curPath = Path()..moveTo(xAt(0), yAt(current.first));
    for (var i = 1; i < current.length; i++) {
      curPath.lineTo(xAt(i), yAt(current[i]));
    }
    canvas.drawPath(
      curPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accent,
    );

    // Current dots (last = r4 with 2px bg1 ring, else r2.4).
    for (var i = 0; i < current.length; i++) {
      final p = Offset(xAt(i), yAt(current[i]));
      final last = i == current.length - 1;
      if (last) {
        canvas.drawCircle(p, 4 + 1, Paint()..color = bg1); // ring (2px each side)
      }
      canvas.drawCircle(p, last ? 4 : 2.4, Paint()..color = accent);
    }

    // X-axis labels (fs10 tx3 centered at y=h-6).
    for (var i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontFamily: T.family,
            fontSize: 10,
            color: tx3,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(canvas, Offset(xAt(i) - tp.width / 2, (h - 6) - tp.height));
    }

    canvas.restore();
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      double dash, double gap) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    double dist = 0;
    while (dist < total) {
      final start = a + dir * dist;
      final end = a + dir * math.min(dist + dash, total);
      canvas.drawLine(start, end, paint);
      dist += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.accent != accent ||
      old.tx3 != tx3 ||
      old.line != line ||
      old.bg1 != bg1 ||
      !_sameList(old.current, current) ||
      !_sameList(old.previous, previous);
}

// ════════════════════════════════════════════════════════════════
// Donut — segmented ring + centered child. Ported from charts.jsx.
//   r = (size - sw)/2 ; segments: butt cap, fraction of circumference.
//   JSX rotates -90° + scaleX(-1): start at top, sweep COUNTER-clockwise.
// ════════════════════════════════════════════════════════════════
class _Donut extends StatelessWidget {
  const _Donut({
    required this.data,
    required this.center,
    this.size = 140,
    this.sw = 22,
  });

  final List<({int value, Color color})> data;
  final Widget center;
  final double size;
  final double sw;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(data: data, sw: sw),
          ),
          center,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.data, required this.sw});

  final List<({int value, Color color})> data;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = (size.width - sw) / 2;
    var total = 0;
    for (final d in data) {
      total += d.value;
    }
    if (total <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: r);
    // -90° start, sweep counter-clockwise (scaleX(-1) mirrors direction).
    const startBase = -math.pi / 2;
    var acc = 0.0;
    for (final d in data) {
      final frac = d.value / total;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.butt
        ..color = d.color;
      canvas.drawArc(
        rect,
        startBase - acc * 2 * math.pi,
        -frac * 2 * math.pi,
        false,
        paint,
      );
      acc += frac;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.sw != sw || old.data != data;
}

// ════════════════════════════════════════════════════════════════
// Heatmap — 7 rows (days) × 24 cols (hours). Ported from charts.jsx.
//   day label col 14px fs11 tx3; cells aspect 1, r3, gap 2.5,
//   background = mix(accent v%, bg3). Footer ۰ ۶ ۱۲ ۱۸ ۲۳ (pr20).
// ════════════════════════════════════════════════════════════════
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.data});
  final List<List<double>> data;

  static const List<String> _days = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var di = 0; di < data.length; di++) ...[
          if (di > 0) const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                child: Text(
                  _days[di],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: c.tx3),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    for (var hi = 0; hi < data[di].length; hi++) ...[
                      if (hi > 0) const SizedBox(width: 2.5),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                c.bg3,
                                c.accent,
                                data[di][hi].clamp(0.0, 1.0),
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
        // Footer scale (paddingRight 20 in JSX → in RTL it's the leading edge).
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final t in const ['۰', '۶', '۱۲', '۱۸', '۲۳'])
                Text(t, style: TextStyle(fontSize: 10, color: c.tx3)),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// DashSkeleton — shimmer placeholder matching the dashboard layout.
// Ported from screens-states.jsx.
// ════════════════════════════════════════════════════════════════
class _DashSkeleton extends StatelessWidget {
  const _DashSkeleton();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header skeleton.
        Padding(
          padding: EdgeInsets.fromLTRB(18, topPad + 8, 18, 14),
          child: const Row(
            children: [
              Skel(w: 42, h: 42, r: 13),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Skel(w: 70, h: 10),
                    SizedBox(height: 6),
                    Skel(w: 110, h: 15),
                  ],
                ),
              ),
              SizedBox(width: 11),
              Skel(w: 38, h: 38, r: 12),
              SizedBox(width: 11),
              Skel(w: 38, h: 38, r: 12),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _gapCol([
              const Skel(w: double.infinity, h: 44, r: 13),
              // 4 KPI cards.
              _Grid2(
                gap: 11,
                children: [
                  for (var i = 0; i < 4; i++)
                    const WcpCard(
                      pad: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Skel(w: 34, h: 34, r: 11),
                              Spacer(),
                              Skel(w: 40, h: 16, r: 8),
                            ],
                          ),
                          SizedBox(height: 12),
                          Skel(w: 90, h: 20),
                          SizedBox(height: 6),
                          Skel(w: 60, h: 11),
                          SizedBox(height: 10),
                          Skel(w: double.infinity, h: 26, r: 6),
                        ],
                      ),
                    ),
                ],
              ),
              // Chart card skeleton.
              const WcpCard(
                pad: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Skel(w: 80, h: 11),
                              SizedBox(height: 8),
                              Skel(w: 140, h: 22),
                            ],
                          ),
                        ),
                        Skel(w: 50, h: 16, r: 8),
                      ],
                    ),
                    SizedBox(height: 16),
                    Skel(w: double.infinity, h: 130, r: 12),
                  ],
                ),
              ),
              // 2 alert-row skeletons.
              for (var i = 0; i < 2; i++)
                const WcpCard(
                  pad: 13,
                  child: Row(
                    children: [
                      Skel(w: 40, h: 40, r: 12),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Skel(w: 120, h: 13),
                            SizedBox(height: 7),
                            Skel(w: 160, h: 11),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ], 16),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Small local layout helpers + a tap-scale wrapper (matches ui.jsx
// `.tap` 0.96 press) so cells in this file feel identical to shared ones.
// ════════════════════════════════════════════════════════════════

/// Column with a fixed vertical gap between children (flex gap).
Widget _gapCol(List<Widget> children, double gap) {
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) out.add(SizedBox(height: gap));
    out.add(children[i]);
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: out,
  );
}

/// Equal-width 2-column grid (gridTemplateColumns: 1fr 1fr) with a gap.
/// Children are laid out in rows of two; the last odd child stretches half.
class _Grid2 extends StatelessWidget {
  const _Grid2({required this.children, this.gap = 11});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right = i + 1 < children.length ? children[i + 1] : null;
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            SizedBox(width: gap),
            right == null ? const Spacer() : Expanded(child: right),
          ],
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

/// Fixed N-column grid (repeat(N,1fr)) with a uniform gap.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.children,
    required this.columns,
    this.gap = 10,
  });
  final List<Widget> children;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var col = 0; col < columns; col++) {
        final idx = i + col;
        if (col > 0) cells.add(SizedBox(width: gap));
        cells.add(Expanded(
          child: idx < children.length ? children[idx] : const SizedBox(),
        ));
      }
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cells,
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

/// Press-scale wrapper (JSX `.tap` → scale .96 on press).
class _Tap extends StatefulWidget {
  const _Tap({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Tap> createState() => _TapState();
}

class _TapState extends State<_Tap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: _down ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
    );
    if (widget.onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: child,
    );
  }
}

// ── color helper: parse '#rrggbb' (or '#rgb') → Color ────────────
Color _hex(String s) {
  var h = s.replaceAll('#', '').trim();
  if (h.length == 3) {
    h = h.split('').map((ch) => '$ch$ch').join();
  }
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

// ════════════════════════════════════════════════════════════════
// Route registration.
// ════════════════════════════════════════════════════════════════
void registerHomeScreen() {
  kScreens['home'] = (ctx, p) => const HomeScreen();
}
