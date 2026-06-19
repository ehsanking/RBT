// ════════════════════════════════════════════════════════════════
// product_analytics.dart — «تحلیل محصول» dashboard (#7).
//
// Read-only product-performance view. App-only: the WC+ product-analytics
// module exposes capability-gated (no-nonce) REST under
//   GET woocommerce-plus/v1/product-analytics/kpis
//   GET woocommerce-plus/v1/product-analytics/top-products
// which the app reaches via StoreApi.wcpGet. These live OUTSIDE the /app
// namespace, so the plugin's optin_wc_auth() must opt the
// `woocommerce-plus/v1/product-analytics` prefix into WooCommerce
// consumer-key auth — otherwise ck/cs requests are unauthenticated and
// manage_woocommerce fails («شما اجازه این کار را ندارید»). Surfaced by the
// grid card «تحلیل محصول».
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/icons.dart';
import '../services/store_api.dart';
import '../nav/shell.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';
import 'registry.dart';

void registerProductAnalyticsScreen() {
  kScreens['mod_product_analytics'] =
      (ctx, p) => const ProductAnalyticsScreen();
}

class ProductAnalyticsScreen extends StatefulWidget {
  const ProductAnalyticsScreen({super.key});
  @override
  State<ProductAnalyticsScreen> createState() => _ProductAnalyticsScreenState();
}

class _ProductAnalyticsScreenState extends State<ProductAnalyticsScreen> {
  int _days = 30; // 7 | 30 | 90
  bool _loading = true;
  String? _error;

  num _revenue = 0;
  int _orders = 0;
  num _aov = 0;
  Map<String, dynamic>? _topProduct;
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  List<double> _revSeries = const <double>[]; // daily store revenue (time-series)

  static const Map<int, String> _periods = <int, String>{
    7: '۷ روز',
    30: '۳۰ روز',
    90: '۹۰ روز',
  };

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
    } else {
      _loading = false;
      _error = 'برای دیدن تحلیل، فروشگاه را متصل کنید.';
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final DateTime now = DateTime.now();
    final Map<String, String> range = <String, String>{
      'date_start': _fmtDate(now.subtract(Duration(days: _days))),
      'date_end': _fmtDate(now),
    };
    final List<StoreResult> res = await Future.wait(<Future<StoreResult>>[
      StoreApi.wcpGet('/product-analytics/kpis', query: range),
      StoreApi.wcpGet('/product-analytics/top-products',
          query: <String, String>{...range, 'limit': '12'}),
      // store-wide daily revenue trend (no product_id) for the line chart.
      StoreApi.wcpGet('/product-analytics/time-series', query: range),
    ]);
    if (!mounted) return;
    final StoreResult kpi = res[0];
    final StoreResult top = res[1];
    final StoreResult ts = res[2];
    if (!kpi.ok && !top.ok) {
      setState(() {
        _loading = false;
        _error = kpi.error ?? 'دریافت تحلیل ناموفق بود.';
      });
      return;
    }
    setState(() {
      _revenue = (kpi.map['total_revenue'] as num?) ?? 0;
      _orders = (kpi.map['total_orders'] as num?)?.toInt() ?? 0;
      _aov = (kpi.map['average_order_value'] as num?) ?? 0;
      _topProduct = kpi.map['top_product'] is Map
          ? Map<String, dynamic>.from(kpi.map['top_product'] as Map)
          : null;
      final dynamic items = top.map['items'];
      _items = items is List
          ? items
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const <Map<String, dynamic>>[];
      final dynamic series = ts.ok ? ts.map['series'] : null;
      _revSeries = series is List
          ? series.map((e) => ((e as num?) ?? 0).toDouble()).toList()
          : const <double>[];
      _loading = false;
    });
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
            title: 'تحلیل محصول',
            sub: 'عملکرد فروش محصولات',
            onBack: () => AppScope.of(context).pop(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // period selector
                  Row(
                    children: [
                      for (final MapEntry<int, String> e in _periods.entries) ...[
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
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.accent),
                        ),
                      ),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13.5, color: c.tx2, height: 1.7)),
                      ),
                    )
                  else ...[
                    // KPI grid
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                              child: _kpi(context, 'درآمد',
                                  Fmt.tomanShort(_revenue), 'coin')),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _kpi(context, 'سفارش', Fmt.fa(_orders),
                                  'orders')),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _kpi(context, 'میانگین سفارش',
                                  Fmt.tomanShort(_aov), 'chart')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Daily store-revenue trend.
                    if (_revSeries.length >= 2) ...[
                      WcpCard(
                        pad: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('روند درآمد روزانه',
                                style: TextStyle(
                                    fontSize: 13.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            WcpLine(values: _revSeries),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (_topProduct != null)
                      WcpCard(
                        pad: 14,
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: c.accentSoft,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child:
                                  WcpIcon('crown', size: 18, color: c.accent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('پرفروش‌ترین محصول',
                                      style: TextStyle(
                                          fontSize: 11.5, color: c.tx3)),
                                  const SizedBox(height: 2),
                                  Text(
                                    Fmt.htmlDecode(
                                        (_topProduct!['name'] ?? '').toString()),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Fmt.tomanShort(
                                  (_topProduct!['revenue'] as num?) ?? 0),
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.accent),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),

                    const Padding(
                      padding: EdgeInsets.only(right: 2, bottom: 8),
                      child: Text('پرفروش‌ترین محصولات',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                    if (_items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('در این بازه فروشی ثبت نشده است.',
                              style: TextStyle(fontSize: 12.5, color: c.tx3)),
                        ),
                      )
                    else ...[
                      // Top-products revenue bars (rank-labelled to stay readable).
                      WcpCard(
                        pad: 14,
                        child: WcpBars(
                          data: [
                            for (final m in _items.take(6))
                              ChartDatum(
                                Fmt.fa((m['rank'] as num?)?.toInt() ?? 0),
                                ((m['revenue'] as num?) ?? 0).toDouble()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      WcpCard(
                        pad: 0,
                        child: Column(
                          children: [
                            for (int i = 0; i < _items.length; i++) ...[
                              if (i > 0) Divider(height: 1, color: c.line),
                              _row(context, _items[i]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(BuildContext context, String label, String value, String icon) {
    final c = context.c;
    return WcpCard(
      pad: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          WcpIcon(icon, size: 16, color: c.accent),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: c.tx3)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> m) {
    final c = context.c;
    final int rank = (m['rank'] as num?)?.toInt() ?? 0;
    final int qty = (m['purchases'] as num?)?.toInt() ?? 0;
    final num rev = (m['revenue'] as num?) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(Fmt.fa(rank),
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: c.tx2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              Fmt.htmlDecode((m['name'] ?? '').toString()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Fmt.tomanShort(rev),
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${Fmt.fa(qty)} فروش',
                  style: TextStyle(fontSize: 10.5, color: c.tx3)),
            ],
          ),
        ],
      ),
    );
  }
}
