// ════════════════════════════════════════════════════════════════
// audience.dart — «مخاطبان» analytics data view (Wave 2).
//
// The DATA half of the Audience module (settings = its modcfg). Reads the
// module's own capability-gated REST (woocommerce-plus/v1/audience/*, opted
// into ck/cs auth via app-rest optin_wc_auth) and charts it with fl_chart:
//   /audience/kpis · /devices · /sources · /weekday-visits · /conversion-rate
//   · /gender · /age-buckets · /users   (?range=day|week|month)
// Route 'mod_audience'.
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

void registerAudienceScreen() {
  // Data view is the primary card; settings reached via the gear on it.
  kScreens['mod_audience'] = (ctx, p) => const AudienceScreen();
  kScreens['mod_audience_settings'] = (ctx, p) =>
      const ModuleConfigScreen(id: 'audience', fallbackTitle: 'مخاطبان');
}

class AudienceScreen extends StatefulWidget {
  const AudienceScreen({super.key});
  @override
  State<AudienceScreen> createState() => _AudienceScreenState();
}

class _AudienceScreenState extends State<AudienceScreen> {
  String _range = 'month';
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _kpis = const {};
  List<ChartDatum> _devices = const [];
  List<ChartDatum> _sources = const [];
  List<ChartDatum> _weekday = const [];
  List<ChartDatum> _gender = const [];
  List<ChartDatum> _age = const [];
  List<double> _convRate = const [];
  List<Map<String, dynamic>> _users = const [];

  static const Map<String, String> _ranges = {
    'day': 'روز',
    'week': 'هفته',
    'month': 'ماه',
  };

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
    } else {
      _loading = false;
      _error = 'برای دیدن مخاطبان، فروشگاه را متصل کنید.';
    }
  }

  // {labels:[],series:[]} → List<ChartDatum>
  List<ChartDatum> _ls(StoreResult r) {
    if (!r.ok || r.map['labels'] is! List || r.map['series'] is! List) {
      return const [];
    }
    final List labels = r.map['labels'] as List;
    final List series = r.map['series'] as List;
    final List<ChartDatum> out = [];
    for (int i = 0; i < labels.length && i < series.length; i++) {
      out.add(ChartDatum(
          '${labels[i]}', ((series[i] as num?) ?? 0).toDouble()));
    }
    return out;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final Map<String, String> q = {'range': _range};
    try {
      final List<StoreResult> r = await Future.wait([
        StoreApi.wcpGet('/audience/kpis', query: q),
        StoreApi.wcpGet('/audience/devices', query: q),
        StoreApi.wcpGet('/audience/sources', query: q),
        StoreApi.wcpGet('/audience/weekday-visits', query: q),
        StoreApi.wcpGet('/audience/conversion-rate', query: q),
        StoreApi.wcpGet('/audience/gender', query: q),
        StoreApi.wcpGet('/audience/age-buckets', query: q),
        StoreApi.wcpGet('/audience/users', query: {'range': _range, 'per_page': '10'}),
      ]);
      if (!mounted) return;
      if (!r[0].ok) {
        setState(() {
          _loading = false;
          _error = r[0].error ?? 'دریافت اطلاعات مخاطبان ناموفق بود.';
        });
        return;
      }
      final dynamic conv = r[4].map['series'];
      final dynamic uitems = r[7].map['items'];
      setState(() {
        _kpis = r[0].map;
        _devices = _ls(r[1]);
        _sources = _ls(r[2]);
        _weekday = _ls(r[3]);
        _convRate = conv is List
            ? conv.map((e) => ((e as num?) ?? 0).toDouble()).toList()
            : const [];
        _gender = _ls(r[5]);
        _age = _ls(r[6]);
        _users = uitems is List
            ? uitems
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : const [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'دریافت اطلاعات مخاطبان ناموفق بود.';
      });
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
            title: 'مخاطبان',
            sub: 'تحلیل بازدیدکنندگان و کاربران',
            onBack: () => AppScope.of(context).pop(),
            actions: [
              IconBtnRaw(
                onClick: () =>
                    AppScope.of(context).push('mod_audience_settings'),
                child: const WcpIcon('settings', size: 20),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const SlowLoader()
                : _error != null
                    ? _err(c)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            _rangeChips(c),
                            const SizedBox(height: 14),
                            _kpiRow(context),
                            const SizedBox(height: 14),
                            _chartCard(context, 'تفکیک دستگاه',
                                WcpDonut(data: _devices, size: 150)),
                            _chartCard(context, 'منبع ورود',
                                WcpDonut(data: _sources, size: 150)),
                            _chartCard(context, 'بازدید بر حسب روز هفته',
                                WcpBars(data: _weekday)),
                            _chartCard(
                                context, 'نرخ تبدیل روزانه', WcpLine(values: _convRate)),
                            if (_gender.isNotEmpty)
                              _chartCard(context, 'جنسیت',
                                  WcpDonut(data: _gender, size: 140)),
                            if (_age.isNotEmpty)
                              _chartCard(
                                  context, 'گروه سنی', WcpBars(data: _age)),
                            const SizedBox(height: 4),
                            _usersCard(context),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _err(AppColors c) => ListView(children: [
        const SizedBox(height: 70),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.tx2, height: 1.8, fontSize: 13.5)),
        ),
      ]);

  Widget _rangeChips(AppColors c) => Row(
        children: [
          for (final e in _ranges.entries) ...[
            if (e.key != _ranges.keys.first) const SizedBox(width: 8),
            Expanded(
              child: WcpChip(
                active: _range == e.key,
                onClick: () {
                  if (_range == e.key) return;
                  setState(() => _range = e.key);
                  _load();
                },
                child: Text(e.value),
              ),
            ),
          ],
        ],
      );

  Widget _kpiRow(BuildContext context) {
    final int totalUsers = (_kpis['total_users'] as num?)?.toInt() ?? 0;
    final Map top = _kpis['top_customer'] is Map ? _kpis['top_customer'] : const {};
    final Map reg = _kpis['registrations'] is Map ? _kpis['registrations'] : const {};
    final int regCur = (reg['current'] as num?)?.toInt() ?? 0;
    final num? pct = reg['pct'] as num?;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
              child: _kpi(context, 'کل کاربران', Fmt.fa(totalUsers), 'users')),
          const SizedBox(width: 10),
          Expanded(
              child: _kpi(
                  context,
                  'بهترین مشتری',
                  (top['name'] ?? '—').toString(),
                  'crown',
                  sub: top['revenue'] != null
                      ? Fmt.tomanShort(top['revenue'] as num)
                      : null)),
          const SizedBox(width: 10),
          Expanded(
              child: _kpi(context, 'ثبت‌نام', Fmt.fa(regCur), 'growth',
                  sub: pct != null
                      ? '${pct >= 0 ? '+' : ''}${Fmt.fa(pct.round())}٪'
                      : null)),
        ],
      ),
    );
  }

  Widget _kpi(BuildContext context, String label, String value, String icon,
      {String? sub}) {
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
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.tx2)),
            ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10.5, color: c.tx3)),
        ],
      ),
    );
  }

  Widget _chartCard(BuildContext context, String title, Widget chart) {
    return Padding(
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
  }

  Widget _usersCard(BuildContext context) {
    final c = context.c;
    if (_users.isEmpty) return const SizedBox.shrink();
    return WcpCard(
      pad: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text('تازه‌ترین کاربران',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
          for (int i = 0; i < _users.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.line),
            _userRow(context, _users[i]),
          ],
        ],
      ),
    );
  }

  Widget _userRow(BuildContext context, Map<String, dynamic> u) {
    final c = context.c;
    final bool online = u['online'] == true;
    final bool blocked = u['blocked'] == true;
    final Map orders = u['orders'] is Map ? u['orders'] : const {};
    final int oc = (orders['count'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: online ? c.success : c.tx3, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text((u['name'] ?? '—').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          if (blocked)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('مسدود',
                  style: TextStyle(fontSize: 11, color: c.error)),
            ),
          Text('$oc سفارش', style: TextStyle(fontSize: 11.5, color: c.tx3)),
        ],
      ),
    );
  }
}
