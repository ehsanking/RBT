// ════════════════════════════════════════════════════════════════
// more.dart — More tab + Settings  (ported from screens-more.jsx)
//
// Screens:
//   MoreScreen      → route 'more'      (tab root)
//   SettingsScreen  → route 'settings'
//
// The JSX `LogoutSheet` is a bottom-sheet body opened from MoreScreen;
// it is reproduced inline via showWcpSheet. There is no `setPhase('lock')`
// machine in the real app (launch/lock was prototype-only studio chrome),
// so confirming logout closes the sheet and surfaces a toast.
//
// The «پشتیبانی و تعامل» row no longer carries a fabricated count badge;
// SupportHub shows the real per-channel counts when opened.
// ════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/fmt.dart';
import '../core/icons.dart';
import '../core/native.dart';
import '../core/shake_report.dart';
import '../core/subs.dart';
import '../data/sample.dart';
import '../nav/shell.dart';
import '../services/portal_api.dart';
import '../services/store_api.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'registry.dart';

// One actionable row inside a More-tab group.
class _MoreItem {
  final String icon;
  final String label;
  final String sub;
  final Color color;
  final void Function(BuildContext) go;
  final bool premium;
  const _MoreItem({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.go,
    this.premium = false,
  });
}

class _MoreGroup {
  final String title;
  final List<_MoreItem> items;
  const _MoreGroup(this.title, this.items);
}

// Brand gold used for the «مالک» badge + premium accents (#e0a52e).
const Color _gold = Color(0xFFE0A52E);
const Color _goldSoft = Color(0x29E0A52E); // rgba(224,165,46,.16)

/// App version, injected at build time via
/// `--dart-define=APP_VERSION=<pubspec.version>` so the footer line and the
/// «دستگاه‌های فعال» screen never go stale relative to pubspec.yaml.
const String _appVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: kAppVersionLabel);

/// `1.0.0+4` → «۱٫۰٫۰ (۴)». The raw `semver+build` string renders mangled on an
/// RTL line — the `+build` suffix gets bidi-reordered to the front, so the
/// footer showed a confusing «۴٫۱٫۰٫۰». Splitting on `+` and parenthesising the
/// build keeps each piece a clean, correctly-ordered number run.
String _versionLabel() {
  final List<String> parts = _appVersion.split('+');
  final String semver = Fmt.fa(parts[0]);
  if (parts.length > 1 && parts[1].isNotEmpty) {
    return '$semver (${Fmt.fa(parts[1])})';
  }
  return semver;
}

/// Persian display names for the currency codes an Iranian store usually
/// touches; anything else falls back to WooCommerce's own option label, then
/// the bare code. Used by the «واحد پول» setting so it follows WooCommerce.
const Map<String, String> _faCurrencyNames = {
  'IRT': 'تومان',
  'IRR': 'ریال',
  'USD': 'دلار آمریکا',
  'EUR': 'یورو',
  'AED': 'درهم امارات',
  'TRY': 'لیر ترکیه',
  'GBP': 'پوند انگلیس',
  'CNY': 'یوان چین',
  'IQD': 'دینار عراق',
};

String _currencyDisplay(String code, String wcLabel) =>
    _faCurrencyNames[code] ?? (wcLabel.isNotEmpty ? wcLabel : code);

/// «صدای گفتگو» (ITEM 6) — the chat-notification tone. Tapping the row opens
/// the SYSTEM ringtone picker (Native.pickNotificationSound) which already
/// offers Default + Silent + every installed tone; native persists the chosen
/// URI + rebuilds the notification channel. We cache only the display LABEL
/// (shared_prefs 'chat_sound_label') to show on the row.
const String _chatSoundDefaultLabel = 'پیش‌فرض سیستم';

// ════════════════════════════════════════════════════════════════
// MORE TAB
// ════════════════════════════════════════════════════════════════
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  List<_MoreGroup> _groups(BuildContext context) {
    final c = context.c;
    return [
      _MoreGroup('مشتریان و تعامل', [
        _MoreItem(
          icon: 'inbox',
          label: 'پشتیبانی و تعامل',
          sub: 'تیکت، نظرات، پرسش‌ها، کاربران',
          color: c.accent,
          // No fabricated badge — the old constant «۹» (2 tickets+4 comments+
          // 3 q&a from the prototype) was fake. The SupportHub screen itself
          // shows real counts; a real aggregate badge can be wired later (#553).
          go: (ctx) => AppScope.of(ctx).push('supportHub'),
        ),
        _MoreItem(
          icon: 'users',
          label: 'مشتریان',
          sub: 'مدیریت و باشگاه مشتریان',
          color: c.info,
          go: (ctx) => AppScope.of(ctx).push('customers'),
        ),
      ]),
      _MoreGroup('فروشگاه', [
        _MoreItem(
          icon: 'store',
          label: 'اطلاعات فروشگاه',
          sub: StoreApi.siteHost ?? sampleStore.domain,
          color: c.accent,
          go: (ctx) => AppScope.of(ctx).push('settings'),
        ),
        _MoreItem(
          icon: 'settings',
          label: 'تنظیمات عمومی فروشگاه',
          sub: 'تقویم جلالی، اعداد فارسی، پوسته، رنگ برند…',
          color: c.accent,
          go: (ctx) => AppScope.of(ctx).push('moduleSettings', {
            'key': 'general',
            'title': 'تنظیمات عمومی فروشگاه',
            'useConfig': true,
          }),
        ),
        _MoreItem(
          icon: 'layers',
          label: 'محتوا',
          sub: 'نوشته‌ها، برگه‌ها و انواع محتوای سفارشی',
          color: c.info,
          go: (ctx) => AppScope.of(ctx).push('content'),
        ),
        _MoreItem(
          icon: 'users',
          label: 'تیم و دسترسی‌ها',
          sub: 'مدیریت کاربران',
          color: c.info,
          go: (ctx) => AppScope.of(ctx).push('team'),
        ),
        _MoreItem(
          icon: 'card',
          label: 'درگاه‌های پرداخت',
          sub: 'اعتبارها، فعال‌سازی و تست اتصال',
          color: c.success,
          go: (ctx) => AppScope.of(ctx).push('mod_payments_providers'),
        ),
        _MoreItem(
          icon: 'truck',
          label: 'روش‌های ارسال',
          sub: 'فعال/غیرفعال‌سازی در همین‌جا',
          color: c.warning,
          go: (ctx) => AppScope.of(ctx).push('shipping'),
        ),
      ]),
      _MoreGroup('حساب کاربری', [
        _MoreItem(
          icon: 'crown',
          label: 'اشتراک و صورت‌حساب',
          // Inside the app the plan is always active (entry is gated on it),
          // so show days-remaining when known, else a neutral «مدیریت اشتراک»
          // — never «غیرفعال»/upgrade framing.
          sub: (Subs.active && Subs.daysLeft > 0)
              ? '${Fmt.fa(Subs.daysLeft)} روز باقی‌مانده'
              : 'مدیریت اشتراک',
          color: _gold,
          premium: true,
          go: (ctx) => AppScope.of(ctx).push('subscription'),
        ),
        _MoreItem(
          icon: 'bell',
          label: 'تنظیمات اعلان',
          sub: 'پوش، ایمیل، پیامک',
          color: c.accent,
          go: (ctx) => AppScope.of(ctx).push('settings'),
        ),
        _MoreItem(
          icon: 'shield',
          label: 'امنیت و حریم خصوصی',
          sub: 'قفل، رمز عبور',
          color: c.error,
          go: (ctx) => AppScope.of(ctx).push('settings'),
        ),
      ]),
      _MoreGroup('پشتیبانی', [
        _MoreItem(
          icon: 'help',
          label: 'راهنما و آموزش',
          sub: 'سوالات متداول',
          color: c.info,
          go: (ctx) => AppScope.of(ctx).push('support'),
        ),
        _MoreItem(
          icon: 'message',
          label: 'گفت‌وگو با پشتیبانی',
          sub: 'پاسخ ظرف ۲۴ ساعت',
          color: c.success,
          go: (ctx) => AppScope.of(ctx).push('support'),
        ),
        _MoreItem(
          icon: 'star',
          label: 'امتیاز به اپلیکیشن',
          sub: 'در کافه‌بازار',
          color: c.warning,
          go: (ctx) => launchUrl(
              Uri.parse(
                  'https://cafebazaar.ir/app/com.woocommercemanager.wcp_premium'),
              mode: LaunchMode.externalApplication),
        ),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final topPad = MediaQuery.of(context).padding.top;
    final groups = _groups(context);
    final String storeName = StoreApi.storeName ?? StoreApi.siteHost ?? 'فروشگاه شما';
    final String storeHost = StoreApi.siteHost ?? sampleStore.domain;

    return ListView(
      // reserve the floating tab-bar height so the last row (shipping
      // methods) clears the bottom nav.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      children: [
        // ── header + profile card ──
        Padding(
          padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'بیشتر',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              WcpCard(
                pad: 16,
                glow: true,
                onClick: () => AppScope.of(context).push('settings'),
                child: Row(
                  children: [
                    Avatar(
                        name: storeName,
                        size: 56,
                        color: const Color(0xFF7C3AED),
                        // Real store logo (WP Site Icon) next to the name;
                        // falls back to initials when none is set.
                        imageUrl: StoreApi.storeLogo),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  storeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 7),
                              const WcpBadge(
                                color: _gold,
                                soft: _goldSoft,
                                child: Text('مالک'),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                storeHost,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 12.5, color: c.tx3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    WcpIcon('chevronL', size: 20, color: c.tx3),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── premium banner ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _PremiumBanner(
            onTap: () => AppScope.of(context).push('subscription'),
          ),
        ),

        // ── promo slider (merchant-controlled from WP-admin → اتصال اپ →
        // اسلایدر). Renders nothing when disconnected or when no slides. ──
        const _MoreSlider(),

        // ── groups + footer ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var gi = 0; gi < groups.length; gi++) ...[
                _GroupBlock(group: groups[gi]),
                if (gi < groups.length - 1) const SizedBox(height: 18),
              ],
              const SizedBox(height: 18),
              WcpButton(
                variant: 'danger',
                full: true,
                icon: 'logout',
                label: 'خروج از حساب',
                onClick: () => _openLogoutSheet(context),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'نسخه ${_versionLabel()} · WPP · ساخته‌شده برای ووکامرس پلاس',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: c.tx3),
                ),
              ),
              // Copyright / credits — Instagram + website as tappable icons.
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CreditIcon(
                      icon: 'instagram',
                      tooltip: 'instagram.com/ehsanking',
                      onTap: () => launchUrl(
                        Uri.parse('https://instagram.com/ehsanking'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    const SizedBox(width: 14),
                    _CreditIcon(
                      icon: 'globe',
                      tooltip: 'wooplusplugin.com',
                      onTap: () => launchUrl(
                        Uri.parse('https://wooplusplugin.com'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openLogoutSheet(BuildContext context) {
    showWcpSheet<void>(
      context,
      title: 'خروج از حساب',
      child: _LogoutSheetBody(rootContext: context),
    );
  }
}

// ── A titled group: small caption + a pad-0 card of rows ──────────
// A round, tappable credit icon (Instagram / website) for the footer.
class _CreditIcon extends StatelessWidget {
  const _CreditIcon(
      {required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.bg2,
            shape: BoxShape.circle,
            border: Border.all(color: c.line, width: 1),
          ),
          child: WcpIcon(icon, size: 19, color: c.tx2),
        ),
      ),
    );
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({required this.group});

  final _MoreGroup group;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = group.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 9),
          child: Text(
            group.title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: c.tx3,
            ),
          ),
        ),
        WcpCard(
          pad: 0,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                ListRow(
                  icon: items[i].icon,
                  iconColor: items[i].color,
                  title: items[i].label,
                  sub: items[i].sub,
                  chevron: true,
                  onClick: () => items[i].go(context),
                  trailing: items[i].premium
                      ? const WcpBadge(
                          color: _gold,
                          soft: _goldSoft,
                          child: Text('ویژه'),
                        )
                      : null,
                ),
                if (i < items.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(height: 1, color: c.line),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Promo slider — merchant-controlled carousel under the premium banner.
// Managed in WP-admin (WooCommerce+ → اتصال اپ → اسلایدر), fetched from
// `/app/slider`. Renders NOTHING when disconnected or when there are no
// enabled slides, so the More tab is unaffected for stores that don't use
// it. Each slide can open an external URL or navigate to an in-app route.
// ════════════════════════════════════════════════════════════════
class _Slide {
  final String id;
  final String title;
  final String subtitle;
  final String image;
  final String link;
  const _Slide({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.link,
  });

  static _Slide fromJson(Map<String, dynamic> m) => _Slide(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        subtitle: (m['subtitle'] ?? '').toString(),
        image: (m['image'] ?? '').toString(),
        link: (m['link'] ?? '').toString(),
      );
}

class _MoreSlider extends StatefulWidget {
  const _MoreSlider();

  @override
  State<_MoreSlider> createState() => _MoreSliderState();
}

class _MoreSliderState extends State<_MoreSlider> {
  List<_Slide> _slides = const [];
  final PageController _pc = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Centrally managed in the WPP portal (not the merchant store), so it's
    // the same promo carousel for every install — fetched from PortalApi.
    final List<Map<String, dynamic>> raw = await PortalApi.appSlider();
    if (!mounted || raw.isEmpty) return;
    final List<_Slide> next = raw
        .map(_Slide.fromJson)
        .where((s) => s.image.isNotEmpty || s.title.isNotEmpty)
        .toList();
    if (next.isEmpty) return;
    setState(() => _slides = next);
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    if (_slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pc.hasClients) return;
      final int next = (_page + 1) % _slides.length;
      _pc.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  void _open(_Slide s) {
    final String link = s.link.trim();
    if (link.isEmpty) return;
    if (link.startsWith('http://') || link.startsWith('https://')) {
      launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } else {
      AppScope.of(context).push(link);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_slides.isEmpty) return const SizedBox.shrink();
    final c = context.c;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Column(
        children: [
          SizedBox(
            height: 116,
            child: PageView.builder(
              controller: _pc,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _SlideCard(
                slide: _slides[i],
                onTap: () => _open(_slides[i]),
              ),
            ),
          ),
          if (_slides.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _slides.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? c.accent : c.line,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide, required this.onTap});

  final _Slide slide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bool hasImg = slide.image.isNotEmpty;
    final bool hasText = slide.title.isNotEmpty || slide.subtitle.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.accentSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line, width: 1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImg)
              Image.network(
                slide.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: c.accentSoft),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : Container(color: c.accentSoft),
              ),
            // Bottom scrim so white text stays legible over any photo.
            if (hasImg && hasText)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
              ),
            if (hasText)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (slide.title.isNotEmpty)
                        Text(
                          slide.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: hasImg ? const Color(0xFFFFFFFF) : c.tx1,
                          ),
                        ),
                      if (slide.subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            slide.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: hasImg
                                  ? const Color(0xE6FFFFFF)
                                  : c.tx2,
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
}

// ── Premium gradient banner ──────────────────────────────────────
class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const white = Color(0xFFFFFFFF);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: c.shadowAccent,
          gradient: const LinearGradient(
            // CSS 120deg → begin top-right, end bottom-left.
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFFC084FC)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // decorative circle (top:-20, left:-10, 90×90, white .12)
              Positioned(
                top: -20,
                left: -10,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x1FFFFFFF), // rgba(255,255,255,.12)
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF), // rgba(255,255,255,.2)
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const WcpIcon('crown',
                        size: 26, fill: true, color: white),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    // App access REQUIRES an active subscription (the launch
                    // gate blocks entry otherwise), so inside the app the
                    // banner always reflects an active plan — no «upgrade».
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اشتراک پرمیوم فعال',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: white,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Opacity(
                            opacity: 0.9,
                            child: Text(
                              'زمان باقی‌مانده اشتراک شما',
                              style: TextStyle(fontSize: 12.5, color: white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Days-remaining badge pinned to the LEFT of the banner —
                  // real value from the stored expiry; hidden when inactive
                  // (never the fabricated 248).
                  if (Subs.active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF), // rgba(255,255,255,.2)
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${Fmt.fa(Subs.daysLeft)} روز',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: white,
                        ),
                      ),
                    ),
                  if (Subs.active) const SizedBox(width: 8),
                  const WcpIcon('chevronL', size: 20, color: white),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logout confirmation sheet body ───────────────────────────────
class _LogoutSheetBody extends StatelessWidget {
  const _LogoutSheetBody({required this.rootContext});

  /// Context that owns AppScope / the sheet route (for toast + pop).
  final BuildContext rootContext;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: c.errorSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: WcpIcon('logout', size: 28, color: c.error),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              'آیا مطمئن هستید که می‌خواهید از حساب خود خارج شوید؟',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.7,
                color: c.tx2,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: WcpButton(
                  variant: 'secondary',
                  full: true,
                  label: 'انصراف',
                  onClick: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: WcpButton(
                  variant: 'dangerSolid',
                  full: true,
                  label: 'خروج',
                  onClick: () {
                    Navigator.of(context).pop();
                    // Real sign-out: clears the stored credentials and returns
                    // to the connect screen (was a cosmetic toast before).
                    AppScope.of(rootContext).logout();
                  },
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
// SETTINGS
// ════════════════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _push = true;
  bool _email = true;
  bool _sms = false;
  bool _biometric = true;
  bool _sound = true;
  bool _shakeReport = true; // «گزارش خطا با تکان دادن»
  // Chat-notification tone (ITEM 6) — persisted as a string key, picker-driven.
  String _chatSound = _chatSoundDefaultLabel;

  // Live store currency, mirrored from WooCommerce (general settings).
  String _currencyCode = '';
  String _currencyLabel = 'تومان';
  Map<String, String> _currencyOptions = const <String, String>{};
  bool _currencyBusy = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadCurrency();
  }

  // Pull the store's active currency + the full code→label option map so the
  // «واحد پول» row reflects WooCommerce rather than a hardcoded «تومان».
  Future<void> _loadCurrency() async {
    if (!StoreApi.hasStore) return;
    final StoreResult r = await StoreApi.getWcCurrency();
    if (!mounted || !r.ok) return;
    final Map<String, dynamic> m = r.map;
    final String code = (m['value'] ?? '').toString();
    final Map opts = (m['options'] is Map) ? m['options'] as Map : const {};
    setState(() {
      _currencyCode = code;
      _currencyOptions =
          opts.map((k, v) => MapEntry(k.toString(), v.toString()));
      _currencyLabel = _currencyDisplay(code, _currencyOptions[code] ?? '');
    });
  }

  void _openCurrencyPicker() {
    if (!StoreApi.hasStore) {
      _toast('فروشگاهی متصل نیست.', kind: 'info');
      return;
    }
    if (_currencyOptions.isEmpty) {
      _toast('واحدهای پول هنوز بارگذاری نشده‌اند.', kind: 'info');
      _loadCurrency();
      return;
    }
    // Curated shortlist (Iranian + a few majors), filtered down to what this
    // WooCommerce install actually supports, current code pinned first.
    const List<String> pref = ['IRT', 'IRR', 'USD', 'EUR', 'AED', 'TRY', 'IQD'];
    final List<String> codes = <String>[
      if (_currencyCode.isNotEmpty &&
          _currencyOptions.containsKey(_currencyCode))
        _currencyCode,
      ...pref.where(
          (c) => c != _currencyCode && _currencyOptions.containsKey(c)),
    ];
    showWcpSheet<void>(
      context,
      title: 'واحد پول فروشگاه',
      child: _CurrencyPickerSheet(
        codes: codes,
        current: _currencyCode,
        options: _currencyOptions,
        onPick: _applyCurrency,
      ),
    );
  }

  // Writes the chosen currency back to WooCommerce (whole-site change), keeps
  // the demo reversible by reading the prior value first via the picker.
  Future<void> _applyCurrency(String code) async {
    final NavigatorState nav = Navigator.of(context);
    if (code == _currencyCode) {
      nav.pop();
      return;
    }
    setState(() => _currencyBusy = true);
    final StoreResult r = await StoreApi.setWcCurrency(code);
    if (!mounted) return;
    nav.pop();
    if (r.ok) {
      setState(() {
        _currencyCode = code;
        _currencyLabel = _currencyDisplay(code, _currencyOptions[code] ?? '');
        _currencyBusy = false;
      });
      _toast('واحد پول فروشگاه به «$_currencyLabel» تغییر کرد.',
          kind: 'success');
    } else {
      setState(() => _currencyBusy = false);
      _toast(r.error ?? 'تغییر واحد پول ناموفق بود.', kind: 'error');
    }
  }

  // Chat-notification tone (ITEM 6). Opens a picker sheet (same pattern as the
  // currency picker) and persists the chosen key to shared_prefs under
  // 'chat_notif_sound'. NO native NotificationChannel / sound is built here —
  // this is purely the setting; transport lands in a later FCM phase.
  // Opens the SYSTEM ringtone picker (Default + Silent + all installed tones).
  // Native persists the URI + rebuilds the channel; we cache the label to show.
  Future<void> _pickChatSound() async {
    final Map<String, String>? r = await Native.pickNotificationSound();
    if (!mounted || r == null) return; // cancelled
    final String name =
        (r['name'] ?? '').isNotEmpty ? r['name']! : _chatSoundDefaultLabel;
    setState(() => _chatSound = name);
    _saveString('chat_sound_label', name);
    _toast('صدای گفتگو روی «$name» تنظیم شد.', kind: 'success');
  }

  // Biometric toggle — turning it ON actually runs a native BiometricPrompt
  // first, so the switch only sticks if the user really has (and passes)
  // fingerprint/face/PIN. Turning OFF is unconditional.
  Future<void> _toggleBiometric(bool v) async {
    if (!v) {
      setState(() => _biometric = false);
      _save('set_biometric', false);
      return;
    }
    final bool available = await Native.biometricAvailable();
    if (!mounted) return;
    if (!available) {
      _toast('این دستگاه قفل بایومتریک/رمز ندارد یا تنظیم نشده است.',
          kind: 'info', icon: 'faceid');
      return;
    }
    final bool ok = await Native.biometricAuthenticate(
        reason: 'برای فعال‌سازی ورود بایومتریک احراز هویت کنید');
    if (!mounted) return;
    if (ok) {
      setState(() => _biometric = true);
      _save('set_biometric', true);
      _toast('ورود بایومتریک فعال شد.', kind: 'success');
    } else {
      _toast('احراز هویت ناموفق بود.', kind: 'error', icon: 'alert');
    }
  }

  // Notification + security toggles persist locally so the merchant's choice
  // sticks across launches (previously they reset every time).
  Future<void> _loadPrefs() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _push = p.getBool('set_push') ?? true;
        _email = p.getBool('set_email') ?? true;
        _sms = p.getBool('set_sms') ?? false;
        _biometric = p.getBool('set_biometric') ?? true;
        _sound = p.getBool('set_sound') ?? true;
        _shakeReport = p.getBool('shake_report_enabled') ?? true;
        _chatSound = p.getString('chat_sound_label') ?? _chatSoundDefaultLabel;
      });
    } catch (_) {}
  }

  // «گزارش خطا با تکان دادن» — start/stop the accelerometer listener live.
  Future<void> _toggleShakeReport(bool v) async {
    setState(() => _shakeReport = v);
    await setShakeReportEnabled(v);
    _toast(
      v ? 'گزارش با تکان دادن فعال شد.' : 'گزارش با تکان دادن خاموش شد.',
      kind: v ? 'success' : 'info',
    );
  }

  // SMS notifications cost money + depend on a configured SMS gateway — confirm
  // with a clear warning before enabling (covers the Digits-instead-of-our-login
  // case the owner asked about).
  Future<void> _toggleSms(bool v) async {
    if (!v) {
      setState(() => _sms = false);
      _save('set_sms', false);
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('فعال‌سازی اعلان پیامکی',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: const Text(
            'اعلان‌های پیامکی از سامانه پیامکی فروشگاه و شماره موبایل پروفایل ارسال می‌شود و '
            'هزینه هر پیامک از اعتبار سامانه شما کسر می‌گردد.\n\n'
            'برای کارکرد باید درگاه پیامک در ووکامرس پلاس تنظیم باشد. اگر ماژول ورود/ثبت‌نام ما را '
            'فعال نکرده‌اید و از Digits استفاده می‌کنید، پیامک‌ها از همان درگاه پیامک Digits می‌رود — '
            'پس درگاه پیامک را در تنظیمات Digits یا ووکامرس پلاس فعال نگه دارید.',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('انصراف')),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('متوجه شدم، فعال کن')),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() => _sms = true);
      _save('set_sms', true);
      _toast('اعلان پیامکی فعال شد.', kind: 'success');
    }
  }

  Future<void> _save(String key, bool val) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setBool(key, val);
    } catch (_) {}
  }

  Future<void> _saveString(String key, String val) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setString(key, val);
    } catch (_) {}
  }

  void _toast(String msg, {String kind = 'info', String? icon}) =>
      AppScope.of(context).showToast(msg, kind: kind, icon: icon);

  Future<void> _copy(String label, String value) async {
    if (value.isEmpty || value == '—') return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _toast('$label در حافظه کپی شد', kind: 'success');
  }

  Future<void> _changePassword() async {
    final String? base = StoreApi.siteUrl;
    if (base == null || base.isEmpty) {
      _toast('فروشگاهی متصل نیست.', kind: 'info', icon: 'lock');
      return;
    }
    await launchUrl(Uri.parse('$base/my-account/lost-password/'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WcpAppBar(
          title: 'تنظیمات',
          onBack: () => AppScope.of(context).pop(),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
            children: [
              _SettingsGroup(
                title: 'اطلاعات فروشگاه',
                children: [
                  ListRow(
                    icon: 'store',
                    iconColor: context.c.accent,
                    title: 'نام فروشگاه',
                    sub: StoreApi.storeName ?? StoreApi.siteHost ?? 'فروشگاه شما',
                    chevron: true,
                    onClick: () =>
                        _copy('نام فروشگاه', StoreApi.storeName ?? StoreApi.siteHost ?? 'فروشگاه شما'),
                  ),
                  const _Sep(),
                  ListRow(
                    icon: 'globe',
                    iconColor: context.c.info,
                    title: 'آدرس دامنه',
                    sub: StoreApi.siteHost ?? sampleStore.domain,
                    chevron: true,
                    onClick: () =>
                        _copy('آدرس دامنه', StoreApi.siteHost ?? sampleStore.domain),
                  ),
                  const _Sep(),
                  ListRow(
                    icon: 'coin',
                    iconColor: context.c.success,
                    title: 'واحد پول',
                    // Mirrors WooCommerce; tapping opens a picker that writes
                    // the change back to the store.
                    sub: _currencyBusy ? 'در حال ذخیره…' : _currencyLabel,
                    chevron: true,
                    onClick: _openCurrencyPicker,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsGroup(
                title: 'اعلان‌ها',
                children: [
                  _ToggleRow(
                    icon: 'bell',
                    color: context.c.accent,
                    label: 'اعلان پوش',
                    sub: 'سفارش، موجودی، پرداخت',
                    on: _push,
                    onChange: (v) {
                      setState(() => _push = v);
                      _save('set_push', v);
                    },
                  ),
                  const _Sep(),
                  _ToggleRow(
                    icon: 'inbox',
                    color: context.c.info,
                    label: 'اعلان ایمیل',
                    sub: 'گزارش‌های روزانه',
                    on: _email,
                    onChange: (v) {
                      setState(() => _email = v);
                      _save('set_email', v);
                    },
                  ),
                  const _Sep(),
                  _ToggleRow(
                    icon: 'message',
                    color: context.c.success,
                    label: 'پیامک',
                    sub: 'هشدارهای مهم · شامل هزینه',
                    on: _sms,
                    onChange: _toggleSms,
                  ),
                  const _Sep(),
                  _ToggleRow(
                    icon: 'bolt',
                    color: context.c.warning,
                    label: 'صدا و لرزش',
                    sub: 'هنگام دریافت اعلان',
                    on: _sound,
                    onChange: (v) {
                      setState(() => _sound = v);
                      _save('set_sound', v);
                    },
                  ),
                  const _Sep(),
                  // ITEM 6 — chat-notification tone. Picker-driven; current
                  // choice shown as the subtitle. Setting only (no transport).
                  ListRow(
                    icon: 'message',
                    iconColor: context.c.accent,
                    title: 'صدای گفتگو',
                    sub: _chatSound,
                    chevron: true,
                    onClick: _pickChatSound,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsGroup(
                title: 'امنیت',
                children: [
                  _ToggleRow(
                    icon: 'faceid',
                    color: context.c.accent,
                    label: 'ورود بایومتریک',
                    sub: 'اثر انگشت / چهره',
                    on: _biometric,
                    onChange: _toggleBiometric,
                  ),
                  const _Sep(),
                  ListRow(
                    icon: 'lock',
                    iconColor: context.c.error,
                    title: 'تغییر رمز عبور',
                    sub: 'بازیابی در سایت فروشگاه',
                    chevron: true,
                    onClick: _changePassword,
                  ),
                  const _Sep(),
                  ListRow(
                    icon: 'devices',
                    iconColor: context.c.info,
                    title: 'دستگاه‌های فعال',
                    sub: _DevicesSheet.shortLabel(),
                    chevron: true,
                    onClick: () => showWcpSheet<void>(
                      context,
                      title: 'دستگاه‌های فعال',
                      child: const _DevicesSheet(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsGroup(
                title: 'نمایش',
                children: [
                  Builder(builder: (context) {
                    final ThemeMode tm = AppScope.of(context).themeMode;
                    Widget chip(String label, ThemeMode mode) {
                      final bool sel = tm == mode;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              AppScope.of(context).setThemeMode(mode),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sel ? context.c.accentSoft : context.c.bg1,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel ? context.c.accent : context.c.line,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color:
                                    sel ? context.c.accentText : context.c.tx2,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(right: 2, bottom: 10),
                            child: Text(
                              'پوسته',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.c.tx1,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              chip('روشن', ThemeMode.light),
                              chip('تیره', ThemeMode.dark),
                              chip('سیستمی', ThemeMode.system),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const _Sep(),
                  ListRow(
                    icon: 'layers',
                    iconColor: context.c.info,
                    title: 'زبان',
                    sub: 'فارسی',
                    chevron: true,
                    onClick: () =>
                        _toast('این نسخه به‌صورت کامل فارسی ارائه می‌شود.',
                            kind: 'info'),
                  ),
                  const _Sep(),
                  _ToggleRow(
                    icon: 'alert',
                    color: context.c.accent,
                    label: 'گزارش خطا با تکان دادن',
                    sub: 'گوشی را تکان دهید تا تصویر صفحه + توضیح ارسال شود',
                    on: _shakeReport,
                    onChange: _toggleShakeReport,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Settings group: caption + pad-0 card ─────────────────────────
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 9),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: c.tx3,
            ),
          ),
        ),
        WcpCard(
          pad: 0,
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ── Toggle row (bespoke — 38×38 r11 icon box + sm switch) ────────
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.label,
    this.sub,
    required this.on,
    required this.onChange,
  });

  final String icon;
  final Color color;
  final String label;
  final String? sub;
  final bool on;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withAlpha(0x22), // c + '22'
              borderRadius: BorderRadius.circular(11),
            ),
            child: WcpIcon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null && sub!.isNotEmpty)
                  Text(
                    sub!,
                    style: TextStyle(fontSize: 11.5, color: c.tx3),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          WcpSwitch(on: on, onChange: onChange, size: 'sm'),
        ],
      ),
    );
  }
}

// ── 1px row separator (margin 0 14) ──────────────────────────────
class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(height: 1, color: context.c.line),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Devices sheet — REAL info about THIS device.
//
// The app doesn't carry a "session list" backend (one ck/cs pair, no
// per-device tokens), so the only honest device fact is the current
// one. We show its OS + version + app build, with the option to log
// out (the only available revocation on this side).
// ════════════════════════════════════════════════════════════════
class _DevicesSheet extends StatelessWidget {
  const _DevicesSheet();

  /// One-line summary shown under the «دستگاه‌های فعال» row.
  static String shortLabel() {
    if (Platform.isAndroid) return 'این دستگاه (اندروید)';
    if (Platform.isIOS) return 'این دستگاه (iOS)';
    return 'این دستگاه';
  }

  String get _osLabel {
    if (Platform.isAndroid) return 'اندروید';
    if (Platform.isIOS) return 'iOS';
    return Platform.operatingSystem;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final String osVer = Platform.operatingSystemVersion;
    final String locale = Platform.localeName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WcpCard(
          pad: 0,
          child: Column(
            children: [
              ListRow(
                icon: 'devices',
                iconColor: c.info,
                title: 'این دستگاه',
                sub: _osLabel,
              ),
              const _Sep(),
              ListRow(
                icon: 'layers',
                iconColor: c.accent,
                title: 'نسخه سیستم‌عامل',
                sub: osVer,
              ),
              const _Sep(),
              ListRow(
                icon: 'globe',
                iconColor: c.warning,
                title: 'منطقه',
                sub: locale,
              ),
              const _Sep(),
              ListRow(
                icon: 'sparkles',
                iconColor: c.success,
                title: 'نسخه اپ',
                sub: _versionLabel(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'این اپ یک نشست واحد به این دستگاه می‌دهد؛ برای ابطال، از «خروج از حساب» در پایین صفحه بیشتر استفاده کنید.',
          style: TextStyle(
              fontFamily: T.family, fontSize: 12, color: c.tx3, height: 1.7),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Currency picker — writes the chosen code straight to WooCommerce.
// ════════════════════════════════════════════════════════════════
class _CurrencyPickerSheet extends StatelessWidget {
  const _CurrencyPickerSheet({
    required this.codes,
    required this.current,
    required this.options,
    required this.onPick,
  });

  final List<String> codes;
  final String current;
  final Map<String, String> options;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WcpCard(
          pad: 0,
          child: Column(
            children: [
              for (int i = 0; i < codes.length; i++) ...[
                if (i > 0) Divider(height: 1, color: c.line),
                _CurrencyRow(
                  code: codes[i],
                  label: _currencyDisplay(codes[i], options[codes[i]] ?? ''),
                  selected: codes[i] == current,
                  onTap: () => onPick(codes[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'این تنظیم مستقیما روی ووکامرس فروشگاه اعمال می‌شود و واحد پول کل سایت را تغییر می‌دهد.',
          style: TextStyle(
              fontFamily: T.family, fontSize: 12, color: c.tx3, height: 1.7),
        ),
      ],
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    code,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11.5, color: c.tx3),
                  ),
                ],
              ),
            ),
            if (selected) WcpIcon('check', size: 20, color: c.accent),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Registration
// ════════════════════════════════════════════════════════════════
void registerMoreScreen() {
  kScreens['more'] = (ctx, p) => const MoreScreen();
  kScreens['settings'] = (ctx, p) => const SettingsScreen();
}
