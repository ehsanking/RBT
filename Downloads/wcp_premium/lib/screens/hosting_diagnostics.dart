// ════════════════════════════════════════════════════════════════
// hosting_diagnostics.dart — «عیب‌یابی هاستینگ» (server/PHP + perf + health +
// security tests). Read-only DATA view of WooPlus_Hosting_Diagnostics_Module:
//   GET  /app/hosting       → grouped metrics {label,value,status,risk,recommend}
//   POST /app/hosting/run   → schedule a fresh async run
// Reached from a «هاست» action on the health/security screen.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../core/icons.dart';
import '../nav/shell.dart';
import '../services/store_api.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'registry.dart';

void registerHostingDiagnosticsScreen() {
  kScreens['mod_hosting_diagnostics'] =
      (ctx, p) => const HostingDiagnosticsScreen();
}

class HostingDiagnosticsScreen extends StatefulWidget {
  const HostingDiagnosticsScreen({super.key});
  @override
  State<HostingDiagnosticsScreen> createState() =>
      _HostingDiagnosticsScreenState();
}

class _HostingDiagnosticsScreenState extends State<HostingDiagnosticsScreen> {
  bool _loading = true;
  bool _pending = false;
  String? _error;
  Map<String, dynamic> _groups = const <String, dynamic>{};
  Map<String, dynamic> _titles = const <String, dynamic>{};

  static const List<String> _order = <String>[
    'server',
    'performance',
    'health',
    'security'
  ];

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
    } else {
      _loading = false;
      _error = 'برای عیب‌یابی هاستینگ، فروشگاه را متصل کنید.';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final StoreResult r = await StoreApi.appHosting();
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() {
        _loading = false;
        _error = (r.map['message'] ?? r.error ?? 'دریافت اطلاعات ناموفق بود.')
            .toString();
      });
      return;
    }
    setState(() {
      _pending = r.map['pending'] == true;
      _groups = r.map['groups'] is Map
          ? Map<String, dynamic>.from(r.map['groups'] as Map)
          : const <String, dynamic>{};
      _titles = r.map['titles'] is Map
          ? Map<String, dynamic>.from(r.map['titles'] as Map)
          : const <String, dynamic>{};
      _loading = false;
    });
  }

  Future<void> _run() async {
    final nav = AppScope.of(context);
    final StoreResult r = await StoreApi.hostingRun();
    if (!mounted) return;
    nav.showToast(
        (r.map['message'] ?? r.error ?? 'زمان‌بندی شد').toString(),
        kind: r.ok ? 'success' : 'error',
        icon: r.ok ? 'check' : 'alert');
  }

  ({Color fg, Color bg, String fa}) _status(String s, AppColors c) {
    switch (s) {
      case 'warning':
        return (fg: c.warning, bg: c.warningSoft, fa: 'هشدار');
      case 'error':
        return (fg: c.error, bg: c.bg3, fa: 'خطا');
      default:
        return (fg: c.success, bg: c.successSoft, fa: 'خوب');
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
            title: 'عیب‌یابی هاستینگ',
            sub: 'سرور، عملکرد، سلامت و امنیت',
            onBack: () => AppScope.of(context).pop(),
            actions: [
              IconBtnRaw(
                onClick: _run,
                child: const WcpIcon('refresh', size: 20),
              ),
            ],
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
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            if (_pending)
                              WcpCard(
                                pad: 16,
                                child: Column(
                                  children: [
                                    WcpIcon('clock', size: 26, color: c.accent),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'آزمون‌ها در حال اجراست',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'کمی بعد این صفحه را بکشید تا تازه شود.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: c.tx3,
                                          height: 1.7),
                                    ),
                                  ],
                                ),
                              )
                            else
                              for (final String g in _order)
                                if ((_groups[g] as List?)?.isNotEmpty ?? false)
                                  _groupCard(context, g),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(BuildContext context, String key) {
    final c = context.c;
    final List items = (_groups[key] as List?) ?? const <dynamic>[];
    final String title = (_titles[key] ?? key).toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WcpCard(
        pad: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
            ),
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.line),
              _row(context, Map<String, dynamic>.from(items[i] as Map)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> m) {
    final c = context.c;
    final st = _status((m['status'] ?? 'success').toString(), c);
    final String label = (m['label'] ?? '').toString();
    final String value = (m['value'] ?? '').toString();
    final String recommend = (m['recommend'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    if (value.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(value,
                          style: TextStyle(fontSize: 12, color: c.tx2)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: st.bg, borderRadius: BorderRadius.circular(999)),
                child: Text(st.fa,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: st.fg)),
              ),
            ],
          ),
          if (recommend.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(recommend,
                style: TextStyle(fontSize: 11.5, color: c.tx3, height: 1.6)),
          ],
        ],
      ),
    );
  }
}
