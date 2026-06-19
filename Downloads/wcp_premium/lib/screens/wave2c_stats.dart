// ════════════════════════════════════════════════════════════════
// wave2c_stats.dart — last Wave-2 data views:
//   MiniAppStatsScreen  (mod_mini_app)     — per-platform users + sessions + 30d
//   SocialLogScreen     (mod_social_tools) — messenger send log (sent/failed)
// Backed by /app/mini-app/stats · /app/social/log-stats. Reuse charts.dart.
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

void registerWave2cStatsScreens() {
  kScreens['mod_mini_app'] = (ctx, p) => const MiniAppStatsScreen();
  kScreens['mod_mini_app_settings'] = (ctx, p) =>
      const ModuleConfigScreen(id: 'mini-app', fallbackTitle: 'مینی‌اپ');
  kScreens['mod_social_tools'] = (ctx, p) => const SocialLogScreen();
  kScreens['mod_social_tools_settings'] = (ctx, p) => const ModuleConfigScreen(
      id: 'social-tools', fallbackTitle: 'ابزار شبکه اجتماعی');
}

const Map<String, String> _kPlatformFa = {
  'telegram': 'تلگرام',
  'bale': 'بله',
  'rubika': 'روبیکا',
  'eitaa': 'ایتا',
  'whatsapp': 'واتساپ',
  'instagram': 'اینستاگرام',
  'web': 'وب',
  'sms': 'پیامک',
};
String _platFa(String k) => _kPlatformFa[k] ?? (k.isEmpty ? 'نامشخص' : k);

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
// MINI-APP
// ════════════════════════════════════════════════════════════════
class MiniAppStatsScreen extends StatefulWidget {
  const MiniAppStatsScreen({super.key});
  @override
  State<MiniAppStatsScreen> createState() => _MiniAppStatsScreenState();
}

class _MiniAppStatsScreenState extends State<MiniAppStatsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const {};

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
    final StoreResult r = await StoreApi.miniAppStats();
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() {
        _loading = false;
        _error = (r.map['message'] ?? r.error ?? 'دریافت آمار ناموفق بود.').toString();
      });
      return;
    }
    setState(() {
      _data = r.map;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final List platforms = _data['platforms'] is List ? _data['platforms'] : const [];
    final int totalUsers = platforms.fold<int>(
        0, (s, e) => s + (((e as Map)['total'] as num?)?.toInt() ?? 0));
    final int active30 = (_data['recent_active_30d'] as num?)?.toInt() ?? 0;
    final int sessions = (_data['active_sessions'] as num?)?.toInt() ?? 0;
    final int orders30 = (_data['orders_30d'] as num?)?.toInt() ?? 0;
    final num rev30 = (_data['revenue_30d'] as num?) ?? 0;
    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'مینی‌اپ',
            sub: 'کاربران و فعالیت پیام‌رسان‌ها',
            onBack: () => AppScope.of(context).pop(),
            actions: [
              IconBtnRaw(
                onClick: () =>
                    AppScope.of(context).push('mod_mini_app_settings'),
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
                                    child: _statCard(context, 'کل کاربران',
                                        Fmt.fa(totalUsers), 'users')),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'فعال ۳۰روزه',
                                        Fmt.fa(active30), 'online',
                                        color: c.success)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'نشست فعال',
                                        Fmt.fa(sessions), 'clock')),
                              ]),
                            ),
                            const SizedBox(height: 10),
                            IntrinsicHeight(
                              child: Row(children: [
                                Expanded(
                                    child: _statCard(context, 'سفارش ۳۰روزه',
                                        Fmt.fa(orders30), 'orders')),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _statCard(context, 'درآمد ۳۰روزه',
                                        Fmt.tomanShort(rev30), 'coin')),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            if (totalUsers > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: WcpCard(
                                  pad: 14,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text('کاربران بر حسب پیام‌رسان',
                                          style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 12),
                                      WcpDonut(
                                        centerLabel: 'کاربران',
                                        data: [
                                          for (final e in platforms)
                                            ChartDatum(
                                                _platFa(((e as Map)['platform'] ??
                                                        '')
                                                    .toString()),
                                                ((e['total'] as num?) ?? 0)
                                                    .toDouble()),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (platforms.isNotEmpty)
                              WcpCard(
                                pad: 0,
                                child: Column(children: [
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                                    child: Text('متصل به حساب فروشگاه',
                                        style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  for (int i = 0; i < platforms.length; i++) ...[
                                    if (i > 0) Divider(height: 1, color: c.line),
                                    _platRow(context,
                                        Map<String, dynamic>.from(platforms[i])),
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

  Widget _platRow(BuildContext context, Map<String, dynamic> p) {
    final c = context.c;
    final int tot = (p['total'] as num?)?.toInt() ?? 0;
    final int linked = (p['linked'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Text(_platFa((p['platform'] ?? '').toString()),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text('${Fmt.fa(linked)} از ${Fmt.fa(tot)} متصل',
            style: TextStyle(fontSize: 11.5, color: c.tx3)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SOCIAL TOOLS — send log.
// ════════════════════════════════════════════════════════════════
class SocialLogScreen extends StatefulWidget {
  const SocialLogScreen({super.key});
  @override
  State<SocialLogScreen> createState() => _SocialLogScreenState();
}

class _SocialLogScreenState extends State<SocialLogScreen> {
  int _days = 30;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const {};

  static const Map<int, String> _periods = {7: '۷ روز', 30: '۳۰ روز', 90: '۹۰ روز'};

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
    final StoreResult r = await StoreApi.socialLogStats(days: _days);
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() {
        _loading = false;
        _error = (r.map['message'] ?? r.error ?? 'دریافت آمار ناموفق بود.').toString();
      });
      return;
    }
    setState(() {
      _data = r.map;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final int sent = (_data['total_sent'] as num?)?.toInt() ?? 0;
    final int failed = (_data['total_failed'] as num?)?.toInt() ?? 0;
    final int total = sent + failed;
    final int rate = total > 0 ? ((sent / total) * 100).round() : 0;
    final Map byPlat = _data['by_platform'] is Map ? _data['by_platform'] : const {};
    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'ابزار شبکه اجتماعی',
            sub: 'گزارش ارسال پیام‌ها',
            onBack: () => AppScope.of(context).pop(),
            actions: [
              IconBtnRaw(
                onClick: () =>
                    AppScope.of(context).push('mod_social_tools_settings'),
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
                                    child: _statCard(context, 'ارسال موفق',
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
                                        '${Fmt.fa(rate)}٪', 'gauge')),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            if (total > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: WcpCard(
                                  pad: 14,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text('موفق در برابر ناموفق',
                                          style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 12),
                                      WcpDonut(
                                        size: 140,
                                        data: [
                                          ChartDatum('موفق', sent.toDouble(),
                                              c.success),
                                          ChartDatum('ناموفق', failed.toDouble(),
                                              c.error),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (byPlat.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text('در این بازه پیامی ارسال نشده است.',
                                      style: TextStyle(
                                          fontSize: 12.5, color: c.tx3)),
                                ),
                              )
                            else
                              WcpCard(
                                pad: 0,
                                child: Column(children: [
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                                    child: Text('بر حسب پیام‌رسان',
                                        style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  for (final entry in byPlat.entries) ...[
                                    _platRow(context, entry.key.toString(),
                                        entry.value is Map
                                            ? Map<String, dynamic>.from(
                                                entry.value)
                                            : const {}),
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

  Widget _platRow(BuildContext context, String plat, Map<String, dynamic> v) {
    final c = context.c;
    final int s = (v['sent'] as num?)?.toInt() ?? 0;
    final int f = (v['failed'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Text(_platFa(plat),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text('${Fmt.fa(s)} موفق',
            style: TextStyle(fontSize: 11.5, color: c.success)),
        const SizedBox(width: 10),
        Text('${Fmt.fa(f)} ناموفق',
            style: TextStyle(fontSize: 11.5, color: f > 0 ? c.error : c.tx3)),
      ]),
    );
  }
}
