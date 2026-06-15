// ════════════════════════════════════════════════════════════════
// chat.dart — «گفتگوی زنده» (Live Chat) for staff.
//
// Reads/writes ALL message content against the MERCHANT'S OWN store
// (woocommerce-plus/v1/app/chat/*), exactly like the tickets screen. The
// central server is only a content-free change beacon — never contacted for
// message bodies. Mirrors support.dart's inbox + conversation patterns.
//
// Routes:
//   chatInbox  → ChatInboxScreen        (conversation list)
//   chatThread → ChatConversationScreen (one conversation + composer)
// ════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../core/icons.dart';
import '../core/fmt.dart';
import '../nav/shell.dart';
import '../services/store_api.dart';
import '../widgets/ui.dart';
import 'registry.dart';

void registerChatScreen() {
  kScreens['chatInbox'] = (ctx, p) => const ChatInboxScreen();
  kScreens['chatThread'] = (ctx, p) => ChatConversationScreen(
        id: p['id'] is int ? p['id'] as int : int.tryParse('${p['id']}') ?? 0,
        name: (p['name'] ?? '').toString(),
      );
  kScreens['chatStaff'] = (ctx, p) => const ChatStaffScreen();
}

// ── status → (color, soft, label) ───────────────────────────────
({Color color, Color soft, String fa}) _statusInfo(BuildContext context, String s) {
  final c = context.c;
  switch (s) {
    case 'closed':
      return (color: c.tx3, soft: c.bg2, fa: 'بسته');
    case 'pending':
      return (color: c.warning, soft: c.warningSoft, fa: 'در انتظار');
    case 'open':
    default:
      return (color: c.success, soft: c.successSoft, fa: 'باز');
  }
}

// ════════════════════════════════════════════════════════════════
// Inbox — conversation list
// ════════════════════════════════════════════════════════════════
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  String _tab = 'open';
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  bool _loading = StoreApi.hasStore;
  bool _available = true;
  bool _isManager = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
      _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final StoreResult r = await StoreApi.chatConversations(status: 'all');
    if (!mounted) return;
    if (r.ok && r.map['available'] != false) {
      setState(() {
        _items = r.list;
        _loading = false;
        _available = true;
        _isManager = r.map['is_manager'] == true;
      });
    } else {
      setState(() {
        _loading = false;
        _available = r.map['available'] != false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const tabs = <({String id, String l})>[
      (id: 'open', l: 'باز'),
      (id: 'pending', l: 'در انتظار'),
      (id: 'closed', l: 'بسته'),
    ];
    int countOf(String s) => _items.where((e) => (e['status'] ?? 'open') == s).length;
    final list = _items.where((e) => (e['status'] ?? 'open') == _tab).toList();
    final int openUnread = _items.fold(0, (a, e) => a + ((e['staff_unread'] ?? 0) as num).toInt());

    return Container(
      color: c.bg0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'گفتگوی زنده',
            sub: '${Fmt.fa(openUnread)} پیام خوانده‌نشده',
            onBack: () => AppScope.of(context).pop(),
            actions: _isManager
                ? [IconBtn(name: 'users', onClick: () => AppScope.of(context).push('chatStaff'))]
                : const <Widget>[],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Segmented(
              full: true,
              value: _tab,
              onChange: (v) => setState(() => _tab = v),
              options: [
                for (final t in tabs) (value: t.id, label: '${t.l} (${Fmt.fa(countOf(t.id))})'),
              ],
            ),
          ),
          Expanded(
            child: !_available
                ? ListView(padding: const EdgeInsets.only(top: 30), children: const [
                    EmptyState(
                      icon: 'message',
                      title: 'ماژول گفتگو فعال نیست',
                      message: 'از تنظیمات افزونه، «گفتگوی زنده» را روشن کنید.',
                    ),
                  ])
                : _loading && _items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : list.isEmpty
                        ? ListView(padding: const EdgeInsets.only(top: 30), children: const [
                            EmptyState(
                              icon: 'message',
                              title: 'گفتگویی نیست',
                              message: 'در این بخش گفتگویی وجود ندارد.',
                            ),
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _row(context, list[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> e) {
    final c = context.c;
    final String name = (e['customer_name'] ?? 'مشتری').toString();
    final String status = (e['status'] ?? 'open').toString();
    final int unread = ((e['staff_unread'] ?? 0) as num).toInt();
    final info = _statusInfo(context, status);

    return WcpCard(
      pad: 13,
      onClick: () => AppScope.of(context).push('chatThread', {'id': e['id'], 'name': name}),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(name: name, size: 44),
                if (unread > 0)
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
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700,
                    color: c.tx1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      WcpBadge(color: info.color, soft: info.soft, dot: true, child: Text(info.fa)),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Text('${Fmt.fa(unread)} پیام تازه',
                            style: TextStyle(fontSize: 11, color: c.error, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          WcpIcon('chevronL', size: 18, color: c.tx3),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Conversation — messages + composer
// ════════════════════════════════════════════════════════════════
class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({super.key, required this.id, this.name = ''});
  final int id;
  final String name;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final List<Map<String, dynamic>> _msgs = <Map<String, dynamic>>[];
  String _status = 'open';
  String _name = '';
  bool _loading = StoreApi.hasStore;
  bool _sending = false;
  bool _internal = false;
  int _lastId = 0;
  Timer? _poll;
  VoidCallback? _restoreFab;

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    if (StoreApi.hasStore) {
      _load();
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoreFab == null) {
      final AppScope scope = AppScope.of(context);
      scope.hideFab();
      _restoreFab = scope.showFab;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _restoreFab?.call();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final StoreResult r = await StoreApi.chatMessages(widget.id, afterId: _lastId);
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() => _loading = false);
      return;
    }
    final List<Map<String, dynamic>> fresh = r.list;
    setState(() {
      _status = (r.map['status'] ?? _status).toString();
      final String n = (r.map['customer_name'] ?? '').toString();
      if (n.isNotEmpty) _name = n;
      for (final m in fresh) {
        final int mid = ((m['id'] ?? 0) as num).toInt();
        if (mid > _lastId) _lastId = mid;
        _msgs.add(m);
      }
      _loading = false;
    });
    if (fresh.isNotEmpty) _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (!StoreApi.hasStore) return;
    final bool wasInternal = _internal;
    setState(() => _sending = true);
    _input.clear();
    final StoreResult r = await StoreApi.chatReply(widget.id, text, internal: wasInternal);
    if (!mounted) return;
    setState(() => _sending = false);
    if (r.ok && r.map['message'] is Map) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(r.map['message'] as Map);
      final int mid = ((m['id'] ?? 0) as num).toInt();
      if (mid > _lastId) {
        _lastId = mid;
        setState(() => _msgs.add(m));
        _scrollToEnd();
      }
      if (wasInternal) setState(() => _internal = false);
    } else {
      _input.text = text;
      AppScope.of(context).showToast(r.error ?? 'ارسال پیام ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  Future<void> _setStatus(String s) async {
    final nav = AppScope.of(context);
    final StoreResult r = await StoreApi.chatStatus(widget.id, s);
    if (!mounted) return;
    if (r.ok) {
      setState(() => _status = s);
      nav.showToast(s == 'closed' ? 'گفتگو بسته شد' : 'گفتگو باز شد', kind: 'success', icon: 'check');
    } else {
      nav.showToast(r.error ?? 'تغییر وضعیت ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final info = _statusInfo(context, _status);
    return Container(
      color: c.bg0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: _name.isNotEmpty ? _name : 'گفتگو',
            sub: info.fa,
            onBack: () => AppScope.of(context).pop(),
            actions: [
              IconBtn(
                name: _status == 'closed' ? 'refresh' : 'check',
                onClick: () => _setStatus(_status == 'closed' ? 'open' : 'closed'),
              ),
            ],
          ),
          Expanded(
            child: _loading && _msgs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    children: [
                      if (_msgs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: Text('هنوز پیامی در این گفتگو نیست.',
                              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: c.tx3)),
                        ),
                      for (var i = 0; i < _msgs.length; i++) ...[
                        const SizedBox(height: 12),
                        _bubble(context, _msgs[i]),
                      ],
                    ],
                  ),
          ),
          if (_status != 'closed') _inputBar(context) else _closedFooter(context),
        ],
      ),
    );
  }

  // staff = physically left, customer = physically right (LTR-pinned row).
  Widget _bubble(BuildContext context, Map<String, dynamic> m) {
    final c = context.c;
    final String type = (m['sender_type'] ?? 'system').toString();
    final bool isStaff = type == 'staff';
    final bool isSystem = type == 'system';
    final bool internal = ((m['is_internal'] ?? 0) as num).toInt() == 1;
    final String body = (m['body'] ?? '').toString();
    final String who = (m['sender_name'] ?? '').toString();

    if (isSystem) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(999)),
          child: Text(body, style: TextStyle(fontSize: 11.5, color: c.tx3)),
        ),
      );
    }

    return Row(
      textDirection: TextDirection.ltr,
      mainAxisAlignment: isStaff ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: internal ? const Color(0x1AF59E0B) : (isStaff ? c.accent : c.bg2),
                  borderRadius: isStaff
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(16))
                      : const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(4)),
                  border: isStaff ? null : Border.all(color: c.line, width: 1),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (internal)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text('یادداشت داخلی',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
                        ),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: internal ? const Color(0xFFB45309) : (isStaff ? c.txOnAccent : c.tx1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isStaff ? (who.isNotEmpty ? who : 'شما') : (_name.isNotEmpty ? _name : 'مشتری'),
                  textAlign: isStaff ? TextAlign.left : TextAlign.right,
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

  Widget _inputBar(BuildContext context) {
    final c = context.c;
    final double bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line, width: 1))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _internal = !_internal),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _internal ? const Color(0xFFF59E0B) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _internal ? const Color(0xFFF59E0B) : c.tx3, width: 1.5),
                    ),
                    child: _internal ? const Icon(Icons.check, size: 12, color: Color(0xFF0A0A0D)) : null,
                  ),
                  const SizedBox(width: 8),
                  Text('یادداشت داخلی (نامرئی برای مشتری)',
                      style: TextStyle(
                          fontSize: 12,
                          color: _internal ? const Color(0xFFF59E0B) : c.tx2,
                          fontWeight: _internal ? FontWeight.w700 : FontWeight.w500)),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _internal ? const Color(0x1AF59E0B) : c.bg1,
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(color: _internal ? const Color(0xFFF59E0B) : c.line, width: 1),
                  ),
                  child: TextField(
                    controller: _input,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 4,
                    cursorColor: c.accent,
                    style: TextStyle(fontFamily: T.family, fontSize: 14, color: c.tx1),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: _internal ? 'یادداشت داخلی…' : 'پاسخ خود را بنویسید…',
                      hintStyle: TextStyle(fontFamily: T.family, fontSize: 14, color: c.tx3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (_input.text.trim().isNotEmpty && !_sending) ? c.accent : c.bg3,
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : WcpIcon('send',
                          size: 20,
                          color: (_input.text.trim().isNotEmpty) ? c.txOnAccent : c.tx3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _closedFooter(BuildContext context) {
    final c = context.c;
    final double bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottom + 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line, width: 1))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('این گفتگو بسته شده است.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.tx3)),
          ),
          WcpButton(
            variant: 'soft',
            full: true,
            icon: 'refresh',
            label: 'بازگشایی گفتگو',
            onClick: () => _setStatus('open'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Staff & departments — manager-only access model management.
// ════════════════════════════════════════════════════════════════
class ChatStaffScreen extends StatefulWidget {
  const ChatStaffScreen({super.key});

  @override
  State<ChatStaffScreen> createState() => _ChatStaffScreenState();
}

class _ChatStaffScreenState extends State<ChatStaffScreen> {
  bool _loading = true;
  bool _forbidden = false;
  List<Map<String, dynamic>> _staff = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _depts = const <Map<String, dynamic>>[];
  final TextEditingController _newDept = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newDept.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final StoreResult r = await StoreApi.chatStaff();
    if (!mounted) return;
    if (r.statusCode == 403) {
      setState(() {
        _forbidden = true;
        _loading = false;
      });
      return;
    }
    setState(() {
      _staff = (r.map['staff'] is List)
          ? List<Map<String, dynamic>>.from((r.map['staff'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)))
          : const <Map<String, dynamic>>[];
      _depts = (r.map['departments'] is List)
          ? List<Map<String, dynamic>>.from((r.map['departments'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)))
          : const <Map<String, dynamic>>[];
      _loading = false;
    });
  }

  String _deptName(int id) {
    for (final d in _depts) {
      if (((d['id'] ?? 0) as num).toInt() == id) return (d['name'] ?? '').toString();
    }
    return '#$id';
  }

  Future<void> _addDept() async {
    final String name = _newDept.text.trim();
    if (name.isEmpty) return;
    _newDept.clear();
    final StoreResult r = await StoreApi.chatCreateDepartment(name);
    if (!mounted) return;
    if (r.ok) {
      await _load();
    } else {
      AppScope.of(context).showToast(r.error ?? 'ساخت دپارتمان ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  Future<void> _deleteDept(int id) async {
    final StoreResult r = await StoreApi.chatDeleteDepartment(id);
    if (!mounted) return;
    if (r.ok) _load();
  }

  Future<void> _editStaff(Map<String, dynamic> s) async {
    final bool? saved = await showWcpSheet<bool>(
      context,
      title: (s['name'] ?? '').toString(),
      child: _StaffEditSheet(staff: s, departments: _depts),
    );
    if (saved == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      color: c.bg0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'کارکنان و دپارتمان‌ها',
            sub: 'دسترسی هر کارمند به گفتگوها',
            onBack: () => AppScope.of(context).pop(),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _forbidden
                    ? ListView(padding: const EdgeInsets.only(top: 30), children: const [
                        EmptyState(
                          icon: 'shield',
                          title: 'دسترسی محدود',
                          message: 'فقط مدیر می‌تواند دپارتمان‌ها و دسترسی کارکنان را تنظیم کند.',
                        ),
                      ])
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _sectionTitle(context, 'دپارتمان‌ها'),
                          WcpCard(
                            pad: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final d in _depts)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        WcpIcon('layers', size: 16, color: c.tx3),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text((d['name'] ?? '').toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                                        IconBtn(name: 'x', size: 16, onClick: () => _deleteDept(((d['id'] ?? 0) as num).toInt())),
                                      ],
                                    ),
                                  ),
                                if (_depts.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Text('هنوز دپارتمانی ساخته نشده.', style: TextStyle(fontSize: 12.5, color: c.tx3)),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(color: c.bg1, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.line)),
                                        child: TextField(
                                          controller: _newDept,
                                          style: TextStyle(fontFamily: T.family, fontSize: 13, color: c.tx1),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                            hintText: 'نام دپارتمان جدید',
                                            hintStyle: TextStyle(fontFamily: T.family, fontSize: 13, color: c.tx3),
                                          ),
                                          onSubmitted: (_) => _addDept(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    WcpButton(variant: 'soft', icon: 'plus', label: 'افزودن', onClick: _addDept),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _sectionTitle(context, 'کارکنان'),
                          for (final s in _staff) ...[
                            ListRow(
                              icon: 'users',
                              title: (s['name'] ?? '').toString(),
                              sub: _staffSub(s),
                              chevron: !(s['is_admin'] == true),
                              onClick: s['is_admin'] == true ? null : () => _editStaff(s),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  String _staffSub(Map<String, dynamic> s) {
    if (s['is_admin'] == true) return 'مدیر اصلی (دسترسی کامل)';
    final String role = (s['role'] ?? 'agent').toString();
    if (role == 'manager') return 'مدیر (همه گفتگوها)';
    final List<int> ids = (s['departments'] is List)
        ? List<int>.from((s['departments'] as List).map((e) => (e as num).toInt()))
        : const <int>[];
    if (ids.isEmpty) return 'کارمند · فقط گفتگوهای خودش';
    return 'کارمند · ${ids.map(_deptName).join('، ')}';
  }

  Widget _sectionTitle(BuildContext context, String t) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 2),
      child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.tx2)),
    );
  }
}

class _StaffEditSheet extends StatefulWidget {
  const _StaffEditSheet({required this.staff, required this.departments});
  final Map<String, dynamic> staff;
  final List<Map<String, dynamic>> departments;

  @override
  State<_StaffEditSheet> createState() => _StaffEditSheetState();
}

class _StaffEditSheetState extends State<_StaffEditSheet> {
  late String _role = (widget.staff['role'] ?? 'agent').toString() == 'manager' ? 'manager' : 'agent';
  late final Set<int> _picked = (widget.staff['departments'] is List)
      ? {...(widget.staff['departments'] as List).map((e) => (e as num).toInt())}
      : <int>{};
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final StoreResult r = await StoreApi.chatSetStaff(
      ((widget.staff['id'] ?? 0) as num).toInt(),
      _role,
      _role == 'agent' ? _picked.toList() : const <int>[],
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.ok) {
      Navigator.of(context).pop(true);
    } else {
      AppScope.of(context).showToast(r.error ?? 'ذخیره ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segmented(
          full: true,
          value: _role,
          onChange: (v) => setState(() => _role = v),
          options: const [
            (value: 'agent', label: 'کارمند (محدود)'),
            (value: 'manager', label: 'مدیر (کامل)'),
          ],
        ),
        if (_role == 'agent') ...[
          const SizedBox(height: 14),
          Text('دپارتمان‌های این کارمند:', style: TextStyle(fontSize: 12.5, color: c.tx2)),
          const SizedBox(height: 8),
          if (widget.departments.isEmpty)
            Text('ابتدا یک دپارتمان بسازید.', style: TextStyle(fontSize: 12, color: c.tx3))
          else
            for (final d in widget.departments) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  final int id = ((d['id'] ?? 0) as num).toInt();
                  if (_picked.contains(id)) {
                    _picked.remove(id);
                  } else {
                    _picked.add(id);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _picked.contains(((d['id'] ?? 0) as num).toInt()) ? c.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: _picked.contains(((d['id'] ?? 0) as num).toInt()) ? c.accent : c.tx3, width: 1.5),
                        ),
                        child: _picked.contains(((d['id'] ?? 0) as num).toInt())
                            ? const Icon(Icons.check, size: 13, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text((d['name'] ?? '').toString(), style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
        ],
        const SizedBox(height: 16),
        WcpButton(
          variant: 'primary',
          full: true,
          label: _saving ? 'در حال ذخیره…' : 'ذخیره',
          onClick: _save,
        ),
      ],
    );
  }
}
