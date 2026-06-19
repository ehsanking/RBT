// ════════════════════════════════════════════════════════════════
// shell.dart — app shell: shared nav state, 5 per-tab Navigators,
// bottom tab bar (raised center «ماژول‌ها» hub + live-chat FAB pill),
// offline banner + toast host. Ported from shell.jsx.
//
// The prototype's DeviceFrame / ControlDock / platform switcher / "both"
// view were studio chrome — intentionally NOT ported. This is the real app.
//
// SCREEN ROUTING
// --------------
// Routes resolve through `kScreens` (see lib/screens/registry.dart). The shell
// calls `registerAllScreens()` once in `initState`, then each tab owns its own
// `Navigator` inside an `IndexedStack` so tab state is preserved when switching.
// Pushing (`AppScope.of(context).push(name, params)`) pushes onto the CURRENTLY
// ACTIVE tab's navigator. Unknown routes render a "صفحه در دست ساخت" placeholder.
//
// NAV API — `AppScope.of(context)` exposes:
//   push(String screen, [Map<String,dynamic>? params]) / pop()
//   goTab(String id) / showToast(String msg, {kind, icon})
//   toggleTheme() + themeMode  + navigate (GlobalKey<NavigatorState> of active tab)
// ════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../core/icons.dart';
import '../core/fmt.dart';
import '../core/native.dart';
import '../widgets/ui.dart';
import '../screens/registry.dart';
import '../services/store_api.dart';

// ── Tabs (from shell.jsx TABS) ──────────────────────────────────
class _Tab {
  final String id;
  final String icon;
  final String label;
  const _Tab(this.id, this.icon, this.label);
}

const List<_Tab> _kTabs = <_Tab>[
  _Tab('home', 'home', 'خانه'),
  _Tab('orders', 'orders', 'سفارش‌ها'),
  _Tab('modules', 'modules', 'ماژول‌ها'),
  _Tab('products', 'products', 'محصولات'),
  _Tab('more', 'more', 'بیشتر'),
];

const List<String> kTabIds = ['home', 'orders', 'modules', 'products', 'more'];

/// Height the bottom tab bar reserves above the OS safe-area inset.
///
/// Mirrors the JSX shell, whose scroll area pads `calc(var(--sa-bottom) + 66px)`
/// so the last items never hide UNDER the bar. 66 is the tab-bar body height;
/// the raised hub / live-chat pill overhang upward INTO the scroll area, but the
/// bar's opaque blocker is only ~66px tall, so 66 is exactly what content must
/// clear. We inject this into the tab subtree's MediaQuery bottom insets (see
/// [_AppShellState.build]) so every tab-rooted screen — whether it reads
/// `padding.bottom`, wraps in `SafeArea`, or adds its own spacer — reserves it
/// uniformly, with no per-screen edits.
const double kTabBarReserve = 66;

// ════════════════════════════════════════════════════════════════
// AppScope — InheritedWidget giving any descendant the nav + app actions.
// ════════════════════════════════════════════════════════════════
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.push,
    required this.pop,
    required this.goTab,
    required this.showToast,
    required this.toggleTheme,
    required this.setThemeMode,
    required this.themeMode,
    required this.activeTab,
    required this.navigate,
    required this.logout,
    required this.hideFab,
    required this.showFab,
    required super.child,
  });

  /// Push a named screen onto the active tab's navigator. Returns a Future
  /// that completes when the pushed screen is popped (so callers can refresh
  /// on return). Ignoring the Future is fine.
  final Future<void> Function(String screen, [Map<String, dynamic>? params])
      push;

  /// Pop the active tab's navigator (no-op at a tab root).
  final VoidCallback pop;

  /// Switch tabs (resets that tab to its root and reveals it).
  final void Function(String id) goTab;

  /// Show a transient toast. kind ∈ success|error|info|warning.
  final void Function(String msg, {String kind, String? icon}) showToast;

  /// Flip dark ⇄ light (MaterialApp owns the actual ThemeMode upstream).
  final VoidCallback toggleTheme;

  /// Set a specific theme mode (light/dark/system) — settings selector.
  final void Function(ThemeMode) setThemeMode;

  /// Current effective theme mode (light/dark — never `system` here).
  final ThemeMode themeMode;

  /// Currently selected tab id.
  final String activeTab;

  /// The active tab's navigator key — escape hatch for advanced flows.
  final GlobalKey<NavigatorState> navigate;

  /// Real sign-out: clears the stored store credentials and returns to the
  /// connect screen. (The «خروج از حساب» sheet used to only show a toast.)
  final VoidCallback logout;

  /// Hide the floating live-chat pill (ref-counted). Screens that own a
  /// bottom composer/input bar (e.g. the ticket conversation) call this on
  /// entry so the FAB doesn't overlap their controls, and [showFab] on exit.
  final VoidCallback hideFab;

  /// Restore the live-chat pill (pairs with [hideFab]).
  final VoidCallback showFab;

  static AppScope of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope.of() called with no AppScope ancestor');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope old) =>
      themeMode != old.themeMode || activeTab != old.activeTab;
}

// ════════════════════════════════════════════════════════════════
// AppShell — root of the in-app experience.
// ════════════════════════════════════════════════════════════════
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onSetThemeMode,
    required this.onLogout,
  });

  /// Effective theme mode, owned by `WcpApp` (so MaterialApp can react).
  final ThemeMode themeMode;

  /// Ask `WcpApp` to flip the theme (light⇄dark, top-bar quick toggle).
  final VoidCallback onToggleTheme;

  /// Ask `WcpApp` to set a specific theme mode (light/dark/system selector).
  final void Function(ThemeMode) onSetThemeMode;

  /// Sign out: clear stored credentials and return to the connect flow.
  /// Wired up the launch-flow's `setPhase('connect')` after `disconnect()`.
  final VoidCallback onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final bool _offline = false;
  // True while the «خروج از برنامه؟» confirm dialog is open, so a second BACK
  // does not stack another copy.
  bool _exitDialogOpen = false;

  // One Navigator per tab; keys let us push/pop into the active tab.
  late final List<GlobalKey<NavigatorState>> _navKeys = List.generate(
    kTabIds.length,
    (i) => GlobalKey<NavigatorState>(debugLabel: 'tab_${kTabIds[i]}'),
  );

  // Toast state.
  _ToastData? _toast;
  int _toastSeq = 0;

  // Ref-count of screens asking the chat FAB pill to stay hidden (e.g.
  // composer screens whose bottom bar it would overlap). >0 → hidden.
  final ValueNotifier<int> _fabHide = ValueNotifier<int>(0);
  void _hideFab() => _fabHide.value++;
  void _showFab() {
    if (_fabHide.value > 0) _fabHide.value--;
  }

  // ── Live-chat unread badge over the FAB ───────────────────────
  // Polled every ~12s while a store is connected (mirrors ChatInboxScreen's
  // openUnread = Σ staff_unread). Re-polled when returning from chatInbox.
  int _chatUnread = 0;
  Timer? _chatPoll;

  Future<void> _refreshChatUnread() async {
    if (!StoreApi.hasStore) return;
    final StoreResult r = await StoreApi.chatConversations(status: 'all');
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) return;
    final int unread =
        r.list.fold(0, (a, e) => a + ((e['staff_unread'] ?? 0) as num).toInt());
    if (unread != _chatUnread) setState(() => _chatUnread = unread);
  }

  String get _activeTabId => kTabIds[_index];
  GlobalKey<NavigatorState> get _activeNav => _navKeys[_index];

  @override
  void initState() {
    super.initState();
    // Populate the route registry before any tab navigator builds.
    registerAllScreens();
    // Poll the live-chat unread count for the FAB badge while connected.
    if (StoreApi.hasStore) {
      _refreshChatUnread();
      _chatPoll = Timer.periodic(
        const Duration(seconds: 12),
        (_) {
          if (StoreApi.hasStore) _refreshChatUnread();
        },
      );
    }
    // One-shot: ask Cafe Bazaar whether a newer version is published, prompt if so.
    _maybeCheckUpdate();
  }

  /// Non-blocking, once per launch: if Bazaar reports a newer published version,
  /// show a gentle prompt to update (deep-links into Bazaar). Silent otherwise
  /// (already up-to-date, or not running inside Bazaar → state 'error').
  Future<void> _maybeCheckUpdate() async {
    final Map<String, dynamic> r = await Native.checkBazaarUpdate();
    if (!mounted || r['state'] != 'need') return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('نسخه‌ی جدید موجود است'),
          content: const Text(
            'نسخه‌ی تازه‌ای از اپ در کافه‌بازار منتشر شده. برای دریافت آخرین قابلیت‌ها '
            'و رفع اشکال‌ها، به‌روزرسانی کنید.',
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('بعدا'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Native.startBazaarUpdate();
              },
              child: const Text('به‌روزرسانی'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _chatPoll?.cancel();
    _fabHide.dispose();
    super.dispose();
  }

  // ── Nav actions exposed via AppScope ──────────────────────────
  Future<void> _push(String screen, [Map<String, dynamic>? params]) {
    final Future<dynamic>? f = _activeNav.currentState?.push(
      _buildRoute(screen, params ?? const <String, dynamic>{}),
    );
    return f == null ? Future<void>.value() : f.then((_) {});
  }

  void _pop() {
    final NavigatorState? nav = _activeNav.currentState;
    if (nav != null && nav.canPop()) nav.pop();
  }

  /// Hardware/gesture BACK handler (wired via PopScope on the shell). Previously
  /// the system back went to the ROOT navigator — which holds only the shell —
  /// so it could not pop and EXITED the app from every screen. Now: pop the
  /// active tab's own navigator (sub-screen or bottom-sheet) → else jump to the
  /// home tab → else, only at the home root, ask «خروج از برنامه؟ بله/خیر».
  void _onBack() {
    final NavigatorState? nav = _activeNav.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }
    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }
    _confirmExit();
  }

  /// At the home root, BACK asks for explicit confirmation before leaving the
  /// app (Yes/No), instead of silently exiting on a double-tap.
  Future<void> _confirmExit() async {
    if (_exitDialogOpen) return; // guard against a second BACK opening a stack
    _exitDialogOpen = true;
    final bool? yes = await showWcpDialog<bool>(
      context,
      icon: 'logout',
      title: 'خروج از برنامه',
      message: 'می‌خواهید از برنامه خارج شوید؟',
      actions: [
        WcpButton(
            variant: 'secondary',
            label: 'خیر',
            onClick: () => Navigator.of(context).pop(false)),
        WcpButton(
            variant: 'primary',
            label: 'بله',
            onClick: () => Navigator.of(context).pop(true)),
      ],
    );
    _exitDialogOpen = false;
    if (yes == true) SystemNavigator.pop(); // exit the app
  }

  void _goTab(String id) {
    final int next = kTabIds.indexOf(id);
    if (next < 0) return;
    if (next == _index) {
      // Re-tapping the active tab pops it back to its root.
      _navKeys[next].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _index = next);
    }
  }

  void _toggleTheme() => widget.onToggleTheme();

  // ── Toast ─────────────────────────────────────────────────────
  void _showToast(String msg, {String kind = 'success', String? icon}) {
    final int seq = ++_toastSeq;
    setState(() => _toast = _ToastData(msg: msg, kind: kind, icon: icon));
    // Auto-dismiss after 2.4s (matches shell.jsx), unless superseded.
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      if (seq == _toastSeq) setState(() => _toast = null);
    });
  }

  // ── Route building (registry lookup + placeholder fallback) ────
  Route<dynamic> _buildRoute(String screen, Map<String, dynamic> params) {
    return PageRouteBuilder<dynamic>(
      settings: RouteSettings(name: screen, arguments: params),
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => _resolve(ctx, screen, params),
      transitionsBuilder: (ctx, anim, _, child) {
        // fadeIn .28s ease (shell.jsx AppContent animation).
        final Animation<double> fade = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOut,
        );
        return FadeTransition(opacity: fade, child: child);
      },
    );
  }

  Widget _resolve(
      BuildContext context, String screen, Map<String, dynamic> params) {
    final builder = kScreens[screen];
    if (builder != null) return builder(context, params);
    return _UnderConstruction(name: screen);
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AppScope(
      push: _push,
      pop: _pop,
      goTab: _goTab,
      showToast: _showToast,
      toggleTheme: _toggleTheme,
      setThemeMode: widget.onSetThemeMode,
      themeMode: widget.themeMode,
      activeTab: _activeTabId,
      navigate: _activeNav,
      logout: widget.onLogout,
      hideFab: _hideFab,
      showFab: _showFab,
      child: PopScope(
        // We own ALL back handling (canPop:false → never auto-pop/exit). Routes
        // ABOVE the shell on the ROOT navigator (dialogs/full-screen pages) still
        // pop normally — this only fires when the shell itself would be popped.
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          _onBack();
        },
        child: Scaffold(
          backgroundColor: context.c.bg0,
        // Keep our own bottom bar laid out manually (raised hub overflows).
        body: Stack(
          children: [
            // The 5 tab navigators; only the active one is interactive.
            //
            // BUG-FIX (content hidden under the tab bar): the bottom bar floats
            // ON TOP of this stack, so without reserving space the last items of
            // every screen's scroll view sit UNDER it. Rather than patching each
            // screen, we widen the bottom inset for the whole tab subtree: add
            // `kTabBarReserve` to BOTH `viewPadding.bottom` (raw safe-area, what
            // most screens read) and `padding.bottom`. Screens then pad/`SafeArea`
            // exactly enough to clear the bar — matching the JSX shell, which
            // reserves `calc(var(--sa-bottom) + 66px)` on its scroll area.
            Positioned.fill(
              child: Builder(
                builder: (innerCtx) {
                  final MediaQueryData mq = MediaQuery.of(innerCtx);
                  final EdgeInsets vp = mq.viewPadding;
                  final EdgeInsets pad = mq.padding;
                  // UNIVERSAL bottom reserve (every page, current & future):
                  // physically inset the ENTIRE tab subtree by
                  // (safe-area + kTabBarReserve) so NO screen — even one whose
                  // scroll root uses EdgeInsets.zero — can draw under the
                  // floating tab bar. We ALSO zero the injected bottom
                  // padding/viewPadding so screens that DO read padding.bottom
                  // don't double-count: net layout is byte-identical to the old
                  // per-screen reserve, but now it's guaranteed globally.
                  final double reserve = pad.bottom + kTabBarReserve;
                  return MediaQuery(
                    data: mq.copyWith(
                      viewPadding: vp.copyWith(bottom: 0),
                      padding: pad.copyWith(bottom: 0),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: reserve),
                      child: IndexedStack(
                        index: _index,
                        children: [
                          for (int i = 0; i < kTabIds.length; i++)
                            _TabNavigator(
                              navKey: _navKeys[i],
                              rootScreen: kTabIds[i],
                              resolve: _resolve,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Offline banner (top, under the status bar).
            if (_offline)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 12,
                right: 12,
                child: const _OfflineBanner(),
              ),

            // Toast host (above the tab bar).
            if (_toast != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 86,
                child: _ToastHost(toast: _toast!),
              ),

            // Bottom tab bar with the raised center hub.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _TabBar(
                activeTab: _activeTabId,
                onTab: _goTab,
              ),
            ),

            // Live-chat pill — hoisted OUT of the tab bar into this full-screen
            // Stack so it is actually tappable (overflowing the bar's own box
            // made it un-hittable). Sits just above the bar on the visual
            // right; `bottom` mirrors the old `top:-52` overhang. Opens the
            // chat inbox and carries an unread badge (Σ staff_unread).
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 62,
              child: ValueListenableBuilder<int>(
                valueListenable: _fabHide,
                builder: (_, hidden, __) => hidden > 0
                    ? const SizedBox.shrink()
                    : _ChatPill(
                        unread: _chatUnread,
                        onTap: () async {
                          await _push('chatInbox');
                          // Re-poll on return so reading the inbox clears the badge.
                          _refreshChatUnread();
                        },
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
// Per-tab Navigator. Its root is the tab id route; pushes stack on top.
// ════════════════════════════════════════════════════════════════
class _TabNavigator extends StatelessWidget {
  const _TabNavigator({
    required this.navKey,
    required this.rootScreen,
    required this.resolve,
  });

  final GlobalKey<NavigatorState> navKey;
  final String rootScreen;
  final Widget Function(BuildContext, String, Map<String, dynamic>) resolve;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      onGenerateInitialRoutes: (state, initialRoute) => [
        MaterialPageRoute<dynamic>(
          settings: RouteSettings(name: rootScreen),
          builder: (ctx) => resolve(ctx, rootScreen, const {}),
        ),
      ],
      onGenerateRoute: (settings) {
        final Map<String, dynamic> params =
            settings.arguments is Map<String, dynamic>
                ? settings.arguments as Map<String, dynamic>
                : const <String, dynamic>{};
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (ctx) => resolve(ctx, settings.name ?? rootScreen, params),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Bottom tab bar (pixel-perfect from shell.jsx TabBar).
//  • bar: bg1, 1px top line, top shadow
//  • 5 slots, center slot is a 56px-wide spacer for the raised hub
//  • raised hub: 58×58 r20, 3px bg1 border, accent→accentPress gradient,
//                shadowAccent, icon 'modules' size 26
//  • live-chat pill: 50×50 r16, top-left (RTL: visual right), bg1, line border,
//                    shadowMd, message icon size 24 sw 2.2 + unread badge
//  • labels: 10.5px, weight 800 active / 600 idle
// ════════════════════════════════════════════════════════════════
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.activeTab,
    required this.onTab,
  });

  final String activeTab;
  final void Function(String id) onTab;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.c;
    final double saBottom = MediaQuery.of(context).padding.bottom;
    final bool modulesActive = activeTab == 'modules';

    return SizedBox(
      // Let the raised hub (top: -24) and pill (top: -64) overflow upward.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The bar itself.
          Container(
            decoration: BoxDecoration(
              color: c.bg1,
              border: Border(top: BorderSide(color: c.line, width: 1)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000), // rgba(0,0,0,.12)
                  blurRadius: 30,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            padding: EdgeInsets.only(bottom: saBottom),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < _kTabs.length; i++)
                    if (i == 2)
                      const SizedBox(width: 56) // center spacer for the hub
                    else
                      Expanded(
                        child: _TabItem(
                          tab: _kTabs[i],
                          active: activeTab == _kTabs[i].id,
                          onTap: () => onTab(_kTabs[i].id),
                        ),
                      ),
                ],
              ),
            ),
          ),

          // «ماژول‌ها» label under the center hub.
          Positioned(
            bottom: saBottom + 5,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  'ماژول‌ها',
                  style: TextStyle(
                    fontFamily: T.family,
                    fontSize: 10.5,
                    fontWeight:
                        modulesActive ? FontWeight.w800 : FontWeight.w600,
                    color: modulesActive ? c.accentText : c.tx3,
                  ),
                ),
              ),
            ),
          ),

          // Raised center hub → modules.
          Positioned(
            top: -24,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTab('modules'),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.accent, c.accentPress],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.bg1, width: 3),
                    boxShadow: c.shadowAccent,
                  ),
                  child: Center(
                    child: WcpIcon(
                      'modules',
                      size: 26,
                      sw: 2,
                      fill: modulesActive,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // NOTE: the live-chat pill is NOT here anymore. When it lived in
          // this Stack at top:-52 it overflowed ABOVE the bar's box, so Flutter
          // routed taps there to the page content behind it (the pill looked
          // tappable but did nothing). It's now hoisted into the shell's
          // full-screen Stack (see `_ChatPill` in _ShellState.build), where
          // it is actually hit-testable.
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Live-chat pill — neumorphic, hoisted to the shell's full-screen Stack so
// it's genuinely tappable (a child overflowing the tab bar's own box is
// painted but NOT hit-tested). Embossed (dark drop + faint top-left light) so
// it reads as raised chrome rather than a solid slab over the content.
// Carries an unread badge (Σ staff_unread) reusing the IconBtn error-pill
// geometry; the badge is hidden when [unread] is 0.
// ════════════════════════════════════════════════════════════════
class _ChatPill extends StatelessWidget {
  const _ChatPill({required this.onTap, required this.unread});
  final VoidCallback onTap;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.c;
    final Widget pill = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: c.bg1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line, width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withAlpha(0x59),
              blurRadius: 12,
              offset: const Offset(5, 5),
            ),
            BoxShadow(
              color: const Color(0xFFFFFFFF).withAlpha(0x12),
              blurRadius: 10,
              offset: const Offset(-4, -4),
            ),
          ],
        ),
        child: Center(
          child: WcpIcon('chatDots', size: 24, sw: 2.2, color: c.accentText),
        ),
      ),
    );

    if (unread <= 0) return pill;

    // Unread badge — same geometry as IconBtn's error pill (minW16, h16,
    // pad 0/4, r8, error bg, #fff fs10 w700, 2px bg0 border).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        pill,
        Positioned(
          top: -4,
          left: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16),
            height: 16,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.error,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.bg0, width: 2),
            ),
            child: Text(
              Fmt.fa(unread),
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.c;
    final Color tint = active ? c.accentText : c.tx3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: active ? 1 : 0.95,
              child: WcpIcon(
                tab.icon,
                size: 24,
                sw: active ? 2 : 1.7,
                fill: active,
                color: tint,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: TextStyle(
                fontFamily: T.family,
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Toast host (from shell.jsx ToastHost).
// ════════════════════════════════════════════════════════════════
class _ToastData {
  final String msg;
  final String kind;
  final String? icon;
  const _ToastData({required this.msg, required this.kind, this.icon});
}

class _ToastHost extends StatelessWidget {
  const _ToastHost({required this.toast});

  final _ToastData toast;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.c;
    // colors map: success/error/warning semantic; 'info' → accent (per JSX).
    final Color tint =
        toast.kind == 'info' ? c.accent : c.kind(toast.kind);

    // Horizontally centered within the (left:16,right:16) band. We use a Row
    // with loose Flexible rather than Center, because the enclosing Positioned
    // constrains width but NOT height — a Center there would get unbounded
    // height and fail to lay out.
    return IgnorePointer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: _PopIn(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.92,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: c.bg2,
                  border: Border.all(color: c.line, width: 1),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: c.shadowLg,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: tint.withAlpha(0x22), // soft tint (hex '22')
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: WcpIcon(
                          toast.icon ?? 'checkCircle',
                          size: 17,
                          color: tint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        toast.msg,
                        style: TextStyle(
                          fontFamily: T.family,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: c.tx1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Offline banner (from screens-states.jsx OfflineBanner).
// ════════════════════════════════════════════════════════════════
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.c;
    return _PopIn(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.bg2,
          border: Border.all(color: c.warning, width: 1),
          borderRadius: BorderRadius.circular(14),
          boxShadow: c.shadowLg,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: c.warningSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: WcpIcon('globe', size: 17, color: c.warning),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اتصال اینترنت قطع است',
                    style: TextStyle(
                      fontFamily: T.family,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.tx1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'نمایش آخرین داده‌های ذخیره‌شده',
                    style: TextStyle(
                      fontFamily: T.family,
                      fontSize: 11,
                      color: c.tx3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _PingDot(color: c.warning),
          ],
        ),
      ),
    );
  }
}

// Pulsing dot (the JSX `ping` ring). 8px solid core + expanding fading ring.
class _PingDot extends StatefulWidget {
  const _PingDot({required this.color});
  final Color color;

  @override
  State<_PingDot> createState() => _PingDotState();
}

class _PingDotState extends State<_PingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 8,
      height: 8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Expanding ring (inset: -3 → grows to ~14px).
          AnimatedBuilder(
            animation: _ctl,
            builder: (context, _) {
              final double t = _ctl.value;
              final double size = 8 + 6 * t; // 8 → 14
              final int alpha = (0.4 * (1 - t) * 255).round(); // fade out
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withAlpha(alpha),
                ),
              );
            },
          ),
          // Solid core.
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// popIn entrance (scale .9→1 + fade) used by toast + offline banner.
// ════════════════════════════════════════════════════════════════
class _PopIn extends StatefulWidget {
  const _PopIn({required this.child});
  final Widget child;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curved =
        CurvedAnimation(parent: _ctl, curve: Motion.ease);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
        child: widget.child,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Placeholder for unregistered routes ("صفحه در دست ساخت").
// ════════════════════════════════════════════════════════════════
class _UnderConstruction extends StatelessWidget {
  const _UnderConstruction({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.c;
    return Scaffold(
      backgroundColor: c.bg0,
      body: SafeArea(
        child: Stack(
          children: [
            // Lightweight back affordance (RTL: chevron points right).
            Positioned(
              top: 8,
              right: 8,
              child: IconBtn(
                name: 'chevronR',
                onClick: () => AppScope.of(context).pop(),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: c.bg2,
                        borderRadius: BorderRadius.circular(R.xl),
                        border: Border.all(color: c.line, width: 1),
                      ),
                      child: Center(
                        child: WcpIcon('settings', size: 38, color: c.tx3),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'صفحه در دست ساخت',
                      style: TextStyle(
                        fontFamily: T.family,
                        fontSize: T.h3,
                        fontWeight: FontWeight.w800,
                        color: c.tx1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'صفحه «$name» در فاز بعدی ساخته می‌شود',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: T.family,
                        fontSize: T.foot,
                        height: 1.7,
                        color: c.tx3,
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
