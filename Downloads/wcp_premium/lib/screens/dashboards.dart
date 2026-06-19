// ════════════════════════════════════════════════════════════════
// dashboards.dart — operational dashboards (wave 4) for the modules whose
// merchant workflow lives beyond a settings form:
//   mod_bookings   → رزرو/نوبت‌دهی (reservation list + confirm/cancel/done)
//   mod_rmas       → مرجوعی (returns: approve/reject/received/refund)
//   mod_campaigns  → کمپین پیامکی (SMS blast list + create + cancel)
//   mod_affiliates → همکاری در فروش (referral earnings + mark paid)
//   mod_subscription_members → اعضای اشتراک (read-only)
//   mod_b2b_approvals        → تایید عمده‌فروشی (pending registrations)
//
// All share [ModuleListDashboard] — a paginated, status-filtered list with
// per-row actions, pull-to-refresh, and load/error/empty states. Backed by
// the /app/* REST added in class-wooplus-app-rest.php.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/fmt.dart';
import '../core/icons.dart';
import '../core/jalali.dart';
import '../nav/shell.dart';
import '../services/store_api.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'module_config.dart';
import 'registry.dart';

void registerDashboardsScreen() {
  // Reached from the «قابلیت‌های فروشگاه» rows, which push modcfg_<id>.
  kScreens['modcfg_bookings'] = (ctx, p) => const BookingsScreen();
  // Booking SETTINGS (global reminders + closed days) — the other half of the
  // module: reached from the gear on BookingsScreen. Data view = list above;
  // config view = the curated schema form for module id 'booking'.
  kScreens['mod_bookings_settings'] = (ctx, p) => const ModuleConfigScreen(
      id: 'booking', fallbackTitle: 'رزرو و نوبت‌دهی');
  // Affiliate settings (program on/off, rate %, cookie days) — gear on the
  // affiliate dashboard. (RMA + campaign have no module-level merchant settings
  // — RMA config is dev filters, campaign config is per-blast in the create
  // sheet — so they stay data-only.)
  kScreens['mod_affiliates_settings'] = (ctx, p) => const ModuleConfigScreen(
      id: 'affiliate', fallbackTitle: 'همکاری در فروش');
  kScreens['modcfg_rmas'] = (ctx, p) => const RmasScreen();
  kScreens['modcfg_campaigns'] = (ctx, p) => const CampaignsScreen();
  kScreens['modcfg_affiliates'] = (ctx, p) => const AffiliatesScreen();
  kScreens['modcfg_subscription_members'] =
      (ctx, p) => const SubscriptionMembersScreen();
  kScreens['modcfg_b2b_approvals'] = (ctx, p) => const B2bApprovalsScreen();
}

typedef DashFetch = Future<StoreResult> Function(int page, String status);
typedef DashRowBuilder = Widget Function(
    BuildContext ctx, Map<String, dynamic> row, Future<void> Function() reload);
typedef DashHeaderBuilder = Widget? Function(
    BuildContext ctx, Map<String, dynamic> meta);

// ── shared status-badge pill ─────────────────────────────────────
Widget statusPill(String label, Color fg, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );

/// Jalali day label from a 'Y-m-d' (or ISO) string.
String jalaliDay(String raw) {
  if (raw.isEmpty) return '';
  final DateTime? dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (dt == null) return raw;
  final List<int> j = Jalali.toJalali(dt.year, dt.month, dt.day);
  return '${Fmt.fa(j[2])} ${Jalali.months[j[1] - 1]} ${Fmt.fa(j[0])}';
}

/// Run a row action: await it, toast the result, reload on success.
Future<void> runAction(
  BuildContext context,
  Future<StoreResult> future,
  Future<void> Function() reload, {
  String okIcon = 'check',
}) async {
  final StoreResult r = await future;
  if (!context.mounted) return;
  final bool ok = r.ok && r.map['ok'] == true;
  final String msg =
      (r.map['message'] ?? r.error ?? (ok ? 'انجام شد' : 'اقدام ناموفق بود'))
          .toString();
  AppScope.of(context).showToast(msg,
      kind: ok ? 'success' : 'error', icon: ok ? okIcon : 'alert');
  if (ok && context.mounted) await reload();
}

// ════════════════════════════════════════════════════════════════
// ModuleListDashboard — the shared paginated list scaffold.
// ════════════════════════════════════════════════════════════════
class ModuleListDashboard extends StatefulWidget {
  const ModuleListDashboard({
    super.key,
    required this.title,
    this.sub,
    required this.fetch,
    required this.itemBuilder,
    this.statusFilters = const <({String key, String label})>[],
    this.headerBuilder,
    this.emptyTitle = 'موردی یافت نشد',
    this.emptyMessage,
    this.emptyIcon = 'inbox',
    this.fabBuilder,
    this.appBarActions,
  });

  final String title;
  final String? sub;
  final DashFetch fetch;
  final DashRowBuilder itemBuilder;
  final List<({String key, String label})> statusFilters;
  final DashHeaderBuilder? headerBuilder;
  final String emptyTitle;
  final String? emptyMessage;
  final String emptyIcon;
  final Widget? Function(BuildContext, Future<void> Function())? fabBuilder;
  final List<Widget>? appBarActions;

  @override
  State<ModuleListDashboard> createState() => _ModuleListDashboardState();
}

class _ModuleListDashboardState extends State<ModuleListDashboard> {
  bool _loading = true;
  bool _more = false;
  String? _error;
  String _status = '';
  int _page = 1;
  bool _hasMore = false;
  Map<String, dynamic> _meta = const <String, dynamic>{};
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load(reset: true);
    } else {
      _loading = false;
      _error = 'برای دیدن این بخش، فروشگاه را متصل کنید.';
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      setState(() => _more = true);
    }
    final StoreResult r = await widget.fetch(_page, _status);
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      final String msg =
          (r.map['message'] ?? r.error ?? 'دریافت اطلاعات ناموفق بود.').toString();
      if (reset) {
        setState(() {
          _loading = false;
          _more = false;
          _error = msg;
        });
      } else {
        // A failed «load more» keeps the already-loaded list intact; roll back
        // the page counter + surface a toast instead of wiping the screen.
        setState(() {
          if (_page > 1) _page -= 1;
          _more = false;
        });
        AppScope.of(context).showToast(msg, kind: 'error', icon: 'alert');
      }
      return;
    }
    final dynamic items = r.map['items'];
    final List<Map<String, dynamic>> page = items is List
        ? items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const <Map<String, dynamic>>[];
    setState(() {
      if (reset) _items.clear();
      _items.addAll(page);
      _meta = r.map;
      _hasMore = r.map['has_more'] == true;
      _loading = false;
      _more = false;
    });
  }

  Future<void> _reload() => _load(reset: true);

  void _setStatus(String s) {
    if (_status == s) return;
    setState(() => _status = s);
    _load(reset: true);
  }

  Future<void> _loadMore() async {
    if (_more || !_hasMore) return;
    _page += 1;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg0,
      floatingActionButton: (_error == null && widget.fabBuilder != null)
          ? widget.fabBuilder!(context, _reload)
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: widget.title,
            sub: widget.sub,
            onBack: () => AppScope.of(context).pop(),
            actions: widget.appBarActions,
          ),
          if (widget.statusFilters.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    for (final f in widget.statusFilters) ...[
                      WcpChip(
                        active: _status == f.key,
                        onClick: () => _setStatus(f.key),
                        child: Text(f.label),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          Expanded(child: _body(c)),
        ],
      ),
    );
  }

  Widget _body(AppColors c) {
    if (_loading) return const SlowLoader();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(icon: 'alert', title: 'خطا', message: _error),
        ),
      );
    }
    final Widget? header = widget.headerBuilder?.call(context, _meta);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          children: [
            if (header != null)
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: header),
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: EmptyState(
                  icon: widget.emptyIcon,
                  title: widget.emptyTitle,
                  message: widget.emptyMessage),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          if (header != null) ...[header, const SizedBox(height: 12)],
          for (final Map<String, dynamic> row in _items) ...[
            widget.itemBuilder(context, row, _reload),
            const SizedBox(height: 10),
          ],
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: WcpButton(
                variant: 'secondary',
                label: _more ? 'در حال بارگذاری…' : 'بیشتر',
                full: true,
                disabled: _more,
                onClick: _loadMore,
              ),
            ),
        ],
      ),
    );
  }
}

// ── small shared helpers for rows ────────────────────────────────
Widget _kvLine(AppColors c, String label, String value, {bool ltr = false}) {
  return Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: c.tx3)),
        const SizedBox(width: 6),
        Expanded(
          child: Directionality(
            textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    ),
  );
}

Future<void> _dial(BuildContext context, String phone) async {
  final String n = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (n.isEmpty) {
    AppScope.of(context)
        .showToast('شماره‌ای ثبت نشده است.', kind: 'info', icon: 'phone');
    return;
  }
  await launchUrl(Uri.parse('tel:$n'), mode: LaunchMode.externalApplication);
}

// ════════════════════════════════════════════════════════════════
// 1) BOOKINGS — رزرو/نوبت‌دهی (priority)
// ════════════════════════════════════════════════════════════════
class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  static const List<({String key, String label})> _filters = [
    (key: '', label: 'همه'),
    (key: 'pending', label: 'در انتظار تایید'),
    (key: 'awaiting_payment', label: 'در انتظار پرداخت'),
    (key: 'confirmed', label: 'تاییدشده'),
    (key: 'done', label: 'انجام‌شده'),
    (key: 'cancelled', label: 'لغوشده'),
  ];

  ({Color fg, Color bg}) _color(String s, AppColors c) {
    switch (s) {
      case 'confirmed':
        return (fg: c.success, bg: c.successSoft);
      case 'done':
        return (fg: c.info, bg: c.infoSoft);
      case 'awaiting_payment':
        return (fg: c.warning, bg: c.warningSoft);
      case 'cancelled':
        return (fg: c.tx3, bg: c.bg3);
      default:
        return (fg: c.accent, bg: c.accentSoft);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModuleListDashboard(
      title: 'رزرو و نوبت‌دهی',
      sub: 'فهرست نوبت‌ها',
      statusFilters: _filters,
      emptyTitle: 'نوبتی نیست',
      emptyMessage: 'برای این فیلتر نوبتی ثبت نشده است.',
      emptyIcon: 'calendar',
      fetch: (page, status) => StoreApi.bookings(page: page, status: status),
      itemBuilder: (ctx, row, reload) => _row(ctx, row, reload),
      appBarActions: [
        IconBtnRaw(
          onClick: () => AppScope.of(context).push('mod_booking_services'),
          child: const WcpIcon('calendar', size: 20),
        ),
        IconBtnRaw(
          onClick: () => AppScope.of(context).push('mod_bookings_settings'),
          child: const WcpIcon('settings', size: 20),
        ),
      ],
    );
  }

  Widget _row(
      BuildContext ctx, Map<String, dynamic> row, Future<void> Function() reload) {
    final c = ctx.c;
    final String status = (row['status'] ?? '').toString();
    final String phone = (row['phone'] ?? '').toString();
    final int id = (row['id'] as num?)?.toInt() ?? 0;
    final String amountFmt = (row['amount_fmt'] ?? '').toString();
    final st = _color(status, c);
    final bool actable =
        status == 'pending' || status == 'awaiting_payment' || status == 'confirmed';

    return WcpCard(
      pad: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((row['customer'] ?? 'مشتری').toString().trim(),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              statusPill(
                  (row['status_label'] ?? status).toString(), st.fg, st.bg),
            ],
          ),
          if ((row['service_name'] ?? '').toString().isNotEmpty)
            _kvLine(c, 'خدمت:', (row['service_name']).toString()),
          _kvLine(c, 'زمان:',
              '${jalaliDay((row['date'] ?? '').toString())} · ${Fmt.fa((row['time'] ?? '').toString())}'),
          if (phone.isNotEmpty) _kvLine(c, 'تماس:', Fmt.fa(phone), ltr: true),
          if (amountFmt.isNotEmpty)
            _kvLine(c, 'مبلغ:', amountFmt, ltr: true),
          if (actable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (status == 'pending' || status == 'awaiting_payment')
                  Expanded(
                    child: WcpButton(
                      variant: 'primary',
                      icon: 'check',
                      label: 'تایید',
                      full: true,
                      onClick: () => runAction(
                          ctx, StoreApi.bookingConfirm(id), reload),
                    ),
                  ),
                if (status == 'confirmed')
                  Expanded(
                    child: WcpButton(
                      variant: 'primary',
                      icon: 'check',
                      label: 'انجام شد',
                      full: true,
                      onClick: () =>
                          runAction(ctx, StoreApi.bookingDone(id), reload),
                    ),
                  ),
                const SizedBox(width: 8),
                if (phone.isNotEmpty) ...[
                  Expanded(
                    child: WcpButton(
                      variant: 'secondary',
                      icon: 'phone',
                      label: 'تماس',
                      full: true,
                      onClick: () => _dial(ctx, phone),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: WcpButton(
                    variant: 'danger',
                    icon: 'x',
                    label: 'لغو',
                    full: true,
                    onClick: () =>
                        runAction(ctx, StoreApi.bookingCancel(id), reload),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 2) RMA — مرجوعی
// ════════════════════════════════════════════════════════════════
class RmasScreen extends StatelessWidget {
  const RmasScreen({super.key});

  static const List<({String key, String label})> _filters = [
    (key: '', label: 'همه'),
    (key: 'requested', label: 'در انتظار بررسی'),
    (key: 'approved', label: 'تاییدشده'),
    (key: 'received', label: 'دریافت‌شده'),
    (key: 'refunded', label: 'عودت‌شده'),
    (key: 'rejected', label: 'ردشده'),
  ];

  ({Color fg, Color bg}) _color(String s, AppColors c) {
    switch (s) {
      case 'approved':
        return (fg: c.info, bg: c.infoSoft);
      case 'received':
        return (fg: c.accent, bg: c.accentSoft);
      case 'refunded':
        return (fg: c.success, bg: c.successSoft);
      case 'rejected':
        return (fg: c.error, bg: c.errorSoft);
      default:
        return (fg: c.warning, bg: c.warningSoft);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModuleListDashboard(
      title: 'مرجوعی کالا',
      sub: 'درخواست‌های بازگشت',
      statusFilters: _filters,
      emptyTitle: 'درخواستی نیست',
      emptyIcon: 'refresh',
      fetch: (page, status) => StoreApi.rmas(page: page, status: status),
      itemBuilder: (ctx, row, reload) => _row(ctx, row, reload),
    );
  }

  Future<void> _refund(BuildContext context, int id, num orderTotal,
      Future<void> Function() reload) async {
    final TextEditingController ctrl =
        TextEditingController(text: orderTotal > 0 ? '${orderTotal.round()}' : '');
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('عودت وجه',
            style: TextStyle(
                fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontFamily: 'Vazirmatn'),
          decoration: const InputDecoration(
            labelText: 'مبلغ (تومان)',
            labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('انصراف',
                  style: TextStyle(fontFamily: 'Vazirmatn'))),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('عودت',
                  style: TextStyle(fontFamily: 'Vazirmatn'))),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    // Integer Toman — strip every non-digit (commas/separators/decimals).
    final num amount =
        num.tryParse(_toLatin(ctrl.text).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0) {
      AppScope.of(context)
          .showToast('مبلغ نامعتبر است.', kind: 'error', icon: 'alert');
      return;
    }
    await runAction(context, StoreApi.rmaRefund(id, amount), reload,
        okIcon: 'wallet');
  }

  Widget _row(
      BuildContext ctx, Map<String, dynamic> row, Future<void> Function() reload) {
    final c = ctx.c;
    final String status = (row['status'] ?? '').toString();
    final int id = (row['id'] as num?)?.toInt() ?? 0;
    final num orderTotal = (row['order_total'] as num?) ?? 0;
    final String refundFmt = (row['refund_fmt'] ?? '').toString();
    final st = _color(status, c);

    return WcpCard(
      pad: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${(row['customer'] ?? '').toString()} · ${(row['order_number'] ?? '').toString()}',
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              statusPill(
                  (row['status_label'] ?? status).toString(), st.fg, st.bg),
            ],
          ),
          _kvLine(c, 'دلیل:', (row['reason_label'] ?? '').toString()),
          if ((row['description'] ?? '').toString().isNotEmpty)
            _kvLine(c, 'توضیح:', (row['description']).toString()),
          if (orderTotal > 0)
            _kvLine(c, 'مبلغ سفارش:', (row['order_total_fmt'] ?? '').toString(),
                ltr: true),
          if (refundFmt.isNotEmpty)
            _kvLine(c, 'عودت‌شده:', refundFmt, ltr: true),
          if (status == 'requested' ||
              status == 'approved' ||
              status == 'received') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (status == 'requested') ...[
                  Expanded(
                    child: WcpButton(
                      variant: 'primary',
                      icon: 'check',
                      label: 'تایید',
                      full: true,
                      onClick: () => runAction(
                          ctx, StoreApi.rmaStatus(id, 'approved'), reload),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: WcpButton(
                      variant: 'danger',
                      icon: 'x',
                      label: 'رد',
                      full: true,
                      onClick: () => runAction(
                          ctx, StoreApi.rmaStatus(id, 'rejected'), reload),
                    ),
                  ),
                ],
                if (status == 'approved')
                  Expanded(
                    child: WcpButton(
                      variant: 'primary',
                      icon: 'package',
                      label: 'کالا دریافت شد',
                      full: true,
                      onClick: () => runAction(
                          ctx, StoreApi.rmaStatus(id, 'received'), reload),
                    ),
                  ),
                if (status == 'received')
                  Expanded(
                    child: WcpButton(
                      variant: 'primary',
                      icon: 'wallet',
                      label: 'عودت وجه',
                      full: true,
                      onClick: () => _refund(ctx, id, orderTotal, reload),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 3) CAMPAIGNS — کمپین پیامکی
// ════════════════════════════════════════════════════════════════
class CampaignsScreen extends StatelessWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleListDashboard(
      title: 'کمپین پیامکی',
      sub: 'ارسال انبوه به مشتریان',
      emptyTitle: 'کمپینی ساخته نشده',
      emptyMessage: 'با دکمه «+» یک کمپین پیامکی بسازید.',
      emptyIcon: 'send',
      fetch: (page, status) => StoreApi.campaigns(),
      headerBuilder: (ctx, meta) {
        if (meta['has_gateway'] == false) {
          final c = ctx.c;
          return WcpCard(
            child: Row(
              children: [
                WcpIcon('alert', size: 18, color: c.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'درگاه پیامک فعال نیست؛ کمپین ارسال نمی‌شود. ابتدا درگاه را در ماژول ورود تنظیم کنید.',
                    style: TextStyle(fontSize: 12, color: c.tx2),
                  ),
                ),
              ],
            ),
          );
        }
        return null;
      },
      itemBuilder: (ctx, row, reload) => _row(ctx, row, reload),
      fabBuilder: (ctx, reload) => FloatingActionButton.extended(
        onPressed: () async {
          final bool? created = await showModalBottomSheet<bool>(
            context: ctx,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const _CampaignCreateSheet(),
          );
          if (created == true) await reload();
        },
        backgroundColor: ctx.c.accent,
        foregroundColor: ctx.c.txOnAccent,
        icon: WcpIcon('plus', size: 18, color: ctx.c.txOnAccent),
        label: const Text('کمپین جدید',
            style:
                TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _row(
      BuildContext ctx, Map<String, dynamic> row, Future<void> Function() reload) {
    final c = ctx.c;
    final String status = (row['status'] ?? '').toString();
    final int id = (row['id'] as num?)?.toInt() ?? 0;
    final int total = (row['total'] as num?)?.toInt() ?? 0;
    final int sent = (row['sent'] as num?)?.toInt() ?? 0;
    final int failed = (row['failed'] as num?)?.toInt() ?? 0;
    final int progress = (row['progress'] as num?)?.toInt() ?? 0;
    final ({Color fg, Color bg}) st = status == 'sending'
        ? (fg: c.warning, bg: c.warningSoft)
        : status == 'done'
            ? (fg: c.success, bg: c.successSoft)
            : (fg: c.tx3, bg: c.bg3);
    final String stLabel = status == 'sending'
        ? 'در حال ارسال'
        : status == 'done'
            ? 'پایان‌یافته'
            : status == 'cancelled'
                ? 'لغوشده'
                : status;

    return WcpCard(
      pad: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((row['name'] ?? 'کمپین').toString(),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              statusPill(stLabel, st.fg, st.bg),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? progress / 100 : 0,
              minHeight: 7,
              backgroundColor: c.bg3,
              valueColor: AlwaysStoppedAnimation<Color>(c.accent),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text('${Fmt.fa(sent)}/${Fmt.fa(total)}',
                    style: TextStyle(fontSize: 11.5, color: c.tx3)),
              ),
              const Spacer(),
              if (failed > 0)
                Text('ناموفق: ${Fmt.fa(failed)}',
                    style: TextStyle(fontSize: 11.5, color: c.error)),
            ],
          ),
          if (status == 'sending') ...[
            const SizedBox(height: 10),
            WcpButton(
              variant: 'danger',
              icon: 'stop',
              label: 'توقف ارسال',
              full: true,
              onClick: () =>
                  runAction(ctx, StoreApi.campaignCancel(id), reload),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 4) AFFILIATES — همکاری در فروش
// ════════════════════════════════════════════════════════════════
class AffiliatesScreen extends StatelessWidget {
  const AffiliatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleListDashboard(
      title: 'همکاری در فروش',
      sub: 'پورسانت معرف‌ها',
      emptyTitle: 'موردی نیست',
      emptyMessage: 'هنوز فروشی از طریق معرف ثبت نشده است.',
      emptyIcon: 'users',
      fetch: (page, status) => StoreApi.affiliates(),
      headerBuilder: (ctx, meta) {
        final c = ctx.c;
        final int rate = (meta['rate'] as num?)?.toInt() ?? 0;
        return WcpCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(12)),
                child: WcpIcon('percent', size: 19, color: c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('نرخ پورسانت: ${Fmt.fa(rate)}٪',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                        meta['enabled'] == true
                            ? 'برنامه فعال است'
                            : 'برنامه غیرفعال است',
                        style: TextStyle(fontSize: 11.5, color: c.tx3)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      itemBuilder: (ctx, row, reload) => _row(ctx, row, reload),
      appBarActions: [
        IconBtnRaw(
          onClick: () => AppScope.of(context).push('mod_affiliates_settings'),
          child: const WcpIcon('settings', size: 20),
        ),
      ],
    );
  }

  Widget _row(
      BuildContext ctx, Map<String, dynamic> row, Future<void> Function() reload) {
    final c = ctx.c;
    final String status = (row['status'] ?? '').toString();
    final int id = (row['id'] as num?)?.toInt() ?? 0;
    final ({Color fg, Color bg}) st = status == 'paid'
        ? (fg: c.success, bg: c.successSoft)
        : status == 'approved'
            ? (fg: c.warning, bg: c.warningSoft)
            : (fg: c.tx3, bg: c.bg3);

    return WcpCard(
      pad: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((row['affiliate'] ?? '').toString(),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              statusPill(
                  (row['status_label'] ?? status).toString(), st.fg, st.bg),
            ],
          ),
          _kvLine(c, 'سفارش:', '#${Fmt.fa((row['order_id'] ?? 0).toString())}',
              ltr: true),
          _kvLine(c, 'نرخ:', '${Fmt.fa((row['rate'] ?? 0).toString())}٪'),
          if ((row['amount_fmt'] ?? '').toString().isNotEmpty)
            _kvLine(c, 'پورسانت:', (row['amount_fmt']).toString(), ltr: true),
          if (status == 'approved') ...[
            const SizedBox(height: 12),
            WcpButton(
              variant: 'primary',
              icon: 'wallet',
              label: 'تسویه پورسانت',
              full: true,
              onClick: () => runAction(ctx, StoreApi.affiliatePay(id), reload,
                  okIcon: 'wallet'),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 5) SUBSCRIPTION MEMBERS — اعضای اشتراک (read-only)
// ════════════════════════════════════════════════════════════════
class SubscriptionMembersScreen extends StatelessWidget {
  const SubscriptionMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleListDashboard(
      title: 'اعضای اشتراک',
      sub: 'مشترکان فعال',
      emptyTitle: 'عضوی نیست',
      emptyIcon: 'crown',
      appBarActions: [
        IconBtnRaw(
          onClick: () => AppScope.of(context).push('mod_subscription_plans'),
          child: const WcpIcon('tag', size: 20),
        ),
        IconBtnRaw(
          onClick: () => AppScope.of(context).push('mod_subscription_profile'),
          child: const WcpIcon('settings', size: 20),
        ),
      ],
      fetch: (page, status) => StoreApi.subscriptionMembers(page: page),
      itemBuilder: (ctx, row, reload) {
        final c = ctx.c;
        final String status = (row['status'] ?? '').toString();
        final ({Color fg, Color bg}) st = status == 'active'
            ? (fg: c.success, bg: c.successSoft)
            : status == 'cancelled' || status == 'expired'
                ? (fg: c.tx3, bg: c.bg3)
                : (fg: c.warning, bg: c.warningSoft);
        return WcpCard(
          pad: 13,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text((row['member'] ?? '').toString(),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  statusPill(
                      (row['status_label'] ?? status).toString(), st.fg, st.bg),
                ],
              ),
              if ((row['plan'] ?? '').toString().isNotEmpty)
                _kvLine(c, 'طرح:', (row['plan']).toString()),
              if ((row['next_renewal'] ?? '').toString().isNotEmpty)
                _kvLine(c, 'تمدید بعدی:',
                    jalaliDay((row['next_renewal']).toString())),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 6) B2B APPROVALS — تایید عمده‌فروشی
// ════════════════════════════════════════════════════════════════
class B2bApprovalsScreen extends StatelessWidget {
  const B2bApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleListDashboard(
      title: 'تایید عمده‌فروشی',
      sub: 'ثبت‌نام‌های در انتظار',
      emptyTitle: 'درخواستی نیست',
      emptyMessage: 'ثبت‌نام عمده‌فروشی در انتظار تاییدی وجود ندارد.',
      emptyIcon: 'check',
      appBarActions: [
        IconBtnRaw(
          onClick: () => AppScope.of(context).push('mod_b2b_customers'),
          child: const WcpIcon('users', size: 20),
        ),
        IconBtnRaw(
          onClick: () => AppScope.of(context).push('mod_b2b'),
          child: const WcpIcon('settings', size: 20),
        ),
      ],
      fetch: (page, status) => StoreApi.b2bApprovals(page: page),
      itemBuilder: (ctx, row, reload) {
        final c = ctx.c;
        final int id = (row['id'] as num?)?.toInt() ?? 0;
        final String phone = (row['phone'] ?? '').toString();
        return WcpCard(
          pad: 13,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text((row['name'] ?? row['login'] ?? '').toString(),
                  style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if ((row['company'] ?? '').toString().isNotEmpty)
                _kvLine(c, 'شرکت:', (row['company']).toString()),
              if ((row['tax_id'] ?? '').toString().isNotEmpty)
                _kvLine(c, 'شناسه ملی:', Fmt.fa((row['tax_id']).toString()),
                    ltr: true),
              if ((row['email'] ?? '').toString().isNotEmpty)
                _kvLine(c, 'ایمیل:', (row['email']).toString(), ltr: true),
              if (phone.isNotEmpty)
                _kvLine(c, 'تماس:', Fmt.fa(phone), ltr: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: WcpButton(
                      variant: 'primary',
                      icon: 'check',
                      label: 'تایید',
                      full: true,
                      onClick: () => runAction(
                          ctx, StoreApi.b2bDecide(id, 'approve'), reload),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (phone.isNotEmpty) ...[
                    Expanded(
                      child: WcpButton(
                        variant: 'secondary',
                        icon: 'phone',
                        label: 'تماس',
                        full: true,
                        onClick: () => _dial(ctx, phone),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: WcpButton(
                      variant: 'danger',
                      icon: 'x',
                      label: 'رد',
                      full: true,
                      onClick: () => runAction(
                          ctx, StoreApi.b2bDecide(id, 'reject'), reload),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── campaign create sheet ────────────────────────────────────────
class _CampaignCreateSheet extends StatefulWidget {
  const _CampaignCreateSheet();
  @override
  State<_CampaignCreateSheet> createState() => _CampaignCreateSheetState();
}

class _CampaignCreateSheetState extends State<_CampaignCreateSheet> {
  String _name = '';
  String _message = '';
  String _segment = 'all_customers';
  String _days = '30';
  String _numbers = '';
  bool _confirm = false;
  bool _busy = false;
  String? _err;

  static const List<({String key, String label})> _segments = [
    (key: 'all_customers', label: 'همه مشتریان'),
    (key: 'recent_buyers', label: 'خریداران اخیر'),
    (key: 'manual', label: 'فهرست دستی'),
  ];

  Future<void> _submit() async {
    if (_message.trim().isEmpty) {
      setState(() => _err = 'متن پیامک را بنویسید.');
      return;
    }
    if (!_confirm) {
      setState(() => _err = 'ارسال پیامک هزینه دارد؛ لطفا تایید کنید.');
      return;
    }
    if (_segment == 'recent_buyers') {
      final int? d =
          int.tryParse(_toLatin(_days).replaceAll(RegExp(r'[^0-9]'), ''));
      if (d == null || d <= 0) {
        setState(() => _err = 'تعداد روز باید یک عدد مثبت باشد.');
        return;
      }
    }
    if (_segment == 'manual' && _numbers.trim().isEmpty) {
      setState(() => _err = 'دست‌کم یک شماره وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final StoreResult r = await StoreApi.campaignCreate(<String, dynamic>{
      'name': _name.trim(),
      'message': _message,
      'segment': _segment,
      if (_segment == 'recent_buyers')
        'days': int.tryParse(_toLatin(_days).replaceAll(RegExp(r'[^0-9]'), '')) ?? 30,
      if (_segment == 'manual') 'numbers': _numbers,
    });
    if (!mounted) return;
    if (r.ok && r.map['ok'] == true) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _err = (r.map['message'] ?? r.error ?? 'ساخت کمپین ناموفق بود.').toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final double bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.bg0,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: c.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('کمپین پیامکی جدید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              WcpField(
                  label: 'نام کمپین (اختیاری)',
                  value: _name,
                  onChange: (v) => _name = v),
              const SizedBox(height: 10),
              WcpField(
                label: 'متن پیامک',
                value: _message,
                multiline: true,
                placeholder: 'سلام {name}! ...',
                hint: '{name} با نام مشتری جایگزین می‌شود.',
                onChange: (v) => _message = v,
              ),
              const SizedBox(height: 12),
              Text('گیرندگان',
                  style: TextStyle(
                      fontFamily: 'Vazirmatn', fontSize: 12.5, color: c.tx3)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _segments)
                    WcpChip(
                      active: _segment == s.key,
                      onClick: () => setState(() => _segment = s.key),
                      child: Text(s.label),
                    ),
                ],
              ),
              if (_segment == 'recent_buyers') ...[
                const SizedBox(height: 10),
                WcpField(
                    label: 'خریداران چند روز اخیر',
                    value: _days,
                    dir: TextDirection.ltr,
                    onChange: (v) => _days = v),
              ],
              if (_segment == 'manual') ...[
                const SizedBox(height: 10),
                WcpField(
                    label: 'شماره‌ها (هر خط یک شماره)',
                    value: _numbers,
                    multiline: true,
                    dir: TextDirection.ltr,
                    onChange: (v) => _numbers = v),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: c.warningSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    WcpIcon('alert', size: 18, color: c.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'پیامک واقعی از درگاه فعال ارسال می‌شود و هزینه دارد. حداکثر ۵٬۰۰۰ گیرنده؛ حدود ۱۵ پیامک در دقیقه.',
                        style: TextStyle(fontSize: 11.5, color: c.tx2, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'می‌دانم پیامک واقعی ارسال و هزینه آن کسر می‌شود.',
                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5),
                    ),
                  ),
                  WcpSwitch(
                      on: _confirm,
                      onChange: (v) => setState(() => _confirm = v)),
                ],
              ),
              if (_err != null) ...[
                const SizedBox(height: 10),
                Text(_err!,
                    style: TextStyle(
                        fontFamily: 'Vazirmatn', fontSize: 12, color: c.error)),
              ],
              const SizedBox(height: 16),
              WcpButton(
                variant: 'primary',
                label: _busy ? 'در حال ساخت…' : 'ساخت و ارسال',
                full: true,
                disabled: _busy,
                onClick: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Persian/Arabic digits → ASCII (for the RMA refund amount parse).
String _toLatin(String s) {
  const String fa = '۰۱۲۳۴۵۶۷۸۹';
  const String ar = '٠١٢٣٤٥٦٧٨٩';
  final StringBuffer out = StringBuffer();
  for (final int rune in s.runes) {
    final String ch = String.fromCharCode(rune);
    final int fi = fa.indexOf(ch);
    final int ai = ar.indexOf(ch);
    out.write(fi >= 0 ? '$fi' : (ai >= 0 ? '$ai' : ch));
  }
  return out.toString();
}
