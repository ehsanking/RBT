// ════════════════════════════════════════════════════════════════
// support.dart — «پشتیبانی و تعامل» hub + Ticketing
// Ported pixel-perfect from app/screens-support.jsx.
//
// Screens / routes:
//   supportHub   → SupportHubScreen   (Support & Engagement hub)
//   tickets      → TicketsScreen      (Tickets inbox)
//   ticketDetail → TicketDetailScreen (Ticket conversation)
//
// TICKET_STATUS / PRIORITY colours live in data/models.dart as the
// kind→colour contract (ticketStatusInfo / priorityInfo). This file
// resolves a kind to concrete (colour, soft) via context.c, exactly
// like StatusPill does.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../core/icons.dart';
import '../core/fmt.dart';
import '../core/native.dart';
import '../data/models.dart';
import '../data/sample.dart';
import '../data/woo_map.dart';
import '../nav/shell.dart';
import '../services/store_api.dart';
import '../widgets/ui.dart';
import 'registry.dart';

// ════════════════════════════════════════════════════════════════
// kind → (colour, soft) — mirrors StatusPill's resolution.
// ════════════════════════════════════════════════════════════════
({Color color, Color soft}) _kindColors(BuildContext context, String kind) {
  final c = context.c;
  if (kind == 'neutral') return (color: c.tx3, soft: c.bg3);
  return (color: c.kind(kind), soft: c.kindSoft(kind));
}

/// Solid colour only (PRIORITY uses just `c`, no soft).
Color _kindColor(BuildContext context, String kind) {
  final c = context.c;
  if (kind == 'neutral') return c.tx3;
  return c.kind(kind);
}

// ════════════════════════════════════════════════════════════════
// Support & Engagement hub
// ════════════════════════════════════════════════════════════════
class SupportHubScreen extends StatefulWidget {
  const SupportHubScreen({super.key});

  @override
  State<SupportHubScreen> createState() => _SupportHubScreenState();
}

class _SupportHubScreenState extends State<SupportHubScreen> {
  // Live-chat unread count (Σ staff_unread) for the «گفتگوی زنده» tile.
  // Fetched once on open (cheap) while a store is connected.
  int _chatUnread = 0;

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) _loadChatUnread();
  }

  Future<void> _loadChatUnread() async {
    final StoreResult r = await StoreApi.chatConversations(status: 'all');
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) return;
    final int unread =
        r.list.fold(0, (a, e) => a + ((e['staff_unread'] ?? 0) as num).toInt());
    if (unread != _chatUnread) setState(() => _chatUnread = unread);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    final cards = <_HubCard>[
      _HubCard(
        id: 'tickets',
        icon: 'ticketSupport',
        label: 'تیکت‌ها و پشتیبانی',
        sub: 'صندوق پیام‌های مشتریان',
        color: c.accent,
        badge: supportTicketsCount,
        go: 'tickets',
      ),
      _HubCard(
        id: 'chat',
        icon: 'message',
        label: 'گفتگوی زنده',
        sub: 'چت مستقیم با مشتریان',
        color: c.success,
        badge: _chatUnread,
        go: 'chatInbox',
      ),
      _HubCard(
        id: 'comments',
        icon: 'message',
        label: 'نظرات',
        sub: 'تأیید و پاسخ دیدگاه‌ها',
        color: c.info,
        badge: supportCommentsCount,
        go: 'comments',
      ),
      _HubCard(
        id: 'qna',
        icon: 'help',
        label: 'پرسش و پاسخ محصولات',
        sub: 'پاسخ به پرسش‌های خرید',
        color: c.success,
        badge: supportQnaCount,
        go: 'qna',
      ),
      _HubCard(
        id: 'users',
        icon: 'users',
        label: 'مدیریت کاربران',
        sub: 'همهٔ کاربران و نقش‌ها',
        color: c.warning,
        badge: 0,
        go: 'users',
      ),
      _HubCard(
        id: 'block',
        icon: 'shield',
        label: 'بلاک و مسدودسازی',
        sub: 'کاربران مسدودشده',
        color: c.error,
        badge: 0,
        go: 'blocklist',
      ),
    ];

    final pendingTotal =
        supportTicketsCount + supportCommentsCount + supportQnaCount;

    return Container(
      color: c.bg0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'پشتیبانی و تعامل',
            sub: '${Fmt.fa(pendingTotal)} مورد در انتظار پاسخ',
            onBack: () => AppScope.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                // summary
                WcpCard(
                  pad: 16,
                  glow: true,
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const WcpIcon('inbox',
                            size: 26, color: Color(0xFFFFFFFF)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Fmt.fa(pendingTotal)} مورد',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'نیازمند رسیدگی شما',
                              style: TextStyle(fontSize: 12.5, color: c.tx2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // cards column (gap 10)
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _hubCardTile(context, cards[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hubCardTile(BuildContext context, _HubCard card) {
    final c = context.c;
    return WcpCard(
      pad: 14,
      onClick: () => AppScope.of(context).push(card.go),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: card.color.withAlpha(0x22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: WcpIcon(card.icon, size: 23, color: card.color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    card.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.tx3),
                  ),
                ),
              ],
            ),
          ),
          if (card.badge > 0) ...[
            const SizedBox(width: 13),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.error,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                Fmt.fa(card.badge),
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
          const SizedBox(width: 13),
          WcpIcon('chevronL', size: 18, color: c.tx3),
        ],
      ),
    );
  }
}

class _HubCard {
  const _HubCard({
    required this.id,
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.badge,
    required this.go,
  });
  final String id;
  final String icon;
  final String label;
  final String sub;
  final Color color;
  final int badge;
  final String go;
}

// ════════════════════════════════════════════════════════════════
// Tickets inbox
// ════════════════════════════════════════════════════════════════
class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  String _tab = 'open';
  // Connected → empty + loading (no fake-ticket flash); disconnected → the
  // design-reference sample so the screen isn't blank in preview mode.
  late List<Ticket> _tickets =
      StoreApi.hasStore ? <Ticket>[] : List.of(sampleTickets);
  bool _loading = StoreApi.hasStore;

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) _load();
  }

  Future<void> _load() async {
    final StoreResult res = await StoreApi.appTickets(status: 'all');
    if (!mounted) return;
    if (res.ok && res.map['available'] != false) {
      setState(() {
        _tickets = res.list.map(ticketFromApp).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _openNewTicket() async {
    final nav = AppScope.of(context);
    if (!StoreApi.hasStore) {
      nav.showToast('برای ساختِ تیکت، فروشگاه را متصل کنید',
          kind: 'info', icon: 'plus');
      return;
    }
    // Pull real departments from the ticketing module (fallback to general).
    List<Map<String, String>> depts = const [
      {'slug': 'general', 'name': 'پشتیبانی عمومی'}
    ];
    final StoreResult m = await StoreApi.ticketMeta();
    if (!mounted) return;
    if (m.ok && m.map['departments'] is List) {
      final List<Map<String, String>> d = <Map<String, String>>[
        for (final dynamic e in m.map['departments'] as List)
          if (e is Map)
            {
              'slug': (e['slug'] ?? '').toString(),
              'name': (e['name'] ?? e['slug'] ?? '').toString(),
            }
      ];
      if (d.isNotEmpty) depts = d;
    }
    if (!mounted) return;
    final bool? created = await showWcpSheet<bool>(
      context,
      title: 'تیکتِ جدید',
      child: _NewTicketSheet(departments: depts),
    );
    if (created == true && mounted) {
      setState(() => _loading = true);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    const tabs = <({String id, String l})>[
      (id: 'open', l: 'باز'),
      (id: 'pending', l: 'در انتظار'),
      (id: 'resolved', l: 'حل‌شده'),
      (id: 'closed', l: 'بسته'),
    ];
    final counts = <String, int>{
      'open': _tickets.where((t) => t.status == 'open').length,
      'pending': _tickets.where((t) => t.status == 'pending').length,
      'resolved': _tickets.where((t) => t.status == 'resolved').length,
      'closed': _tickets.where((t) => t.status == 'closed').length,
    };
    final list = _tickets.where((t) => t.status == _tab).toList();

    return Container(
      color: c.bg0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'تیکت‌ها',
            sub: '${Fmt.fa(counts['open']!)} تیکت باز',
            onBack: () => AppScope.of(context).pop(),
            actions: [
              IconBtn(
                name: 'plus',
                onClick: _openNewTicket,
              ),
              IconBtn(
                name: 'search',
                onClick: () => AppScope.of(context).push('search'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Segmented(
              full: true,
              value: _tab,
              onChange: (v) => setState(() => _tab = v),
              options: [
                for (final t in tabs)
                  (
                    value: t.id,
                    label: '${t.l} (${Fmt.fa(counts[t.id]!)})',
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading && _tickets.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                ? ListView(
                    padding: const EdgeInsets.only(top: 30),
                    children: const [
                      EmptyState(
                        icon: 'ticketSupport',
                        title: 'تیکتی نیست',
                        message: 'در این بخش تیکتی وجود ندارد.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _ticketCard(context, list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _ticketCard(BuildContext context, Ticket t) {
    final c = context.c;
    final sInfo = ticketStatusInfo(t.status);
    final s = _kindColors(context, sInfo.kind);
    final pColor = _kindColor(context, priorityInfo(t.priority).kind);

    return WcpCard(
      pad: 13,
      onClick: () =>
          AppScope.of(context).push('ticketDetail', {'id': t.id}),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // avatar + unread dot
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(name: t.customer, size: 44),
                if (t.unread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: c.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bg1, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              t.unread ? FontWeight.w800 : FontWeight.w700,
                          color: c.tx1,
                        ),
                      ),
                    ),
                    if (t.priority == 'high' || t.priority == 'urgent') ...[
                      const SizedBox(width: 7),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: pColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    if ((t.rating ?? 0) > 0) ...[
                      const SizedBox(width: 7),
                      Icon(Icons.star,
                          size: 13,
                          color: (t.rating ?? 0) >= 4
                              ? c.success
                              : ((t.rating ?? 0) <= 2 ? c.error : c.warning)),
                      Text(
                        Fmt.fa(t.rating ?? 0),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: (t.rating ?? 0) >= 4
                                ? c.success
                                : ((t.rating ?? 0) <= 2 ? c.error : c.warning)),
                      ),
                    ],
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    t.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.tx3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      WcpBadge(
                        color: s.color,
                        soft: s.soft,
                        dot: true,
                        child: Text(sInfo.fa),
                      ),
                      const SizedBox(width: 8),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '#${Fmt.fa(t.id)}',
                          style: TextStyle(fontSize: 11, color: c.tx3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· ${t.customer}',
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
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Ticket conversation
// ════════════════════════════════════════════════════════════════
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late Ticket _t;
  late List<TicketMessage> _msgs;
  late String _status;
  bool _loading = StoreApi.hasStore;
  bool _sending = false;

  // A pending image attachment (uploaded, awaiting send with the next reply).
  int? _pendingAttachId;
  String? _pendingAttachUrl;

  // Compose an internal note (invisible to the customer) instead of a reply.
  bool _internalMode = false;

  // Captured in didChangeDependencies so dispose() can restore the global
  // quick-add FAB (it's hidden while this composer screen is on top — it
  // would otherwise overlap the reply bar).
  VoidCallback? _restoreFab;

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  static const List<String> _quick = [
    'در حال بررسی هستیم 🙏',
    'سفارش شما امروز ارسال می‌شود',
    'مبلغ تا ۲۴ ساعت بازگردانده می‌شود',
  ];

  @override
  void initState() {
    super.initState();
    _t = sampleTickets.firstWhere(
      (x) => x.id == widget.id,
      orElse: () => sampleTickets.first,
    );
    _status = _t.status;
    // Connected → empty conversation + spinner (no fabricated customer
    // messages); disconnected → a small sample so the preview isn't blank.
    _msgs = StoreApi.hasStore
        ? <TicketMessage>[]
        : <TicketMessage>[
            TicketMessage(who: 'customer', text: _t.last, time: _t.time),
          ];
    if (StoreApi.hasStore) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hide the global quick-add «+» pill while this composer is on screen so
    // it doesn't overlap the reply bar. Capture showFab for dispose().
    if (_restoreFab == null) {
      final AppScope scope = AppScope.of(context);
      scope.hideFab();
      _restoreFab = scope.showFab;
    }
  }

  Future<void> _load() async {
    final StoreResult res = await StoreApi.appTicket(widget.id);
    if (!mounted) return;
    if (!res.ok || res.map['available'] == false) {
      setState(() => _loading = false);
      return;
    }
    final Map<String, dynamic> m = res.map;
    final Map<String, dynamic> tj =
        m['ticket'] is Map ? Map<String, dynamic>.from(m['ticket'] as Map) : {};
    final List<TicketMessage> msgs = <TicketMessage>[
      for (final dynamic raw in (m['messages'] is List ? m['messages'] as List : const []))
        if (raw is Map) ticketMessageFromApp(Map<String, dynamic>.from(raw)),
    ];
    setState(() {
      if (tj.isNotEmpty) {
        _t = ticketFromApp(tj);
        _status = _t.status;
      }
      _msgs = msgs; // real conversation (may be empty — that's honest)
      _loading = false;
    });
    _scrollToEnd();
  }

  @override
  void dispose() {
    _restoreFab?.call(); // bring the global quick-add «+» pill back
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _append(TicketMessage m) {
    setState(() => _msgs.add(m));
    _scrollToEnd();
  }

  // Attach: pick an image natively → upload to the media library → drop its
  // URL into the reply box so the agent sends it with the real _send().
  Future<void> _attach() async {
    final nav = AppScope.of(context);
    if (!StoreApi.hasStore) {
      nav.showToast('برای پیوستِ تصویر، فروشگاه را متصل کنید',
          kind: 'info', icon: 'image');
      return;
    }
    if (_sending) return;
    final Map<String, String>? picked = await Native.pickImage();
    if (picked == null || !mounted) return; // cancelled
    setState(() => _sending = true);
    final StoreResult r = await StoreApi.uploadMedia(
      data: picked['data'] ?? '',
      mime: picked['mime'] ?? 'image/jpeg',
      filename: picked['filename'] ?? 'image.jpg',
    );
    if (!mounted) return;
    setState(() => _sending = false);
    final String url = (r.map['url'] ?? '').toString();
    final int id = r.map['id'] is int
        ? r.map['id'] as int
        : int.tryParse('${r.map['id']}') ?? 0;
    if (r.ok && url.isNotEmpty && id > 0) {
      setState(() {
        _pendingAttachId = id;
        _pendingAttachUrl = url;
      });
      nav.showToast('تصویر پیوست شد؛ برای ارسال دکمهٔ ارسال را بزنید',
          kind: 'success', icon: 'image');
    } else {
      nav.showToast(r.error ?? 'آپلودِ تصویر ناموفق بود',
          kind: 'error', icon: 'alert');
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final int? attachId = _pendingAttachId;
    final String? attachUrl = _pendingAttachUrl;
    // Allow an image-only reply (text empty but an attachment is pending).
    if ((text.isEmpty && attachId == null) || _sending) return;

    // Not connected → local-only echo (demo preview, no server to write to).
    if (!StoreApi.hasStore) {
      _append(TicketMessage(
        who: 'agent',
        text: text,
        time: 'هم‌اکنون',
        images: attachUrl != null ? <String>[attachUrl] : const <String>[],
      ));
      _input.clear();
      setState(() {
        _pendingAttachId = null;
        _pendingAttachUrl = null;
      });
      return;
    }

    // Optimistic: show the bubble immediately (incl. the attached image) with a
    // «در حال ارسال…» stamp, then reconcile with the server-rendered message.
    final bool wasInternal = _internalMode;
    final TicketMessage optimistic = TicketMessage(
      who: 'agent',
      text: text,
      time: 'در حال ارسال…',
      images: attachUrl != null ? <String>[attachUrl] : const <String>[],
      internal: wasInternal,
    );
    setState(() {
      _sending = true;
      _msgs.add(optimistic);
      _pendingAttachId = null;
      _pendingAttachUrl = null;
    });
    _input.clear();
    _scrollToEnd();

    final StoreResult r = await StoreApi.ticketReply(
      widget.id,
      body: text,
      internal: _internalMode,
      attachmentIds: attachId != null ? <int>[attachId] : const <int>[],
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _msgs.remove(optimistic);
    });
    if (r.ok) {
      final Map<String, dynamic> mm = r.map['message'] is Map
          ? Map<String, dynamic>.from(r.map['message'] as Map)
          : <String, dynamic>{};
      _append(mm.isNotEmpty
          ? ticketMessageFromApp(mm)
          : TicketMessage(
              who: 'agent',
              text: text,
              time: 'هم‌اکنون',
              internal: wasInternal,
            ));
      // Internal-note mode is one-shot — don't carry it into the next reply.
      if (wasInternal) {
        setState(() => _internalMode = false);
      }
    } else {
      // Keep the user's text + restore the pending attachment so nothing is lost.
      _input.text = text;
      _input.selection =
          TextSelection.collapsed(offset: _input.text.length);
      setState(() {
        _pendingAttachId = attachId;
        _pendingAttachUrl = attachUrl;
      });
      AppScope.of(context).showToast(r.error ?? 'ارسالِ پاسخ ناموفق بود',
          kind: 'error', icon: 'alert');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sInfo = ticketStatusInfo(_t.status);
    final s = _kindColors(context, sInfo.kind);
    final curInfo = ticketStatusInfo(_status);

    return Container(
      color: c.bg0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: '#${Fmt.fa(_t.id)}',
            sub: _t.subject,
            onBack: () => AppScope.of(context).pop(),
            actions: [
              _StatusButton(
                color: s.color,
                soft: s.soft,
                label: curInfo.fa,
                onTap: () => _openActions(context),
              ),
            ],
          ),

          // customer banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: c.bg1,
              border: Border(bottom: BorderSide(color: c.line, width: 1)),
            ),
            child: Row(
              children: [
                Avatar(name: _t.customer, size: 38),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t.customer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'دپارتمان ${_t.dept} · اولویت ${priorityInfo(_t.priority).fa}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: c.tx3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                IconBtn(
                  name: 'user',
                  size: 18,
                  onClick: () => AppScope.of(context).push(
                    'customerProfile',
                    {'id': sampleCustomers.first.id},
                  ),
                ),
              ],
            ),
          ),

          // CSAT — the CUSTOMER's rating + feedback (read-only). Lets the
          // manager reward/reprimand the operator who handled the ticket.
          if ((_t.rating ?? 0) > 0) _ratingCard(context),

          // messages
          Expanded(
            child: _loading && _msgs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scroll,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.bg2,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _t.time,
                            style: TextStyle(fontSize: 11, color: c.tx3),
                          ),
                        ),
                      ),
                      if (_msgs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: Text(
                            'هنوز پیامی در این تیکت ثبت نشده است.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: c.tx3),
                          ),
                        ),
                      for (var i = 0; i < _msgs.length; i++) ...[
                        const SizedBox(height: 12),
                        _bubble(context, _msgs[i]),
                      ],
                    ],
                  ),
          ),

          // quick replies
          if (_status != 'closed')
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  for (var i = 0; i < _quick.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    WcpChip(
                      // Route through the real sender so a connected store
                      // actually receives the reply (no fabricated local echo).
                      onClick: () {
                        _input.text = _quick[i];
                        _send();
                      },
                      child: Text(_quick[i]),
                    ),
                  ],
                ],
              ),
            ),

          // input / closed footer
          if (_status != 'closed')
            _inputBar(context)
          else
            _closedFooter(context),
        ],
      ),
    );
  }

  // message bubble — agent physically left, customer physically right
  // (matches JSX bubble geometry + timestamp textAlign). The outer row is
  // pinned LTR so start=left/end=right; bubble + timestamp content stay RTL.
  Widget _bubble(BuildContext context, TicketMessage m) {
    final c = context.c;
    final isAgent = m.who == 'agent';
    return Row(
      textDirection: TextDirection.ltr,
      mainAxisAlignment:
          isAgent ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.internal)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x33F59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'یادداشت داخلی',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: m.internal
                      ? const Color(0x1AF59E0B)
                      : (isAgent ? c.accent : c.bg2),
                  borderRadius: isAgent
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(16),
                        )
                      : const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(4),
                        ),
                  border:
                      isAgent ? null : Border.all(color: c.line, width: 1),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final String img in m.images) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxHeight: 220, minHeight: 60),
                            child: Image.network(
                              img,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, prog) =>
                                  prog == null
                                      ? child
                                      : const SizedBox(
                                          height: 120,
                                          child: Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            ),
                                          ),
                                        ),
                              errorBuilder: (ctx, e, st) => Container(
                                height: 80,
                                alignment: Alignment.center,
                                color: c.bg3,
                                child: WcpIcon('image', size: 22, color: c.tx3),
                              ),
                            ),
                          ),
                        ),
                        if (m.text.isNotEmpty) const SizedBox(height: 8),
                      ],
                      if (m.text.isNotEmpty)
                        Text(
                          m.text,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: m.internal
                                ? const Color(0xFFB45309)
                                : (isAgent ? c.txOnAccent : c.tx1),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${isAgent ? 'شما' : _t.customer} · ${m.time}',
                  textAlign: isAgent ? TextAlign.left : TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 10, color: c.tx3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Read-only customer-satisfaction card (CSAT). The rating + comment are
  // written by the CUSTOMER; the manager only views them here, with the
  // operator's name, to reward or reprimand.
  Widget _ratingCard(BuildContext context) {
    final c = context.c;
    final int r = _t.rating ?? 0;
    final bool good = r >= 4;
    final bool bad = r <= 2;
    final Color col = good ? c.success : (bad ? c.error : c.warning);
    final Color soft = good ? c.successSoft : (bad ? c.errorSoft : c.warningSoft);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: col.withAlpha(0x55), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WcpIcon('star', size: 18, fill: true, color: col),
              const SizedBox(width: 7),
              Text(
                'امتیازِ رضایتِ مشتری',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: c.tx1),
              ),
              const Spacer(),
              // stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var s = 1; s <= 5; s++)
                    Icon(
                      s <= r ? Icons.star : Icons.star_border,
                      size: 17,
                      color: s <= r ? col : c.tx3,
                    ),
                ],
              ),
              const SizedBox(width: 6),
              Text('${Fmt.fa(r)}/۵',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: col)),
            ],
          ),
          if (_t.ratingComment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                '«${_t.ratingComment}»',
                style: TextStyle(fontSize: 12.5, height: 1.7, color: c.tx2),
              ),
            ),
          ],
          if (_t.assigneeName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                WcpIcon('users', size: 14, color: c.tx3),
                const SizedBox(width: 6),
                Text('اپراتورِ رسیدگی‌کننده: ${_t.assigneeName}',
                    style: TextStyle(fontSize: 12, color: c.tx3)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // input bar
  Widget _inputBar(BuildContext context) {
    final c = context.c;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Internal-note toggle (agent-only). When ON, the composer turns
          // amber and the reply lands as a private note instead of a customer
          // reply — uses the same /app/tickets/{id}/reply with internal:true.
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _internalMode = !_internalMode),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _internalMode
                              ? const Color(0xFFF59E0B)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _internalMode
                                ? const Color(0xFFF59E0B)
                                : c.tx3,
                            width: 1.5,
                          ),
                        ),
                        child: _internalMode
                            ? const Icon(Icons.check,
                                size: 12, color: Color(0xFF0A0A0D))
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'یادداشتِ داخلی (نامرئی برای مشتری)',
                        style: TextStyle(
                          fontSize: 12,
                          color: _internalMode
                              ? const Color(0xFFF59E0B)
                              : c.tx2,
                          fontWeight: _internalMode
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_pendingAttachUrl != null) _attachPreview(context),
          Row(
        children: [
          IconBtnRaw(
            onClick: _sending ? () {} : _attach,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const WcpIcon('image', size: 20),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _internalMode
                    ? const Color(0x1AF59E0B) // amber@.10
                    : c.bg1,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: _internalMode
                      ? const Color(0xFFF59E0B)
                      : c.line,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _input,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                cursorColor: c.accent,
                style: TextStyle(
                  fontFamily: T.family,
                  fontSize: 14,
                  color: c.tx1,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: _internalMode
                      ? 'یادداشت داخلی…'
                      : 'پاسخ خود را بنویسید…',
                  hintStyle: TextStyle(
                    fontFamily: T.family,
                    fontSize: 14,
                    color: c.tx3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          _SendButton(
            active: _input.text.trim().isNotEmpty || _pendingAttachId != null,
            onTap: _send,
          ),
        ],
          ),
        ],
      ),
    );
  }

  // Pending-attachment preview shown above the composer (thumb + remove ×).
  Widget _attachPreview(BuildContext context) {
    final c = context.c;
    final String url = _pendingAttachUrl ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 46,
              height: 46,
              fit: BoxFit.cover,
              errorBuilder: (ctx, e, st) => Container(
                width: 46,
                height: 46,
                color: c.bg3,
                alignment: Alignment.center,
                child: WcpIcon('image', size: 18, color: c.tx3),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'تصویر آمادهٔ ارسال',
              style: TextStyle(fontSize: 12.5, color: c.tx2),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _pendingAttachId = null;
              _pendingAttachUrl = null;
            }),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.bg3, shape: BoxShape.circle),
              child: WcpIcon('x', size: 14, sw: 2.5, color: c.tx2),
            ),
          ),
        ],
      ),
    );
  }

  // closed footer
  Widget _closedFooter(BuildContext context) {
    final c = context.c;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottom + 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'این تیکت بسته شده است${_t.rating != null ? ' · رضایت ${Fmt.fa(_t.rating!)}/۵' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.tx3),
            ),
          ),
          WcpButton(
            variant: 'soft',
            full: true,
            icon: 'refresh',
            label: 'بازگشایی تیکت',
            onClick: () async {
              final nav = AppScope.of(context);
              final StoreResult r =
                  await StoreApi.ticketStatus(widget.id, status: 'open');
              if (!mounted) return;
              if (r.ok) {
                setState(() => _status = 'open');
                nav.showToast('تیکت بازگشایی شد', kind: 'success', icon: 'refresh');
              } else {
                nav.showToast(r.error ?? 'بازگشایی ناموفق بود',
                    kind: 'error', icon: 'alert');
              }
            },
          ),
        ],
      ),
    );
  }

  // ── actions sheet ───────────────────────────────────────────────
  void _openActions(BuildContext context) {
    showWcpSheet<void>(
      context,
      title: 'اقدامات تیکت',
      child: _TicketActions(
        current: _status,
        onPick: (k) async {
          Navigator.of(context).pop();
          final nav = AppScope.of(context);
          final StoreResult r =
              await StoreApi.ticketStatus(widget.id, status: k);
          if (!mounted) return;
          if (r.ok) {
            setState(() => _status = k);
            nav.showToast('وضعیت تیکت: ${ticketStatusInfo(k).fa}', kind: 'success');
          } else {
            nav.showToast(r.error ?? 'تغییر وضعیت ناموفق بود',
                kind: 'error', icon: 'alert');
          }
        },
        onAssign: () {
          Navigator.of(context).pop();
          _openAssign(context);
        },
        onPriority: () {
          Navigator.of(context).pop();
          _openPriority(context);
        },
        onDept: () {
          Navigator.of(context).pop();
          _openDept();
        },
      ),
    );
  }

  // Real priority picker → POST /app/tickets/{id}/status {priority}.
  void _openPriority(BuildContext context) {
    if (!StoreApi.hasStore) {
      AppScope.of(context).showToast(
          'برای تغییر اولویت، فروشگاه را متصل کنید',
          kind: 'info', icon: 'gauge');
      return;
    }
    showWcpSheet<void>(
      context,
      title: 'تغییر اولویتِ تیکت',
      child: _PrioritySheet(
        current: _t.priority,
        onPick: (String p) async {
          final nav = AppScope.of(context);
          Navigator.of(context).pop();
          final StoreResult r =
              await StoreApi.ticketStatus(widget.id, priority: p);
          if (!mounted) return;
          if (r.ok) {
            setState(() => _t = _t.copyWithPriority(p));
            nav.showToast('اولویت: ${priorityInfo(p).fa}',
                kind: 'success', icon: 'gauge');
          } else {
            nav.showToast(r.error ?? 'تغییر اولویت ناموفق بود',
                kind: 'error', icon: 'alert');
          }
        },
      ),
    );
  }

  // Real department picker → POST /app/tickets/{id}/status {department}.
  Future<void> _openDept() async {
    final nav = AppScope.of(context);
    if (!StoreApi.hasStore) {
      nav.showToast('برای تغییر دپارتمان، فروشگاه را متصل کنید',
          kind: 'info', icon: 'users');
      return;
    }
    final StoreResult m = await StoreApi.ticketMeta();
    if (!mounted) return;
    final List<Map<String, String>> depts = <Map<String, String>>[
      if (m.ok && m.map['departments'] is List)
        for (final dynamic e in m.map['departments'] as List)
          if (e is Map)
            {
              'slug': (e['slug'] ?? '').toString(),
              'name': (e['name'] ?? e['slug'] ?? '').toString(),
            }
    ];
    if (depts.isEmpty) {
      nav.showToast('دپارتمانی یافت نشد', kind: 'info', icon: 'users');
      return;
    }
    if (!mounted) return;
    showWcpSheet<void>(
      context,
      title: 'تغییر دپارتمان',
      child: _DeptSheet(
        current: _t.dept,
        departments: depts,
        onPick: (String slug, String name) async {
          Navigator.of(context).pop();
          final StoreResult r =
              await StoreApi.ticketStatus(widget.id, department: slug);
          if (!mounted) return;
          nav.showToast(
              r.ok ? 'دپارتمان: $name' : (r.error ?? 'تغییر دپارتمان ناموفق بود'),
              kind: r.ok ? 'success' : 'error',
              icon: r.ok ? 'users' : 'alert');
        },
      ),
    );
  }

  // Real staff picker → assign the ticket via POST /app/tickets/{id}/status.
  void _openAssign(BuildContext context) {
    if (!StoreApi.hasStore) {
      AppScope.of(context).showToast('برای تخصیص، فروشگاه را متصل کنید',
          kind: 'info', icon: 'users');
      return;
    }
    showWcpSheet<void>(
      context,
      title: 'تخصیص به همکار',
      child: _AssignSheet(
        onPick: (int uid, String name) async {
          final nav = AppScope.of(context);
          Navigator.of(context).pop();
          final StoreResult r =
              await StoreApi.ticketStatus(widget.id, assigneeId: uid);
          if (!mounted) return;
          nav.showToast(
              r.ok ? 'تیکت به $name تخصیص یافت' : (r.error ?? 'تخصیص ناموفق بود'),
              kind: r.ok ? 'success' : 'error',
              icon: r.ok ? 'users' : 'alert');
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Staff picker — loads /app/team and lets an agent assign the ticket.
// ════════════════════════════════════════════════════════════════
class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.onPick});
  final void Function(int uid, String name) onPick;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _staff = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final StoreResult r = await StoreApi.appTeam();
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _loading = false;
        _error = r.error ?? 'دریافتِ فهرستِ همکاران ناموفق بود';
      });
      return;
    }
    setState(() {
      _staff = r.list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(_error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.error)),
      );
    }
    if (_staff.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('همکاری برای تخصیص یافت نشد.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.tx3)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in _staff) ...[
          ListRow(
            icon: 'users',
            title: (s['display_name'] ?? s['login'] ?? '—').toString(),
            sub: (s['role_label'] ?? s['email'] ?? '').toString(),
            chevron: true,
            onClick: () => widget.onPick(
              int.tryParse('${s['id']}') ?? 0,
              (s['display_name'] ?? s['login'] ?? '').toString(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Priority picker — 4 rows (low/normal/high/urgent) with kind colors.
// ════════════════════════════════════════════════════════════════
class _PrioritySheet extends StatelessWidget {
  const _PrioritySheet({required this.current, required this.onPick});
  final String current;
  final void Function(String slug) onPick;

  static const List<String> _slugs = <String>['low', 'normal', 'high', 'urgent'];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _slugs.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _row(context, _slugs[i]),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, String slug) {
    final c = context.c;
    final info = priorityInfo(slug);
    final bool selected = current == slug;
    final Color color = _priorityColor(c, info.kind);
    final Color soft = _prioritySoft(c, info.kind);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onPick(slug),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? soft : c.bg1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : c.line, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'اولویتِ «${info.fa}»',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.tx1,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 18, color: Color(0xFF16A34A)),
          ],
        ),
      ),
    );
  }

  static Color _priorityColor(AppColors c, String kind) {
    switch (kind) {
      case 'error':
        return c.error;
      case 'warning':
        return c.warning;
      case 'success':
        return c.success;
      default:
        return c.tx3;
    }
  }

  static Color _prioritySoft(AppColors c, String kind) {
    switch (kind) {
      case 'error':
        return c.errorSoft;
      case 'warning':
        return c.warningSoft;
      case 'success':
        return c.successSoft;
      default:
        return c.bg2;
    }
  }
}

// ════════════════════════════════════════════════════════════════
// Department picker (real, from the ticketing module's departments).
// ════════════════════════════════════════════════════════════════
class _DeptSheet extends StatelessWidget {
  const _DeptSheet(
      {required this.current, required this.departments, required this.onPick});
  final String current; // current dept name OR slug
  final List<Map<String, String>> departments;
  final void Function(String slug, String name) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in departments) ...[
          ListRow(
            icon: 'layers',
            title: d['name'] ?? d['slug'] ?? '—',
            chevron: true,
            onClick: () =>
                onPick(d['slug'] ?? '', d['name'] ?? d['slug'] ?? ''),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// New-ticket composer (merchant-side) → StoreApi.ticketCreate.
// Pops `true` after a successful create so the list refreshes.
// ════════════════════════════════════════════════════════════════
class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet({required this.departments});
  final List<Map<String, String>> departments;

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  String _subject = '';
  String _body = '';
  String _email = '';
  String _name = '';
  late String _dept = widget.departments.isNotEmpty
      ? (widget.departments.first['slug'] ?? 'general')
      : 'general';
  String _priority = 'normal';
  bool _busy = false;

  static const List<({String slug, String fa})> _prios = [
    (slug: 'low', fa: 'کم'),
    (slug: 'normal', fa: 'عادی'),
    (slug: 'high', fa: 'زیاد'),
    (slug: 'urgent', fa: 'فوری'),
  ];

  Future<void> _submit() async {
    final nav = AppScope.of(context);
    if (_subject.trim().length < 3) {
      nav.showToast('موضوع باید حداقل ۳ کاراکتر باشد', kind: 'error', icon: 'alert');
      return;
    }
    if (_body.trim().isEmpty) {
      nav.showToast('متنِ تیکت را وارد کنید', kind: 'error', icon: 'alert');
      return;
    }
    final String em = _email.trim();
    if (!em.contains('@') || !em.contains('.')) {
      nav.showToast('ایمیلِ مشتری معتبر نیست', kind: 'error', icon: 'alert');
      return;
    }
    setState(() => _busy = true);
    final StoreResult r = await StoreApi.ticketCreate(
      subject: _subject.trim(),
      body: _body.trim(),
      customerEmail: em,
      customerName: _name.trim(),
      department: _dept,
      priority: _priority,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      Navigator.of(context).pop(true);
      nav.showToast('تیکت ساخته شد', kind: 'success', icon: 'check');
    } else {
      nav.showToast(r.error ?? 'ساختِ تیکت ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WcpField(
          label: 'موضوع',
          value: _subject,
          placeholder: 'موضوعِ تیکت',
          onChange: (v) => _subject = v,
        ),
        const SizedBox(height: 12),
        WcpField(
          label: 'ایمیلِ مشتری',
          value: _email,
          placeholder: 'customer@example.com',
          onChange: (v) => _email = v,
        ),
        const SizedBox(height: 12),
        WcpField(
          label: 'نامِ مشتری (اختیاری)',
          value: _name,
          placeholder: 'نام',
          onChange: (v) => _name = v,
        ),
        const SizedBox(height: 12),
        WcpField(
          label: 'متنِ تیکت',
          value: _body,
          multiline: true,
          placeholder: 'شرحِ موضوع…',
          onChange: (v) => _body = v,
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(right: 2, bottom: 8),
          child: Text('دپارتمان',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: c.tx3)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in widget.departments)
              WcpChip(
                active: _dept == (d['slug'] ?? ''),
                onClick: () => setState(() => _dept = d['slug'] ?? 'general'),
                child: Text(d['name'] ?? d['slug'] ?? '—'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(right: 2, bottom: 8),
          child: Text('اولویت',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: c.tx3)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _prios)
              WcpChip(
                active: _priority == p.slug,
                onClick: () => setState(() => _priority = p.slug),
                child: Text(p.fa),
              ),
          ],
        ),
        const SizedBox(height: 16),
        WcpButton(
          full: true,
          size: 'lg',
          icon: 'plus',
          label: _busy ? 'در حال ساخت…' : 'ساختِ تیکت',
          onClick: _busy ? null : _submit,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AppBar status pill button (badge + chevronD) — opens actions sheet.
// JSX `iconBtn` width auto, padding 0/12, gap 5.
// ════════════════════════════════════════════════════════════════
class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.color,
    required this.soft,
    required this.label,
    required this.onTap,
  });
  final Color color;
  final Color soft;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.bg1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.line, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WcpBadge(color: color, soft: soft, child: Text(label)),
            const SizedBox(width: 5),
            WcpIcon('chevronD', size: 15, color: c.tx1),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Send button — 46 circle, accent when active else bg3.
// ════════════════════════════════════════════════════════════════
class _SendButton extends StatelessWidget {
  const _SendButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.accent : c.bg3,
          shape: BoxShape.circle,
        ),
        child: WcpIcon(
          'send',
          size: 19,
          color: active ? const Color(0xFFFFFFFF) : c.tx3,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Ticket actions sheet body.
// ════════════════════════════════════════════════════════════════
class _TicketActions extends StatelessWidget {
  const _TicketActions({
    required this.current,
    required this.onPick,
    required this.onAssign,
    required this.onPriority,
    required this.onDept,
  });
  final String current;
  final ValueChanged<String> onPick;
  final VoidCallback onAssign;
  final VoidCallback onPriority;
  final VoidCallback onDept;

  static const List<String> _statuses = ['open', 'pending', 'resolved', 'closed'];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _statuses.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _statusRow(context, _statuses[i]),
        ],
        // Sep
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(height: 1, color: c.line),
        ),
        ListRow(
          icon: 'users',
          title: 'تخصیص به همکار',
          chevron: true,
          onClick: onAssign,
        ),
        ListRow(
          icon: 'gauge',
          title: 'تغییر اولویت',
          chevron: true,
          onClick: onPriority,
        ),
        ListRow(
          icon: 'layers',
          title: 'تغییر دپارتمان',
          chevron: true,
          onClick: onDept,
        ),
      ],
    );
  }

  Widget _statusRow(BuildContext context, String k) {
    final c = context.c;
    final info = ticketStatusInfo(k);
    final col = _kindColors(context, info.kind);
    final selected = current == k;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onPick(k),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? col.soft : c.bg2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: col.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'تغییر به «${info.fa}»',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              WcpIcon('check', size: 18, sw: 2.4, color: col.color),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Registration
// ════════════════════════════════════════════════════════════════
void registerSupportScreen() {
  kScreens['supportHub'] = (ctx, p) => const SupportHubScreen();
  kScreens['tickets'] = (ctx, p) => const TicketsScreen();
  kScreens['ticketDetail'] =
      (ctx, p) => TicketDetailScreen(id: p['id'] as int);
}
