// ════════════════════════════════════════════════════════════════
// module_pages.dart — rich sample module screens, ported pixel-perfect
// from app/screens-module-pages.jsx.
//
// Screens:  WalletModule · LoyaltyModule · CouponModule · CouponCreate
//           · MarketModule  (+ the shared ModSettingRow toggle row).
// Routes:   mod_<id> overrides for the five RICH modules (wallet,
//           loyalty, coupon, divar, basalam) + couponCreate +
//           genericModule. The generic `mod_<id>` fallbacks and the
//           `GenericModuleScreen` itself come from modules.dart (port of
//           screens-modules.jsx); we reuse that screen here.
//
// Uses only the shared design-system widgets (ui.dart), icons.dart,
// fmt helper, sample.dart data and the AppScope nav. RTL is global.
// ════════════════════════════════════════════════════════════════
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/icons.dart';
import '../data/models.dart';
import '../data/sample.dart';
import '../data/woo_map.dart';
import '../nav/shell.dart';
import '../services/store_api.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';
import 'modules.dart' show GenericModuleScreen;
import 'registry.dart';

// ════════════════════════════════════════════════════════════════
// Shared module-pages helpers
// ════════════════════════════════════════════════════════════════

/// `fieldLabel` from the JSX (fontSize 13, weight 600, var(--tx-2)).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.c.tx2,
      ),
    );
  }
}

/// Colour at a given opacity-suffix (JSX `color + '22'` etc → alpha hex).
Color _alpha(Color base, int alpha) => base.withAlpha(alpha);

/// Parse a `#rrggbb` / `#rgb` hex string → [Color] (opaque). Falls back to the
/// brand accent when the string is malformed.
Color _hexColor(String hex) {
  String s = hex.trim().replaceFirst('#', '');
  if (s.length == 3) {
    s = s.split('').map((ch) => '$ch$ch').join();
  }
  if (s.length == 6) {
    final int? v = int.tryParse(s, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  return const Color(0xFF8B5CF6);
}

/// 1px hairline divider inset horizontally (JSX `height:1; background:line;
/// margin:0 <inset>`).
class _Divider extends StatelessWidget {
  const _Divider({this.inset = 16});
  final double inset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: inset),
      color: context.c.line,
    );
  }
}

/// A column of vertically-gapped children (JSX flex-column + gap).
List<Widget> _vgap(List<Widget> children, double gap) {
  if (children.length <= 1) return children;
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) out.add(SizedBox(height: gap));
    out.add(children[i]);
  }
  return out;
}

/// Screen scaffold: opaque bg-0 canvas + sticky [WcpAppBar] + scroll body.
class _ModuleScaffold extends StatelessWidget {
  const _ModuleScaffold({required this.appBar, required this.body});
  final WcpAppBar appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.bg0,
      body: Column(
        children: [
          appBar,
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ModSettingRow — stateful toggle row (JSX `ModSettingRow`).
//   icon box 36×36 r11 c+'18'; title 14/600; sub 11.5/tx3; Switch sm.
// ════════════════════════════════════════════════════════════════
class ModSettingRow extends StatefulWidget {
  const ModSettingRow({
    super.key,
    required this.label,
    required this.sub,
    required this.initial,
    required this.icon,
    required this.color,
  });

  final String label;
  final String sub;
  final bool initial;
  final String icon;
  final Color color;

  @override
  State<ModSettingRow> createState() => _ModSettingRowState();
}

class _ModSettingRowState extends State<ModSettingRow> {
  late bool _on = widget.initial;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _alpha(widget.color, 0x18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: WcpIcon(widget.icon, size: 18, color: widget.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.sub,
                  style: TextStyle(fontSize: 11.5, color: c.tx3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          WcpSwitch(
            on: _on,
            size: 'sm',
            onChange: (v) => setState(() => _on = v),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// WALLET
// ════════════════════════════════════════════════════════════════
class _Txn {
  const _Txn({
    required this.title,
    required this.who,
    required this.amount,
    required this.kind, // 'in' | 'out'
  });
  final String title;
  final String who;
  final int amount;
  final String kind;
}

class WalletModuleScreen extends StatefulWidget {
  const WalletModuleScreen({super.key});

  @override
  State<WalletModuleScreen> createState() => _WalletModuleScreenState();
}

class _WalletModuleScreenState extends State<WalletModuleScreen> {
  // Connected → empty + loading (no fabricated transactions / names);
  // disconnected → the design-reference sample so the preview isn't blank.
  List<_Txn> _txns = StoreApi.hasStore
      ? const <_Txn>[]
      : const <_Txn>[
          _Txn(
              title: 'شارژ کیف پول',
              who: 'مریم احمدی',
              amount: 500000,
              kind: 'in'),
          _Txn(
              title: 'خرید سفارش #۱۰۲۴۸',
              who: 'رضا کریمی',
              amount: -340000,
              kind: 'out'),
          _Txn(
              title: 'بازگشت وجه',
              who: 'سارا موسوی',
              amount: 180000,
              kind: 'in'),
          _Txn(
              title: 'خرید سفارش #۱۰۲۴۵',
              who: 'علی رحیمی',
              amount: -620000,
              kind: 'out'),
          _Txn(
              title: 'پاداش وفاداری',
              who: 'نگار حسینی',
              amount: 50000,
              kind: 'in'),
        ];
  bool _loading = StoreApi.hasStore;

  // Hero numbers — «—» until the real appWallet totals land (no fake figures).
  String _balance = StoreApi.hasStore ? '—' : Fmt.toman(48720000);
  String _accounts = StoreApi.hasStore ? '—' : Fmt.fa('۲٬۴۸۰');
  String _today = StoreApi.hasStore ? '—' : Fmt.fa(64);

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) _load();
  }

  Future<void> _load() async {
    final StoreResult res = await StoreApi.appWallet();
    if (!mounted) return;
    if (!res.ok || res.map['available'] == false) {
      setState(() => _loading = false);
      return;
    }
    final Map<String, dynamic> m = res.map;

    final Map<String, dynamic> tb = m['total_balance'] is Map
        ? Map<String, dynamic>.from(m['total_balance'] as Map)
        : const {};
    final String balDisplay = (tb['display'] ?? '').toString().trim();
    final String balance = balDisplay.isNotEmpty
        ? balDisplay
        : (tb['amount'] != null
            ? Fmt.toman(num.tryParse('${tb['amount']}') ?? 0)
            : _balance);

    final int accounts = m['accounts_count'] is num
        ? (m['accounts_count'] as num).toInt()
        : int.tryParse('${m['accounts_count']}') ?? -1;

    final List<dynamic> rt = m['recent_transactions'] is List
        ? m['recent_transactions'] as List
        : const [];
    final List<_Txn> txns = <_Txn>[
      for (final dynamic raw in rt)
        if (raw is Map) _txnFromApp(Map<String, dynamic>.from(raw)),
    ];

    setState(() {
      _balance = balance;
      _accounts = accounts >= 0 ? Fmt.fa(accounts) : '—';
      _today = Fmt.fa(txns.length);
      _txns = txns; // real ledger (may be empty — honest, not sample)
      _loading = false;
    });
  }

  // appWallet recent-transaction → the local _Txn row model.
  static _Txn _txnFromApp(Map<String, dynamic> j) {
    final Map<String, dynamic> amt = j['amount'] is Map
        ? Map<String, dynamic>.from(j['amount'] as Map)
        : const {};
    final num value =
        amt['amount'] is num ? amt['amount'] as num : num.tryParse('${amt['amount']}') ?? 0;
    final String type = (j['type'] ?? '').toString().toLowerCase();
    // Direction: explicit credit/debit type, else sign of the amount.
    final bool isIn = type.contains('credit') ||
        type.contains('deposit') ||
        type.contains('refund') ||
        type.contains('topup') ||
        type.contains('reward') ||
        (type.isEmpty && value >= 0);
    String who = (j['user_name'] ?? '').toString().trim();
    if (who.isEmpty) who = 'مشتری';
    String title = (j['reason'] ?? '').toString().trim();
    if (title.isEmpty) {
      final int orderId = j['order_id'] is num
          ? (j['order_id'] as num).toInt()
          : int.tryParse('${j['order_id']}') ?? 0;
      title = orderId > 0
          ? 'خرید سفارش #${Fmt.fa(orderId)}'
          : (isIn ? 'شارژ کیف پول' : 'برداشت');
    }
    return _Txn(
      title: title,
      who: who,
      amount: (isIn ? value.abs() : -value.abs()).toInt(),
      kind: isIn ? 'in' : 'out',
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppScope.of(context);
    final List<_Txn> txns = _txns;

    return _ModuleScaffold(
      appBar: WcpAppBar(
        title: 'کیف پول',
        sub: 'تعامل با مشتری',
        onBack: nav.pop,
        actions: [
          IconBtn(
            name: 'settings',
            onClick: () => nav.push(
                'moduleSettings', {'key': 'wallet', 'title': 'تنظیمات کیف پول'}),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _vgap([
            // balance hero
            _WalletHero(balance: _balance, accounts: _accounts, today: _today),
            // action buttons grid 1fr 1fr gap 10
            Row(
              children: [
                Expanded(
                  // Manual top-up runs per-customer: open the customers list
                  // where the real «افزایش اعتبار کیف‌پول» action lives (⋮ menu),
                  // backed by POST /app/customer/wallet-credit.
                  child: WcpButton(
                    label: 'شارژ دستی',
                    icon: 'plus',
                    full: true,
                    onClick: () async {
                      await showWcpSheet<void>(context,
                          title: 'شارژ کیف پول مشتری',
                          child: const _WalletTopupSheet());
                      if (mounted) _load();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: WcpButton(
                    label: 'انتقال اعتبار',
                    variant: 'secondary',
                    icon: 'send',
                    full: true,
                    onClick: () async {
                      await showWcpSheet<void>(context,
                          title: 'انتقال اعتبار بین کیف‌پول‌ها',
                          child: const _WalletTransferSheet());
                      if (mounted) _load();
                    },
                  ),
                ),
              ],
            ),
            // Real module settings (schema-driven editor) instead of the old
            // hardcoded toggles — only the fields the wallet module actually
            // exposes are shown + saved.
            WcpCard(
              pad: 0,
              child: ListRow(
                icon: 'settings',
                iconColor: const Color(0xFF8B5CF6),
                title: 'تنظیمات کیف پول',
                sub: 'کش‌بک، برداشت نقدی و سایر گزینه‌ها',
                chevron: true,
                onClick: () => nav.push('moduleSettings',
                    {'key': 'wallet', 'title': 'تنظیمات کیف پول'}),
              ),
            ),
            // txns
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHead(
                  title: 'آخرین تراکنش‌ها',
                  action: 'مشاهده همه',
                  onAction: () => AppScope.of(context).push('walletTxns'),
                ),
                WcpCard(
                  pad: 0,
                  child: _loading && txns.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 26),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : txns.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 22),
                              child: Center(
                                child: Text(
                                  'تراکنشی ثبت نشده است.',
                                  style: TextStyle(
                                      fontSize: 12.5, color: context.c.tx3),
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                for (var i = 0; i < txns.length; i++) ...[
                                  _TxnRow(tx: txns[i]),
                                  if (i < txns.length - 1)
                                    const _Divider(inset: 14),
                                ],
                              ],
                            ),
                ),
              ],
            ),
          ], 14),
        ),
      ),
    );
  }
}

class _WalletHero extends StatelessWidget {
  const _WalletHero({
    required this.balance,
    required this.accounts,
    required this.today,
  });
  final String balance;
  final String accounts;
  final String today;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            // 135deg, #7c3aed → #a855f7 70% → #c084fc
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFFC084FC)],
            stops: [0.0, 0.7, 1.0],
          ),
          boxShadow: context.c.shadowAccent,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // decorative circle: top -30 left -20, 140×140, white .12
            Positioned(
              top: -30,
              left: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha((0.12 * 255).round()),
                ),
              ),
            ),
            // decorative circle: bottom -40 left 40, 100×100, white .08
            Positioned(
              bottom: -40,
              left: 40,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha((0.08 * 255).round()),
                ),
              ),
            ),
            // content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'موجودی کل کیف‌پول‌ها',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha((0.85 * 255).round()),
                      ),
                    ),
                    const Opacity(
                      opacity: 0.9,
                      child: WcpIcon('wallet',
                          size: 24, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  balance,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6, // -.02em of 30
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _WalletStat(label: 'کاربران فعال', value: accounts),
                    const SizedBox(width: 18),
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.white.withAlpha((0.25 * 255).round()),
                    ),
                    const SizedBox(width: 18),
                    _WalletStat(label: 'تراکنش امروز', value: today),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withAlpha((0.8 * 255).round()),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.tx});
  final _Txn tx;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isIn = tx.kind == 'in';
    final amtColor = isIn ? c.success : c.error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isIn ? c.successSoft : c.errorSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: WcpIcon(
              isIn ? 'arrowDown' : 'arrowUp',
              size: 18,
              sw: 2.2,
              color: amtColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  tx.who,
                  style: TextStyle(fontSize: 11.5, color: c.tx3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '${isIn ? '+' : '−'}${Fmt.tomanShort(tx.amount.abs())}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: amtColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// LOYALTY
// ════════════════════════════════════════════════════════════════
class _Tier {
  const _Tier({
    required this.name,
    required this.color,
    required this.members,
    required this.perk,
  });
  final String name;
  final Color color;
  final int members;
  final String perk;
}

// ── Tier add/edit sheet — pops a {label, min_lifetime, color, perks[], _delete}
//    map (null if cancelled). Used by the loyalty screen's real CRUD.
class _TierEditSheet extends StatefulWidget {
  const _TierEditSheet({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_TierEditSheet> createState() => _TierEditSheetState();
}

class _TierEditSheetState extends State<_TierEditSheet> {
  late String _label;
  late String _min;
  late String _color;
  late String _perks;

  static const List<String> _swatches = <String>[
    '#B8804A', '#9AA3AD', '#E0A52E', '#5EC8E0',
    '#8B5CF6', '#16A34A', '#EF4444', '#3B82F6',
  ];

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? i = widget.initial;
    _label = (i?['label'] ?? '').toString();
    _min = ((i?['min_lifetime'] ?? 0)).toString();
    _color = (i?['color'] ?? '#8B5CF6').toString();
    final dynamic p = i?['perks'];
    _perks = p is List
        ? p.map((e) => e.toString()).where((e) => e.isNotEmpty).join('\n')
        : (p ?? '').toString();
  }

  Map<String, dynamic> _result({bool delete = false}) {
    final List<String> perks = _perks
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return <String, dynamic>{
      'label': _label.trim(),
      'min_lifetime': int.tryParse(_wxDigits(_min)) ?? 0,
      'color': _color,
      'perks': perks,
      if (delete) '_delete': true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WcpField(
          label: 'نام سطح',
          value: _label,
          placeholder: 'مثلا: طلایی',
          onChange: (v) => _label = v,
        ),
        const SizedBox(height: 12),
        WcpField(
          label: 'آستانه امتیاز مادام‌العمر',
          value: _min,
          placeholder: 'مثلا: ۵۰۰۰',
          onChange: (v) => _min = v,
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(right: 2, bottom: 8),
          child: Text('رنگ',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: c.tx3)),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final s in _swatches)
              GestureDetector(
                onTap: () => setState(() => _color = s),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _hexColor(s),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _color.toLowerCase() == s.toLowerCase()
                          ? c.tx1
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        WcpField(
          label: 'مزایا (هر خط یک مورد)',
          value: _perks,
          multiline: true,
          placeholder: 'مثلا:\n٪۵ پاداش\nارسال رایگان',
          onChange: (v) => _perks = v,
        ),
        const SizedBox(height: 16),
        WcpButton(
          full: true,
          size: 'lg',
          icon: 'check',
          label: _isEdit ? 'ذخیره تغییرات' : 'افزودن سطح',
          onClick: () {
            if (_label.trim().isEmpty) {
              AppScope.of(context).showToast('نام سطح را وارد کنید',
                  kind: 'error', icon: 'alert');
              return;
            }
            Navigator.of(context).pop(_result());
          },
        ),
        if (_isEdit) ...[
          const SizedBox(height: 10),
          WcpButton(
            full: true,
            variant: 'danger',
            icon: 'trash',
            label: 'حذف این سطح',
            onClick: () => Navigator.of(context).pop(_result(delete: true)),
          ),
        ],
      ],
    );
  }
}

class LoyaltyModuleScreen extends StatefulWidget {
  const LoyaltyModuleScreen({super.key});

  @override
  State<LoyaltyModuleScreen> createState() => _LoyaltyModuleScreenState();
}

class _LoyaltyModuleScreenState extends State<LoyaltyModuleScreen> {
  // Connected → empty + loading (no fabricated member counts); disconnected →
  // the design-reference sample so the preview isn't blank.
  List<_Tier> _tiers = StoreApi.hasStore
      ? const <_Tier>[]
      : const <_Tier>[
          _Tier(
              name: 'برنزی',
              color: Color(0xFFB8804A),
              members: 1420,
              perk: '٪۲ پاداش'),
          _Tier(
              name: 'نقره‌ای',
              color: Color(0xFF9AA3AD),
              members: 680,
              perk: '٪۵ پاداش + ارسال رایگان'),
          _Tier(
              name: 'طلایی',
              color: Color(0xFFE0A52E),
              members: 240,
              perk: '٪۸ پاداش + پشتیبانی ویژه'),
          _Tier(
              name: 'الماس',
              color: Color(0xFF5EC8E0),
              members: 64,
              perk: '٪۱۲ پاداش + هدیه تولد'),
        ];
  bool _loading = StoreApi.hasStore;
  bool _savingTiers = false;

  // Raw tier maps ({slug,label,min_lifetime,color,perks}) — the editable source
  // of truth for add/edit/delete. The display `_tiers` is derived from these.
  List<Map<String, dynamic>> _tiersRaw = <Map<String, dynamic>>[];

  // Stat numbers — «—» until the real appLoyalty totals land (no fake figures).
  String _members = StoreApi.hasStore ? '—' : Fmt.fa('۲٬۴۰۴');
  String _points = StoreApi.hasStore ? '—' : Fmt.tomanShort(1840000);

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) _load();
  }

  Future<void> _load() async {
    final StoreResult res = await StoreApi.appLoyalty();
    if (!mounted) return;
    if (!res.ok || res.map['available'] == false) {
      setState(() => _loading = false);
      return;
    }
    final Map<String, dynamic> m = res.map;

    final int members = m['members_count'] is num
        ? (m['members_count'] as num).toInt()
        : int.tryParse('${m['members_count']}') ?? -1;
    final int points = m['total_current_points'] is num
        ? (m['total_current_points'] as num).toInt()
        : int.tryParse('${m['total_current_points']}') ?? -1;

    // Per-tier member counts from top_members (the only per-member source).
    final List<dynamic> tm =
        m['top_members'] is List ? m['top_members'] as List : const [];
    final Map<String, int> tierCounts = <String, int>{};
    for (final dynamic raw in tm) {
      if (raw is! Map) continue;
      final String t = (raw['tier'] ?? '').toString();
      if (t.isEmpty) continue;
      tierCounts[t] = (tierCounts[t] ?? 0) + 1;
    }

    final List<dynamic> tj =
        m['tiers'] is List ? m['tiers'] as List : const [];
    final List<Map<String, dynamic>> raw = <Map<String, dynamic>>[
      for (final dynamic r in tj)
        if (r is Map) Map<String, dynamic>.from(r),
    ];
    final List<_Tier> tiers = <_Tier>[
      for (final Map<String, dynamic> r in raw) _tierFromApp(r, tierCounts),
    ];

    setState(() {
      _members = members >= 0 ? Fmt.fa(members) : '—';
      _points = points >= 0 ? Fmt.fa(points) : '—';
      _tiers = tiers; // real tiers (may be empty — honest, not sample)
      _tiersRaw = raw;
      _loading = false;
    });
  }

  // Persist a mutated tier list, then reload from the server (which returns the
  // normalized set). Returns true on success.
  Future<bool> _persistTiers(List<Map<String, dynamic>> next) async {
    setState(() => _savingTiers = true);
    final StoreResult r = await StoreApi.saveLoyaltyTiers(next);
    if (!mounted) return false;
    setState(() => _savingTiers = false);
    if (r.ok) {
      await _load();
    }
    return r.ok;
  }

  // Unique Latin slug for a NEW tier (Persian labels sanitize to empty server
  // side, so we must supply one).
  String _newSlug() {
    final Set<String> used =
        _tiersRaw.map((e) => (e['slug'] ?? '').toString()).toSet();
    int n = used.length + 1;
    while (used.contains('tier_$n')) {
      n++;
    }
    return 'tier_$n';
  }

  Future<void> _addTier(BuildContext context) async {
    final nav = AppScope.of(context);
    if (!StoreApi.hasStore) {
      nav.showToast('برای ویرایش سطوح، فروشگاه را متصل کنید',
          kind: 'info', icon: 'crown');
      return;
    }
    final Map<String, dynamic>? result = await showWcpSheet<Map<String, dynamic>>(
      context,
      title: 'افزودن سطح',
      child: const _TierEditSheet(),
    );
    if (result == null || !mounted) return;
    final List<Map<String, dynamic>> next =
        List<Map<String, dynamic>>.from(_tiersRaw)
          ..add(<String, dynamic>{
            'slug': _newSlug(),
            'label': result['label'],
            'min_lifetime': result['min_lifetime'],
            'color': result['color'],
            'perks': result['perks'],
          });
    final bool ok = await _persistTiers(next);
    if (!mounted) return;
    nav.showToast(ok ? 'سطح جدید افزوده شد' : 'ذخیره سطح ناموفق بود',
        kind: ok ? 'success' : 'error', icon: ok ? 'crown' : 'alert');
  }

  Future<void> _editTier(BuildContext context, Map<String, dynamic> tier) async {
    final nav = AppScope.of(context);
    if (!StoreApi.hasStore) {
      nav.showToast('برای ویرایش سطوح، فروشگاه را متصل کنید',
          kind: 'info', icon: 'crown');
      return;
    }
    final String slug = (tier['slug'] ?? '').toString();
    final Map<String, dynamic>? result = await showWcpSheet<Map<String, dynamic>>(
      context,
      title: 'ویرایش سطح',
      child: _TierEditSheet(initial: tier),
    );
    if (result == null || !mounted) return;

    List<Map<String, dynamic>> next;
    if (result['_delete'] == true) {
      next = _tiersRaw
          .where((e) => (e['slug'] ?? '').toString() != slug)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      next = _tiersRaw.map((e) {
        if ((e['slug'] ?? '').toString() != slug) {
          return Map<String, dynamic>.from(e);
        }
        return <String, dynamic>{
          'slug': slug,
          'label': result['label'],
          'min_lifetime': result['min_lifetime'],
          'color': result['color'],
          'perks': result['perks'],
        };
      }).toList();
    }
    final bool ok = await _persistTiers(next);
    if (!mounted) return;
    final bool del = result['_delete'] == true;
    nav.showToast(
        ok
            ? (del ? 'سطح حذف شد' : 'سطح به‌روزرسانی شد')
            : 'ذخیره سطح ناموفق بود',
        kind: ok ? 'success' : 'error',
        icon: ok ? 'crown' : 'alert');
  }

  // appLoyalty tier → the local _Tier card model.
  static _Tier _tierFromApp(Map<String, dynamic> j, Map<String, int> counts) {
    final String slug = (j['slug'] ?? '').toString();
    final String label = (j['label'] ?? '').toString().trim();
    final String name = label.isEmpty ? (slug.isEmpty ? 'سطح' : slug) : label;
    final dynamic perksRaw = j['perks'];
    String perk;
    if (perksRaw is List) {
      perk = perksRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).join(' · ');
    } else {
      perk = (perksRaw ?? '').toString().trim();
    }
    if (perk.isEmpty) perk = 'مزایای باشگاه';
    return _Tier(
      name: name,
      color: _hexColor((j['color'] ?? '#8b5cf6').toString()),
      members: counts[slug] ?? counts[label] ?? 0,
      perk: perk,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final nav = AppScope.of(context);
    final List<_Tier> tiers = _tiers;

    return _ModuleScaffold(
      appBar: WcpAppBar(
        title: 'باشگاه مشتریان',
        sub: 'تعامل با مشتری',
        onBack: nav.pop,
        actions: [
          IconBtn(
            name: 'settings',
            onClick: () => nav.push(
                'moduleSettings', {'key': 'loyalty', 'title': 'تنظیمات باشگاه مشتریان'}),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _vgap([
            // stat cards grid 1fr 1fr gap 11
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: WcpCard(
                    pad: 15,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('اعضای باشگاه',
                            style:
                                TextStyle(fontSize: 11.5, color: c.tx3)),
                        const SizedBox(height: 3),
                        Text(
                          _members,
                          style: const TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Delta(value: 9.2),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: WcpCard(
                    pad: 15,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('امتیاز توزیع‌شده',
                            style:
                                TextStyle(fontSize: 11.5, color: c.tx3)),
                        const SizedBox(height: 3),
                        Text(
                          _points,
                          style: const TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text('این ماه',
                            style: TextStyle(fontSize: 11, color: c.tx3)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // tiers
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHead(title: 'سطوح باشگاه'),
                // Tier-distribution donut (members per tier) — shown once tiers
                // with members are loaded.
                if (tiers.any((t) => t.members > 0)) ...[
                  WcpCard(
                    pad: 14,
                    child: WcpDonut(
                      data: [
                        for (final t in tiers)
                          ChartDatum(t.name, t.members.toDouble(), t.color),
                      ],
                      centerLabel: 'اعضا',
                      size: 150,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_loading && tiers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (tiers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'هنوز سطحی برای باشگاه تعریف نشده است.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: c.tx3),
                    ),
                  )
                else
                  Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _vgap([
                    for (final t in tiers)
                      WcpCard(
                        pad: 14,
                        onClick: tiers.indexOf(t) < _tiersRaw.length
                            ? () => _editTier(
                                context, _tiersRaw[tiers.indexOf(t)])
                            : () => nav.showToast(
                                'برای ویرایش سطوح، فروشگاه را متصل کنید',
                                kind: 'info', icon: 'crown'),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _alpha(t.color, 0x22),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: WcpIcon('crown',
                                  size: 24, fill: true, color: t.color),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          t.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      WcpBadge(
                                        color: t.color,
                                        soft: _alpha(t.color, 0x22),
                                        child: Text(
                                            '${Fmt.fa(t.members)} عضو'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    t.perk,
                                    style: TextStyle(
                                        fontSize: 12, color: c.tx3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 13),
                            WcpIcon('chevronL', size: 18, color: c.tx3),
                          ],
                        ),
                      ),
                  ], 10),
                ),
              ],
            ),
            WcpButton(
              label: _savingTiers ? 'در حال ذخیره…' : 'افزودن سطح',
              variant: 'soft',
              full: true,
              icon: 'plus',
              onClick: _savingTiers ? null : () => _addTier(context),
            ),
          ], 14),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COUPON
// ════════════════════════════════════════════════════════════════
class _Coupon {
  const _Coupon({
    this.id = 0,
    required this.code,
    required this.type,
    required this.desc,
    required this.used,
    required this.limit,
    required this.on,
    required this.color,
  });
  final int id;
  final String code;
  final String type;
  final String desc;
  final int used;
  final int limit;
  final bool on;
  final Color color;
}

class CouponModuleScreen extends StatefulWidget {
  const CouponModuleScreen({super.key});

  @override
  State<CouponModuleScreen> createState() => _CouponModuleScreenState();
}

class _CouponModuleScreenState extends State<CouponModuleScreen> {
  // Connected → empty + loading (real wc/v3/coupons fill in); disconnected →
  // the design-reference sample so the preview isn't blank.
  List<_Coupon> _coupons = StoreApi.hasStore
      ? const <_Coupon>[]
      : const <_Coupon>[
          _Coupon(
              code: 'NOWRUZ1405',
              type: '٪۳۰',
              desc: 'تخفیف نوروزی',
              used: 142,
              limit: 500,
              on: true,
              color: Color(0xFF34D399)),
          _Coupon(
              code: 'WELCOME',
              type: '۵۰ هزار',
              desc: 'خوش‌آمد مشتری جدید',
              used: 88,
              limit: 1000,
              on: true,
              color: Color(0xFF8B5CF6)),
          _Coupon(
              code: 'VIP20',
              type: '٪۲۰',
              desc: 'ویژه اعضای طلایی',
              used: 34,
              limit: 100,
              on: true,
              color: Color(0xFFE0A52E)),
          _Coupon(
              code: 'SUMMER',
              type: '٪۱۵',
              desc: 'حراج تابستان',
              used: 0,
              limit: 300,
              on: false,
              color: Color(0xFFFB7185)),
        ];
  bool _loading = StoreApi.hasStore;

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) _load();
  }

  Future<void> _load() async {
    final StoreResult res = await StoreApi.coupons(perPage: 50);
    if (!mounted) return;
    if (!res.ok) {
      setState(() => _loading = false);
      return;
    }
    final List<_Coupon> real = <_Coupon>[
      for (int i = 0; i < res.list.length; i++) _couponFromWoo(res.list[i], i),
    ];
    setState(() {
      _coupons = real; // real coupons (may be empty — honest, not sample)
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final nav = AppScope.of(context);
    final List<_Coupon> coupons = _coupons;
    final int activeCount = coupons.where((x) => x.on).length;
    final int totalUsed = coupons.fold<int>(0, (s, x) => s + x.used);

    return _ModuleScaffold(
      appBar: WcpAppBar(
        title: 'کوپن و تخفیف',
        sub: 'بازاریابی',
        onBack: nav.pop,
        actions: [
          IconBtn(
            name: 'plus',
            onClick: () => nav.push('couponCreate'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _vgap([
            // stat cards grid 1fr 1fr gap 11
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: WcpCard(
                    pad: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('کوپن فعال',
                            style:
                                TextStyle(fontSize: 11.5, color: c.tx3)),
                        const SizedBox(height: 3),
                        Text(
                          Fmt.fa(activeCount),
                          style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: c.success),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: WcpCard(
                    pad: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('استفاده کل',
                            style:
                                TextStyle(fontSize: 11.5, color: c.tx3)),
                        const SizedBox(height: 3),
                        Text(
                          Fmt.fa(totalUsed),
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_loading && coupons.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (coupons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'هنوز کوپنی ساخته نشده است.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: c.tx3),
                ),
              )
            else
              for (final cp in coupons) _CouponCard(coupon: cp),
          ], 12),
        ),
      ),
    );
  }
}

// wc/v3 coupon JSON → the local _Coupon card model.
_Coupon _couponFromWoo(Map<String, dynamic> j, int i) {
  const List<Color> palette = <Color>[
    Color(0xFF34D399),
    Color(0xFF8B5CF6),
    Color(0xFFE0A52E),
    Color(0xFFFB7185),
    Color(0xFF06B6D4),
  ];
  final String dtype = (j['discount_type'] ?? 'percent').toString();
  final num amount = num.tryParse((j['amount'] ?? '0').toString()) ?? 0;
  final String type =
      dtype == 'percent' ? '٪${Fmt.fa(amount.toInt())}' : Fmt.tomanShort(amount);
  final String desc = (j['description'] ?? '').toString().trim();
  return _Coupon(
    id: int.tryParse((j['id'] ?? 0).toString()) ?? 0,
    code: (j['code'] ?? '').toString().toUpperCase(),
    type: type,
    desc: desc.isEmpty ? 'کد تخفیف' : desc,
    used: int.tryParse((j['usage_count'] ?? 0).toString()) ?? 0,
    limit: j['usage_limit'] == null
        ? 0
        : (int.tryParse(j['usage_limit'].toString()) ?? 0),
    on: (j['status'] ?? 'publish').toString() == 'publish',
    color: palette[i % palette.length],
  );
}

class _CouponCard extends StatefulWidget {
  const _CouponCard({required this.coupon});
  final _Coupon coupon;

  @override
  State<_CouponCard> createState() => _CouponCardState();
}

class _CouponCardState extends State<_CouponCard> {
  late bool _on = widget.coupon.on;
  bool _busy = false;

  // Real enable/disable — wc/v3 coupon status publish↔draft. Optimistic flip,
  // reverts on failure.
  Future<void> _toggle(bool v) async {
    if (_busy || widget.coupon.id <= 0) return;
    final nav = AppScope.of(context);
    setState(() {
      _on = v;
      _busy = true;
    });
    final StoreResult r = await StoreApi.updateCoupon(
        widget.coupon.id, {'status': v ? 'publish' : 'draft'});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      nav.showToast(v ? 'کوپن فعال شد' : 'کوپن غیرفعال شد',
          kind: v ? 'success' : 'info');
    } else {
      setState(() => _on = !v); // revert
      nav.showToast(r.error ?? 'تغییر وضعیت کوپن ناموفق بود.',
          kind: 'error', icon: 'alert');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final _Coupon coupon = widget.coupon;
    return Opacity(
      opacity: _on ? 1 : 0.6,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.bg1,
          border: Border.all(color: c.line, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // left stub: width 76, color tile + dashed separator
              Container(
                width: 76,
                decoration: BoxDecoration(
                  color: _alpha(coupon.color, 0x1F),
                  border: Border(
                    left: BorderSide(color: c.line, width: 2),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    WcpIcon('coupon', size: 22, color: coupon.color),
                    const SizedBox(height: 3),
                    Text(
                      coupon.type,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: coupon.color,
                      ),
                    ),
                  ],
                ),
              ),
              // body
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                coupon.code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          WcpSwitch(
                            on: _on,
                            size: 'sm',
                            onChange: _busy ? null : _toggle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        coupon.desc,
                        style: TextStyle(fontSize: 12, color: c.tx3),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('استفاده',
                              style: TextStyle(fontSize: 11, color: c.tx3)),
                          Text(
                            '${Fmt.fa(coupon.used)} از ${Fmt.fa(coupon.limit)}',
                            style: TextStyle(fontSize: 11, color: c.tx3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Bar(
                        value: coupon.used / coupon.limit * 100,
                        color: coupon.color,
                        h: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COUPON CREATE
// ════════════════════════════════════════════════════════════════
class CouponCreateScreen extends StatefulWidget {
  const CouponCreateScreen({super.key});

  @override
  State<CouponCreateScreen> createState() => _CouponCreateScreenState();
}

class _CouponCreateScreenState extends State<CouponCreateScreen> {
  String _code = '';
  String _type = 'percent';
  String _val = '';
  bool _busy = false;

  /// Normalize Persian/Arabic-Indic digits + Persian decimal mark to ASCII so
  /// the typed amount is a valid number for the WC REST API.
  static String _enDigits(String s) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in s.trim().split('')) {
      final fi = fa.indexOf(ch);
      final ai = ar.indexOf(ch);
      if (fi >= 0) {
        b.write(fi);
      } else if (ai >= 0) {
        b.write(ai);
      } else if (ch == '٫' || ch == '،') {
        b.write('.');
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }

  // Create the coupon for real on the connected store (wc/v3/coupons).
  Future<void> _create(BuildContext context) async {
    if (_busy) return;
    final String code = _code.trim();
    if (code.isEmpty) {
      AppScope.of(context)
          .showToast('ابتدا کد کوپن را وارد کنید یا تولید کنید.', kind: 'error', icon: 'alert');
      return;
    }
    final String amount = _type == 'ship' ? '0' : _enDigits(_val);
    if (_type != 'ship' && (amount.isEmpty || (double.tryParse(amount) ?? 0) <= 0)) {
      AppScope.of(context)
          .showToast('مقدار تخفیف معتبر نیست.', kind: 'error', icon: 'alert');
      return;
    }
    setState(() => _busy = true);
    final Map<String, dynamic> body = <String, dynamic>{
      'code': code,
      'discount_type': _type == 'percent'
          ? 'percent'
          : (_type == 'fixed' ? 'fixed_cart' : 'percent'),
      'amount': amount,
      if (_type == 'ship') 'free_shipping': true,
    };
    final StoreResult r = await StoreApi.createCoupon(body);
    if (!context.mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      AppScope.of(context).pop();
      AppScope.of(context).showToast('کوپن «$code» ساخته شد', kind: 'success', icon: 'coupon');
    } else {
      AppScope.of(context).showToast(
        r.error ?? 'ساخت کوپن ناموفق بود (شاید کد تکراری است).',
        kind: 'error',
        icon: 'alert',
      );
    }
  }

  void _gen() {
    final rnd = math.Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final tail = List.generate(
        5, (_) => chars[rnd.nextInt(chars.length)]).join();
    setState(() => _code = 'OFF$tail');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final nav = AppScope.of(context);
    final saBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        children: [
          WcpAppBar(title: 'کوپن جدید', onBack: nav.pop),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _vgap([
                    // code + random
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('کد تخفیف'),
                        const SizedBox(height: 9),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: WcpField(
                                value: _code,
                                onChange: (v) => setState(() => _code = v),
                                placeholder: 'مثلا NOWRUZ',
                                dir: TextDirection.ltr,
                                icon: 'coupon',
                              ),
                            ),
                            const SizedBox(width: 9),
                            WcpButton(
                              label: 'تصادفی',
                              variant: 'soft',
                              icon: 'refresh',
                              onClick: _gen,
                            ),
                          ],
                        ),
                      ],
                    ),
                    // type segmented
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('نوع تخفیف'),
                        const SizedBox(height: 9),
                        Segmented(
                          full: true,
                          value: _type,
                          onChange: (v) => setState(() => _type = v),
                          options: const [
                            (value: 'percent', label: 'درصدی'),
                            (value: 'fixed', label: 'مبلغ ثابت'),
                            (value: 'ship', label: 'ارسال رایگان'),
                          ],
                        ),
                      ],
                    ),
                    if (_type != 'ship')
                      WcpField(
                        label: 'مقدار تخفیف',
                        value: _val,
                        onChange: (v) => setState(() => _val = v),
                        suffix: _type == 'percent' ? '٪' : 'تومان',
                        dir: TextDirection.ltr,
                        icon: 'percent',
                      ),
                    const WcpField(
                      label: 'حداکثر استفاده',
                      value: '۵۰۰',
                      dir: TextDirection.ltr,
                      suffix: 'بار',
                      icon: 'users',
                    ),
                    const WcpField(
                      label: 'تاریخ انقضا',
                      value: '۱۴۰۵/۰۱/۱۵',
                      dir: TextDirection.ltr,
                      icon: 'calendar',
                    ),
                    const WcpCard(
                      pad: 0,
                      child: Column(
                        children: [
                          ModSettingRow(
                            label: 'فقط مشتریان جدید',
                            sub: 'یک‌بار برای هر کاربر',
                            initial: false,
                            icon: 'user',
                            color: Color(0xFF8B5CF6),
                          ),
                          _Divider(),
                          ModSettingRow(
                            label: 'ترکیب با سایر تخفیف‌ها',
                            sub: 'قابل استفاده با کوپن دیگر',
                            initial: false,
                            icon: 'layers',
                            color: Color(0xFF8B5CF6),
                          ),
                        ],
                      ),
                    ),
                  ], 16),
                ),
              ),
            ),
          ),
          // sticky bottom action bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, saBottom + 12),
            decoration: BoxDecoration(
              color: c.bg0,
              border: Border(top: BorderSide(color: c.line, width: 1)),
            ),
            child: WcpButton(
              label: _busy ? 'در حال ساخت…' : 'ساخت کوپن',
              full: true,
              size: 'lg',
              icon: 'check',
              disabled: _busy,
              onClick: () => _create(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MARKETPLACES (divar / basalam sync)
// ════════════════════════════════════════════════════════════════
class _Market {
  const _Market({
    required this.name,
    required this.color,
    required this.synced,
    required this.errors,
    required this.on,
    required this.icon,
  });
  final String name;
  final Color color;
  final int synced;
  final int errors;
  final bool on;
  final String icon;
}

class MarketModuleScreen extends StatefulWidget {
  const MarketModuleScreen({super.key});

  @override
  State<MarketModuleScreen> createState() => _MarketModuleScreenState();
}

class _MarketModuleScreenState extends State<MarketModuleScreen> {
  // Real per-provider state (#17) — read from the curated marketplaces
  // schema (GET /app/module/marketplaces/settings): `{slug}__enabled`
  // toggles + the token/status info rows. No fabricated sync counts.
  Map<String, bool> _enabled = const {};
  Map<String, bool> _hasToken = const {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) _load();
  }

  Future<void> _load() async {
    final StoreResult r = await StoreApi.moduleSchema('marketplaces');
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() => _loaded = true);
      return;
    }
    final Map<String, bool> en = {};
    final Map<String, bool> tok = {};
    for (final dynamic g in (r.map['groups'] as List? ?? const [])) {
      if (g is! Map) continue;
      final String slug = (g['key'] ?? '').toString();
      for (final dynamic f in (g['fields'] as List? ?? const [])) {
        if (f is! Map) continue;
        final String key = (f['key'] ?? '').toString();
        if (key == '${slug}__enabled') en[slug] = f['value'] == true;
        if (key == '${slug}__status') {
          tok[slug] = (f['value'] ?? '').toString().contains('✓');
        }
        if (key == '${slug}__feed') tok[slug] = true; // Torob's feed is always live
      }
    }
    setState(() {
      _enabled = en;
      _hasToken = tok;
      _loaded = true;
    });
  }

  void _openConfig() =>
      AppScope.of(context).push('mod_marketplaces', {'title': 'بازارگاه‌ها'});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final nav = AppScope.of(context);

    // Connected stores: REAL enabled/token state from the store (sync counts
    // stay 0 until the sync engine ships — never fabricated). The numbered
    // sample below is only the disconnected (demo) preview.
    final List<_Market> markets = StoreApi.hasStore
        ? <_Market>[
            _Market(name: 'باسلام', color: const Color(0xFFF59E0B), synced: 0, errors: 0, on: _enabled['basalam'] ?? false, icon: 'store'),
            _Market(name: 'دیوار', color: const Color(0xFFE11D48), synced: 0, errors: 0, on: _enabled['divar'] ?? false, icon: 'globe'),
            _Market(name: 'ترب', color: const Color(0xFF16A34A), synced: 0, errors: 0, on: _hasToken['torob'] ?? false, icon: 'search'),
            _Market(name: 'دیجی‌کالا', color: const Color(0xFFEF4444), synced: 0, errors: 0, on: _enabled['digikala'] ?? false, icon: 'package'),
          ]
        : const <_Market>[
            _Market(name: 'باسلام', color: Color(0xFFF59E0B), synced: 486, errors: 2, on: true, icon: 'store'),
            _Market(name: 'دیوار', color: Color(0xFFE11D48), synced: 312, errors: 0, on: true, icon: 'globe'),
            _Market(name: 'ترب', color: Color(0xFF16A34A), synced: 486, errors: 0, on: true, icon: 'search'),
            _Market(name: 'دیجی‌کالا', color: Color(0xFFEF4444), synced: 0, errors: 0, on: false, icon: 'package'),
          ];

    return _ModuleScaffold(
      appBar: WcpAppBar(
        title: 'دیوار و ترب',
        sub: 'ایران و پرداخت',
        onBack: nav.pop,
        actions: [
          IconBtn(
            name: 'refresh',
            onClick: () => nav.showToast(
                'همگام‌سازی مارکت‌پلیس‌ها از اپ به‌زودی فعال می‌شود',
                kind: 'info',
                icon: 'refresh'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _vgap([
            // Config CTA (#17) — credentials, enable toggles and REAL
            // test-connection actions live in the curated settings screen.
            WcpCard(
              pad: 16,
              onClick: StoreApi.hasStore
                  ? _openConfig
                  : () => nav.showToast(
                      'در حالت دمو فروشگاهی متصل نیست؛ پس از اتصال از همین‌جا پیکربندی کنید',
                      kind: 'info',
                      icon: 'store'),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: WcpIcon('settings', size: 22, color: c.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('پیکربندی و اتصال بازارگاه‌ها',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          'کلیدهای باسلام، دیجی‌کالا، دیوار، ترب و حساب‌فا را وارد کنید — با تست اتصال واقعی.',
                          style: TextStyle(
                              fontSize: 12.5, color: c.tx3, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  WcpIcon('chevronR', size: 20, color: c.tx3),
                ],
              ),
            ),
            for (final m in markets)
              WcpCard(
                pad: 14,
                onClick: StoreApi.hasStore
                    ? _openConfig
                    : () => nav.showToast(
                        'در حالت دمو، اتصال واقعی در دسترس نیست',
                        kind: 'info', icon: m.icon),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _alpha(m.color, 0x22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: WcpIcon(m.icon, size: 23, color: m.color),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  m.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (m.errors > 0) ...[
                                const SizedBox(width: 7),
                                WcpBadge(
                                  color: c.error,
                                  soft: c.errorSoft,
                                  dot: true,
                                  child: Text('${Fmt.fa(m.errors)} خطا'),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            StoreApi.hasStore
                                ? (m.on
                                    ? 'فعال ✓ — مدیریت از «پیکربندی»'
                                    : (_loaded
                                        ? 'پیکربندی نشده'
                                        : 'در حال دریافت وضعیت…'))
                                : (m.on
                                    ? '${Fmt.fa(m.synced)} محصول همگام'
                                    : 'متصل نشده'),
                            style: TextStyle(fontSize: 12, color: c.tx3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 13),
                    WcpSwitch(
                      on: m.on,
                      size: 'sm',
                      onChange: (_) => StoreApi.hasStore
                          ? _openConfig()
                          : nav.showToast(
                              'در حالت دمو، اتصال واقعی در دسترس نیست',
                              kind: 'info',
                            ),
                    ),
                  ],
                ),
              ),
          ], 12),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Route registration
// ════════════════════════════════════════════════════════════════
//
// `modules.dart` (port of screens-modules.jsx) already registers a
// `mod_<id>` route → its shared `GenericModuleScreen` for EVERY module
// id, and owns the `modules` tab. The JSX here only customises the five
// RICH modules (`RICH_MODULES = { wallet, loyalty, coupon, divar,
// basalam }`); every other id keeps the generic fallback. So this file
// OVERRIDES only those five `mod_*` keys (registerModulePagesScreen is
// invoked AFTER registerModulesScreen in registry.dart), adds the
// `couponCreate` builder, and wires the `genericModule` settings route
// the rich screens push to — delegating it to modules.dart's screen.
// ════════════════════════════════════════════════════════════════

/// Rich screen for a given module id (JSX `RICH_MODULES`).
Widget _richModule(String id) {
  switch (id) {
    case 'loyalty':
      return const LoyaltyModuleScreen();
    case 'coupon':
      return const CouponModuleScreen();
    case 'divar':
    case 'basalam':
      return const MarketModuleScreen();
    case 'wallet':
    default:
      return const WalletModuleScreen();
  }
}

/// Registers the rich `mod_<id>` overrides, the `couponCreate` builder,
/// and the `genericModule` settings route.
void registerModulePagesScreen() {
  // Override only the rich module ids (JSX RICH_MODULES keys).
  for (final id in const ['wallet', 'loyalty', 'coupon', 'divar', 'basalam']) {
    kScreens['mod_$id'] = (ctx, p) => _richModule(id);
  }

  // Coupon builder.
  kScreens['couponCreate'] = (ctx, p) => const CouponCreateScreen();

  // All wallet transactions (paginated «مشاهده همه تراکنش‌ها»).
  kScreens['walletTxns'] = (ctx, p) => const AllWalletTxnsScreen();

  // Generic module settings (reached from the rich modules' settings
  // buttons via `push('genericModule', {'id': ...})`). Delegated to the
  // shared screen from modules.dart.
  kScreens['genericModule'] = (ctx, p) =>
      GenericModuleScreen(id: (p['id'] as String?) ?? sampleModules.first.id);
}

// ════════════════════════════════════════════════════════════════
// WALLET — real top-up / transfer / all-transactions (#574)
// Backed by /app/customer/wallet-credit, /app/wallet/transfer and
// /app/wallet/transactions. No fake success toasts: every action calls the
// store and reports the real result.
// ════════════════════════════════════════════════════════════════

/// Persian/Arabic-Indic digits + decimal mark → ASCII, so a typed amount is a
/// valid number for the REST API (thousands separators are dropped).
String _wxDigits(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.trim().split('')) {
    final fi = fa.indexOf(ch);
    final ai = ar.indexOf(ch);
    if (fi >= 0) {
      b.write(fi);
    } else if (ai >= 0) {
      b.write(ai);
    } else if (ch == '٫' || ch == '،' || ch == ',') {
      // drop thousands separators
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

Future<Customer?> _pickWalletCustomer(BuildContext context, String title) =>
    showWcpSheet<Customer>(context,
        title: title, child: const _WalletCustomerPicker());

/// Searchable customer picker — loads the store's customers once and filters
/// locally; tapping a row returns that [Customer].
class _WalletCustomerPicker extends StatefulWidget {
  const _WalletCustomerPicker();
  @override
  State<_WalletCustomerPicker> createState() => _WalletCustomerPickerState();
}

class _WalletCustomerPickerState extends State<_WalletCustomerPicker> {
  List<Customer> _all = const [];
  String _q = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final StoreResult r = await StoreApi.customers(perPage: 100);
    if (!mounted) return;
    setState(() {
      _all = r.list.map(customerFromWoo).toList();
      _loading = false;
    });
  }

  List<Customer> get _filtered {
    final q = _q.trim();
    if (q.isEmpty) return _all;
    return _all
        .where((x) => x.name.contains(q) || x.phone.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = _filtered;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WcpField(
          value: _q,
          placeholder: 'جستجوی نام یا شماره…',
          icon: 'search',
          onChange: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Text('مشتری‌ای یافت نشد.',
                  style: TextStyle(fontSize: 12.5, color: c.tx3)),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (_, __) => const _Divider(inset: 14),
              itemBuilder: (_, i) => ListRow(
                icon: 'user',
                title: list[i].name,
                sub: list[i].phone.isNotEmpty ? list[i].phone : '—',
                chevron: true,
                onClick: () => Navigator.of(context).pop(list[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Direct manual top-up: pick a customer, enter amount + reason, credit their
/// wallet via /app/customer/wallet-credit.
class _WalletTopupSheet extends StatefulWidget {
  const _WalletTopupSheet();
  @override
  State<_WalletTopupSheet> createState() => _WalletTopupSheetState();
}

class _WalletTopupSheetState extends State<_WalletTopupSheet> {
  Customer? _cust;
  String _amount = '';
  String _reason = '';
  bool _busy = false;

  Future<void> _submit() async {
    final nav = AppScope.of(context);
    final int cid = int.tryParse(_cust?.id ?? '') ?? 0;
    if (cid <= 0) {
      nav.showToast('ابتدا مشتری را انتخاب کنید', kind: 'error', icon: 'alert');
      return;
    }
    final int amt = int.tryParse(_wxDigits(_amount)) ?? 0;
    if (amt <= 0) {
      nav.showToast('مبلغ باید بزرگ‌تر از صفر باشد', kind: 'error', icon: 'alert');
      return;
    }
    if (_reason.trim().isEmpty) {
      nav.showToast('دلیل افزایش اعتبار الزامی است', kind: 'error', icon: 'alert');
      return;
    }
    setState(() => _busy = true);
    final StoreResult res = await StoreApi.appCustomerWalletCredit(
        userId: cid, amount: amt, reason: _reason.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      Navigator.of(context).pop();
      nav.showToast('کیف‌پول ${_cust!.name} شارژ شد',
          kind: 'success', icon: 'check');
    } else {
      nav.showToast(res.error ?? 'افزایش اعتبار ناموفق بود',
          kind: 'error', icon: 'alert');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WalletPickRow(
          label: 'مشتری',
          value: _cust?.name,
          onTap: () async {
            final Customer? p =
                await _pickWalletCustomer(context, 'انتخاب مشتری');
            if (p != null && mounted) setState(() => _cust = p);
          },
        ),
        const SizedBox(height: 10),
        WcpField(
          label: 'مبلغ (تومان)',
          value: _amount,
          dir: TextDirection.ltr,
          icon: 'wallet',
          onChange: (v) => _amount = v,
        ),
        const SizedBox(height: 10),
        WcpField(
          label: 'دلیل افزایش اعتبار (الزامی)',
          value: _reason,
          onChange: (v) => _reason = v,
        ),
        const SizedBox(height: 16),
        WcpButton(
          label: _busy ? 'در حال ثبت…' : 'افزایش اعتبار',
          icon: 'check',
          full: true,
          size: 'lg',
          disabled: _busy,
          onClick: _busy ? null : _submit,
        ),
      ],
    );
  }
}

/// Transfer credit between two customer wallets via /app/wallet/transfer.
class _WalletTransferSheet extends StatefulWidget {
  const _WalletTransferSheet();
  @override
  State<_WalletTransferSheet> createState() => _WalletTransferSheetState();
}

class _WalletTransferSheetState extends State<_WalletTransferSheet> {
  Customer? _from;
  Customer? _to;
  String _amount = '';
  String _reason = '';
  bool _busy = false;

  Future<void> _submit() async {
    final nav = AppScope.of(context);
    final int from = int.tryParse(_from?.id ?? '') ?? 0;
    final int to = int.tryParse(_to?.id ?? '') ?? 0;
    if (from <= 0 || to <= 0) {
      nav.showToast('فرستنده و گیرنده را انتخاب کنید', kind: 'error', icon: 'alert');
      return;
    }
    if (from == to) {
      nav.showToast('فرستنده و گیرنده باید متفاوت باشند',
          kind: 'error', icon: 'alert');
      return;
    }
    final int amt = int.tryParse(_wxDigits(_amount)) ?? 0;
    if (amt <= 0) {
      nav.showToast('مبلغ باید بزرگ‌تر از صفر باشد', kind: 'error', icon: 'alert');
      return;
    }
    if (_reason.trim().isEmpty) {
      nav.showToast('دلیل انتقال الزامی است', kind: 'error', icon: 'alert');
      return;
    }
    setState(() => _busy = true);
    final StoreResult res = await StoreApi.walletTransfer(
        fromUser: from, toUser: to, amount: amt, reason: _reason.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      Navigator.of(context).pop();
      nav.showToast('انتقال از ${_from!.name} به ${_to!.name} انجام شد',
          kind: 'success', icon: 'check');
    } else {
      nav.showToast(res.error ?? 'انتقال ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WalletPickRow(
          label: 'از کیف‌پول',
          value: _from?.name,
          onTap: () async {
            final Customer? p =
                await _pickWalletCustomer(context, 'انتخاب فرستنده');
            if (p != null && mounted) setState(() => _from = p);
          },
        ),
        const SizedBox(height: 10),
        _WalletPickRow(
          label: 'به کیف‌پول',
          value: _to?.name,
          onTap: () async {
            final Customer? p =
                await _pickWalletCustomer(context, 'انتخاب گیرنده');
            if (p != null && mounted) setState(() => _to = p);
          },
        ),
        const SizedBox(height: 10),
        WcpField(
          label: 'مبلغ (تومان)',
          value: _amount,
          dir: TextDirection.ltr,
          icon: 'send',
          onChange: (v) => _amount = v,
        ),
        const SizedBox(height: 10),
        WcpField(
          label: 'دلیل انتقال (الزامی)',
          value: _reason,
          onChange: (v) => _reason = v,
        ),
        const SizedBox(height: 16),
        WcpButton(
          label: _busy ? 'در حال انتقال…' : 'انتقال اعتبار',
          icon: 'send',
          full: true,
          size: 'lg',
          disabled: _busy,
          onClick: _busy ? null : _submit,
        ),
      ],
    );
  }
}

/// A tappable "picker" row used inside the wallet sheets.
class _WalletPickRow extends StatelessWidget {
  const _WalletPickRow(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WcpCard(
      pad: 0,
      child: ListRow(
        icon: 'user',
        title: label,
        sub: (value == null || value!.isEmpty) ? 'انتخاب کنید' : value!,
        chevron: true,
        onClick: onTap,
      ),
    );
  }
}

/// Paginated store-wide wallet ledger («مشاهده همه تراکنش‌ها»).
class AllWalletTxnsScreen extends StatefulWidget {
  const AllWalletTxnsScreen({super.key});
  @override
  State<AllWalletTxnsScreen> createState() => _AllWalletTxnsScreenState();
}

class _AllWalletTxnsScreenState extends State<AllWalletTxnsScreen> {
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final StoreResult r =
        await StoreApi.walletTransactions(page: _page, perPage: 30);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _total =
            r.map['total'] is num ? (r.map['total'] as num).toInt() : _total;
        _items.addAll(r.list);
        _more = _items.length < _total;
      }
    });
  }

  Future<void> _loadMore() async {
    _page++;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      color: c.bg0,
      child: Column(
        children: [
          WcpAppBar(
            title: 'همه تراکنش‌ها',
            sub: _total > 0 ? '${Fmt.fa(_total)} تراکنش' : null,
            onBack: () => AppScope.of(context).pop(),
          ),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.only(top: 40),
                        children: const [
                          EmptyState(
                            icon: 'wallet',
                            title: 'تراکنشی نیست',
                            message:
                                'هنوز هیچ تراکنش کیف‌پولی ثبت نشده است.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(16, 12, 16,
                            MediaQuery.of(context).padding.bottom + 16),
                        itemCount: _items.length + (_more ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 9),
                        itemBuilder: (_, i) {
                          if (i >= _items.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: WcpButton(
                                label: _loading
                                    ? 'در حال بارگذاری…'
                                    : 'بارگذاری بیشتر',
                                variant: 'secondary',
                                full: true,
                                disabled: _loading,
                                onClick: _loading ? null : _loadMore,
                              ),
                            );
                          }
                          return _AllTxnCard(row: _items[i]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AllTxnCard extends StatelessWidget {
  const _AllTxnCard({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final String type = (row['type'] ?? '').toString().toLowerCase();
    final bool isIn = type.contains('credit') ||
        type.contains('refund') ||
        type.contains('topup') ||
        type.contains('cashback') ||
        type.contains('gift');
    final Map amt = row['amount'] is Map ? row['amount'] as Map : const {};
    final String amtDisp = (amt['display'] ?? '').toString();
    final String who = (row['user_name'] ?? '—').toString();
    String title = (row['reason'] ?? '').toString().trim();
    if (title.isEmpty) {
      final int oid =
          row['order_id'] is num ? (row['order_id'] as num).toInt() : 0;
      title = oid > 0
          ? 'سفارش #${Fmt.fa(oid)}'
          : (isIn ? 'افزایش اعتبار' : 'برداشت');
    }
    final String when = (row['created_at'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (isIn ? c.success : c.error).withAlpha(0x22),
              borderRadius: BorderRadius.circular(11),
            ),
            child: WcpIcon(isIn ? 'arrowDown' : 'arrowUp',
                size: 18, color: isIn ? c.success : c.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('$who · $when',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: c.tx3)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            (isIn ? '+ ' : '− ') + amtDisp,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isIn ? c.success : c.error,
            ),
          ),
        ],
      ),
    );
  }
}
