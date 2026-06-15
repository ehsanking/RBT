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
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens.dart';
import '../core/icons.dart';
import '../core/fmt.dart';
import '../core/jalali.dart';
import '../core/native.dart';
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

// ── message timestamp — mirrors the tickets «who · time» footer ─────
// Parses the message `created_at` (MySQL datetime, e.g. '2026-06-15 23:39:55')
// and renders a compact Persian label: just the time today, else Jalali date.
// Uses the real clock (NOT the sample anchor) so live messages read correctly.
String _msgTime(Object? createdAt) {
  final String iso = (createdAt ?? '').toString().trim();
  if (iso.isEmpty) return '';
  final DateTime? dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final String hh = dt.hour.toString().padLeft(2, '0');
  final String mm = dt.minute.toString().padLeft(2, '0');
  final String time = '${Fmt.fa(hh)}:${Fmt.fa(mm)}';
  final DateTime now = DateTime.now();
  final bool sameDay =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  if (sameDay) return time;
  final List<int> j = Jalali.toJalali(dt.year, dt.month, dt.day);
  return '${Fmt.fa(j[2])} ${Jalali.months[j[1] - 1]} · $time';
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
  Timer? _poll; // direct-WP fallback cadence (8s) — used until/unless the beacon takes over.

  // ── ITEM13 near-real-time beacon (central /s/changes) ──────────────
  // Privacy: only the opaque subscribe-token + an integer version cross central;
  // all conversation bodies are still fetched from the merchant WP below.
  Timer? _beacon; // lightweight ~3s central poll that gates the WP fetch.
  String _central = '';
  String _subToken = '';
  int _lastVersion = -1; // last central version that triggered a WP fetch.
  int _beaconFails = 0; // consecutive beacon errors → fall back to direct-WP.

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      // Immediate first WP fetch so the first paint is real.
      _load();
      // Start on the direct-WP fallback cadence; the beacon disables it on success.
      _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
      _initBeacon();
    }
  }

  /// Fetch relay creds ONCE; if usable, start the central beacon (3s) and stop
  /// the direct-WP timer. On any failure the direct-WP timer stays running.
  Future<void> _initBeacon() async {
    final StoreResult r = await StoreApi.chatRelayCredentials();
    if (!mounted) return;
    final String central = (r.map['central_base'] ?? '').toString().trim();
    final String token = (r.map['subscribe_token'] ?? '').toString().trim();
    if (!r.ok || central.isEmpty || token.isEmpty) return; // keep direct-WP timer.
    _central = central;
    _subToken = token;
    // The beacon owns scheduling now — drop the fixed 8s WP timer.
    _poll?.cancel();
    _poll = null;
    _beacon = Timer.periodic(const Duration(seconds: 3), (_) => _tickBeacon());
  }

  Future<void> _tickBeacon() async {
    final ({bool ok, int version, bool changed}) c =
        await StoreApi.chatChanges(_central, _subToken);
    if (!mounted) return;
    if (!c.ok) {
      // Repeated failures → fall back to the direct-WP cadence (never break).
      if (++_beaconFails >= 3) {
        _beacon?.cancel();
        _beacon = null;
        _poll ??= Timer.periodic(
            const Duration(seconds: 8), (_) => _load(silent: true));
      }
      return;
    }
    _beaconFails = 0;
    // Only fetch bodies from WP when the version advanced (or first tick).
    if (_lastVersion < 0 || c.version > _lastVersion) {
      _lastVersion = c.version;
      _load(silent: true);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _beacon?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final StoreResult r = await StoreApi.chatConversations(status: 'all');
    if (!mounted) return;
    if (r.ok && r.map['available'] != false) {
      // The endpoint returns the list under `conversations` (NOT the `items`
      // envelope StoreResult.list expects), so read it explicitly.
      final List<Map<String, dynamic>> convs = (r.map['conversations'] is List)
          ? List<Map<String, dynamic>>.from((r.map['conversations'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e)))
          : const <Map<String, dynamic>>[];
      setState(() {
        _items = convs;
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
            child: RefreshIndicator(
              onRefresh: () => _load(),
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
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) => _row(context, list[i]),
                            ),
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
  Map<String, dynamic> _meta = const <String, dynamic>{};
  bool _blocked = false;
  bool _loading = StoreApi.hasStore;
  bool _sending = false;
  bool _internal = false;
  bool _uploading = false;
  int _lastId = 0;
  Timer? _poll; // direct-WP fallback cadence (4s) — used until/unless the beacon takes over.
  VoidCallback? _restoreFab;

  // ── ITEM13 near-real-time beacon (central /s/changes) ──────────────
  // Same content-blind relay as the inbox: only subscribe-token + version cross
  // central; message bodies are still fetched from the merchant WP via _load().
  Timer? _beacon;
  String _central = '';
  String _subToken = '';
  int _lastVersion = -1;
  int _beaconFails = 0;

  // Voice recording.
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  int _recSecs = 0;
  Timer? _recTimer;
  String? _recPath;

  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  // ── BATCH3 #5 canned replies (server-side chat settings) ──────────
  // Loaded once from StoreApi.chatConfig() -> settings.canned_replies and
  // cached locally; the quick-reply sheet inserts/edits them + saves back.
  List<Map<String, dynamic>> _canned = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    if (StoreApi.hasStore) {
      // Immediate first WP fetch so the first paint is real.
      _load();
      // Start on the direct-WP fallback cadence; the beacon disables it on success.
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
      _initBeacon();
      _loadCanned();
    }
  }

  /// Fetch the canned replies once from chat settings and cache them. Silent on
  /// failure — the quick-reply sheet just shows the empty state + add button.
  Future<void> _loadCanned() async {
    final StoreResult r = await StoreApi.chatConfig();
    if (!mounted || !r.ok) return;
    setState(() => _canned = _parseCanned(r.map));
  }

  /// Extract the canned-replies list from a chatConfig() response map. The list
  /// lives under settings.canned_replies as [{title,text}]; we normalize each
  /// entry to non-null strings and drop blanks.
  List<Map<String, dynamic>> _parseCanned(Map<String, dynamic> m) {
    final dynamic settings = m['settings'];
    final dynamic raw =
        (settings is Map) ? settings['canned_replies'] : m['canned_replies'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final dynamic e in raw) {
      if (e is! Map) continue;
      final String title = (e['title'] ?? '').toString().trim();
      final String text = (e['text'] ?? '').toString().trim();
      if (title.isEmpty && text.isEmpty) continue;
      out.add(<String, dynamic>{'title': title, 'text': text});
    }
    return out;
  }

  /// Fetch relay creds ONCE; if usable, start the central beacon (3s) and stop
  /// the direct-WP timer. On any failure the direct-WP timer stays running.
  Future<void> _initBeacon() async {
    final StoreResult r = await StoreApi.chatRelayCredentials();
    if (!mounted) return;
    final String central = (r.map['central_base'] ?? '').toString().trim();
    final String token = (r.map['subscribe_token'] ?? '').toString().trim();
    if (!r.ok || central.isEmpty || token.isEmpty) return; // keep direct-WP timer.
    _central = central;
    _subToken = token;
    _poll?.cancel();
    _poll = null;
    _beacon = Timer.periodic(const Duration(seconds: 3), (_) => _tickBeacon());
  }

  Future<void> _tickBeacon() async {
    final ({bool ok, int version, bool changed}) c =
        await StoreApi.chatChanges(_central, _subToken);
    if (!mounted) return;
    if (!c.ok) {
      if (++_beaconFails >= 3) {
        _beacon?.cancel();
        _beacon = null;
        _poll ??= Timer.periodic(
            const Duration(seconds: 4), (_) => _load(silent: true));
      }
      return;
    }
    _beaconFails = 0;
    if (_lastVersion < 0 || c.version > _lastVersion) {
      _lastVersion = c.version;
      _load(silent: true);
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
    _beacon?.cancel();
    _recTimer?.cancel();
    _recorder.dispose();
    _restoreFab?.call();
    _input.dispose();
    _inputFocus.dispose();
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
    final List<Map<String, dynamic>> fresh = (r.map['messages'] is List)
        ? List<Map<String, dynamic>>.from((r.map['messages'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)))
        : const <Map<String, dynamic>>[];
    setState(() {
      _status = (r.map['status'] ?? _status).toString();
      final String n = (r.map['customer_name'] ?? '').toString();
      if (n.isNotEmpty) _name = n;
      if (r.map['meta'] is Map) {
        _meta = Map<String, dynamic>.from(r.map['meta'] as Map);
      }
      if (r.map.containsKey('blocked')) {
        _blocked = ((r.map['blocked'] ?? 0) as num).toInt() == 1;
      }
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

  /// Append the message a send/upload returned (dedup by id) + scroll.
  void _appendReturned(StoreResult r) {
    if (r.map['message'] is Map) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(r.map['message'] as Map);
      final int mid = ((m['id'] ?? 0) as num).toInt();
      if (mid > _lastId) {
        _lastId = mid;
        setState(() => _msgs.add(m));
        _scrollToEnd();
      }
    }
  }

  Future<void> _pickAndSend() async {
    if (_uploading || _sending || _recording || !StoreApi.hasStore) return;
    final FilePickerResult? res = await FilePicker.platform
        .pickFiles(allowMultiple: true, type: FileType.any, withData: false);
    if (res == null || res.files.isEmpty || !mounted) return;
    final List<String> paths =
        res.files.map((f) => f.path).whereType<String>().toList();
    if (paths.isEmpty) return;
    final String caption = _input.text.trim();
    setState(() => _uploading = true);
    final StoreResult r = await StoreApi.chatUpload(widget.id,
        filePaths: paths, internal: _internal, caption: caption);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (r.ok) {
      _input.clear();
      _appendReturned(r);
    } else {
      AppScope.of(context)
          .showToast(r.error ?? 'بارگذاری ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  Future<void> _startRec() async {
    if (_uploading || _sending || _recording || !StoreApi.hasStore) return;
    final bool ok = await _recorder.hasPermission();
    if (!ok) {
      if (mounted) {
        AppScope.of(context)
            .showToast('دسترسی به میکروفون لازم است', kind: 'error', icon: 'alert');
      }
      return;
    }
    final Directory dir = await getTemporaryDirectory();
    final String path =
        '${dir.path}/wcp_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (!mounted) return;
    setState(() {
      _recording = true;
      _recSecs = 0;
      _recPath = path;
    });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recSecs++);
      if (_recSecs >= 600) _stopRec(true); // hard ceiling
    });
  }

  Future<void> _stopRec(bool send) async {
    _recTimer?.cancel();
    final int secs = _recSecs;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    path ??= _recPath;
    if (!mounted) return;
    setState(() => _recording = false);
    if (!send || path == null) {
      if (path != null) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
      return;
    }
    setState(() => _uploading = true);
    final StoreResult r = await StoreApi.chatUpload(widget.id,
        voicePath: path, voiceSeconds: secs, internal: _internal);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (r.ok) {
      _appendReturned(r);
    } else {
      AppScope.of(context)
          .showToast(r.error ?? 'ارسال ویس ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  Future<void> _deleteConversation() async {
    final AppScope nav = AppScope.of(context);
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: c.bg1,
            title: const Text('حذف گفتگو'),
            content: const Text(
                'این گفتگو و همه پیام‌ها و فایل‌هایش برای همیشه حذف می‌شوند. مطمئن هستید؟'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('انصراف')),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('حذف', style: TextStyle(color: Color(0xFFEF4444)))),
            ],
          ),
        );
      },
    );
    if (yes != true) return;
    final StoreResult r = await StoreApi.chatDeleteConversation(widget.id);
    if (!mounted) return;
    if (r.ok) {
      nav.showToast('گفتگو حذف شد', kind: 'success', icon: 'check');
      nav.pop();
    } else {
      nav.showToast(r.error ?? 'حذف ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  // ── Customer contact details from the conversation meta ──────────
  String _metaStr(List<String> keys) {
    for (final String k in keys) {
      final dynamic v = _meta[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  String get _custEmail => _metaStr(const ['email', 'customer_email']);
  String get _custPhone => _metaStr(const ['phone', 'customer_phone', 'tel']);
  String get _custDept => _metaStr(const ['department', 'department_name', 'dept']);

  bool get _hasContact =>
      _custEmail.isNotEmpty || _custPhone.isNotEmpty || _custDept.isNotEmpty;

  Future<void> _openOverflow() async {
    final String action = await showWcpSheet<String>(
          context,
          title: 'گزینه‌های گفتگو',
          child: _OverflowSheet(blocked: _blocked),
        ) ??
        '';
    if (!mounted) return;
    if (action == 'block') {
      _toggleBlock();
    } else if (action == 'delete') {
      _deleteConversation();
    } else if (action == 'dept') {
      _changeDepartment();
    }
  }

  /// Fetch departments, let the manager pick one, then assign the conversation
  /// to it via the API. The server injects a please-wait system message to the
  /// customer (#3c) — here we just reflect the new department locally.
  Future<void> _changeDepartment() async {
    final AppScope nav = AppScope.of(context);
    final StoreResult r = await StoreApi.chatDepartments();
    if (!mounted) return;
    final List<Map<String, dynamic>> depts = (r.map['departments'] is List)
        ? List<Map<String, dynamic>>.from((r.map['departments'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)))
        : const <Map<String, dynamic>>[];
    if (depts.isEmpty) {
      nav.showToast('دپارتمانی برای انتقال وجود ندارد', kind: 'info', icon: 'info');
      return;
    }
    final Map<String, dynamic>? picked = await showWcpSheet<Map<String, dynamic>>(
      context,
      title: 'تغییر دپارتمان',
      child: _DeptPickerSheet(departments: depts, currentName: _custDept),
    );
    if (picked == null || !mounted) return;
    final int id = ((picked['id'] ?? 0) as num).toInt();
    final String name = (picked['name'] ?? '').toString();
    if (id <= 0) return;
    final StoreResult a = await StoreApi.chatAssign(widget.id, departmentId: id);
    if (!mounted) return;
    if (a.ok) {
      // Reflect the new department locally so the header hint + contact sheet update.
      setState(() {
        final Map<String, dynamic> meta = Map<String, dynamic>.from(_meta);
        meta['department'] = name;
        meta['department_name'] = name;
        _meta = meta;
      });
      nav.showToast('گفتگو به «$name» منتقل شد', kind: 'success', icon: 'check');
    } else {
      nav.showToast(a.error ?? 'انتقال دپارتمان ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  void _openContactSheet() {
    showWcpSheet<void>(
      context,
      title: _name.isNotEmpty ? _name : 'مشتری',
      child: _ContactSheet(
        email: _custEmail,
        phone: _custPhone,
        department: _custDept,
      ),
    );
  }

  // ── BATCH3 #5 — canned replies sheet (insert / manage) ─────────────
  /// Open the quick-reply sheet. Tapping a reply inserts its text into the
  /// composer (focused, ready to send); a «مدیریت» mode lets the manager
  /// create/edit/delete replies, saved back to chat settings via chatSaveConfig.
  Future<void> _openCanned() async {
    final List<Map<String, dynamic>>? result =
        await showWcpSheet<List<Map<String, dynamic>>>(
      context,
      title: 'پاسخ‌های آماده',
      child: _CannedSheet(
        replies: _canned,
        onInsert: _insertCanned,
        onSave: _saveCanned,
      ),
    );
    // The sheet returns the updated list when a save happened so we cache it.
    if (result != null && mounted) setState(() => _canned = result);
  }

  /// Drop the chosen reply text into the composer and focus it, ready to send.
  void _insertCanned(String text) {
    final String t = text.trim();
    if (t.isEmpty) return;
    _input.text = t;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    setState(() {});
    _inputFocus.requestFocus();
  }

  /// Persist the canned-replies list to chat settings. Returns true on success.
  Future<bool> _saveCanned(List<Map<String, dynamic>> list) async {
    final StoreResult r =
        await StoreApi.chatSaveConfig(<String, dynamic>{'canned_replies': list});
    if (!mounted) return false;
    if (r.ok) {
      setState(() => _canned = _parseCanned(r.map).isNotEmpty
          ? _parseCanned(r.map)
          : List<Map<String, dynamic>>.from(list));
    } else {
      AppScope.of(context)
          .showToast(r.error ?? 'ذخیره پاسخ‌ها ناموفق بود', kind: 'error', icon: 'alert');
    }
    return r.ok;
  }

  Future<void> _toggleBlock() async {
    final AppScope nav = AppScope.of(context);
    final bool willBlock = !_blocked;
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: c.bg1,
            title: Text(willBlock ? 'مسدود کردن مشتری' : 'رفع مسدودی'),
            content: Text(willBlock
                ? 'با مسدود کردن، مشتری دیگر نمی‌تواند در این گفتگو پیام بفرستد. ادامه می‌دهید؟'
                : 'مسدودی این گفتگو برداشته شود تا مشتری دوباره بتواند پیام بفرستد؟'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('انصراف')),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(willBlock ? 'مسدود کردن' : 'رفع مسدودی',
                      style: TextStyle(
                          color: willBlock ? const Color(0xFFEF4444) : c.accent))),
            ],
          ),
        );
      },
    );
    if (yes != true) return;
    final StoreResult r = await StoreApi.chatBlockConversation(widget.id, willBlock);
    if (!mounted) return;
    if (r.ok) {
      setState(() => _blocked =
          r.map.containsKey('blocked') ? ((r.map['blocked'] ?? 0) as num).toInt() == 1 : willBlock);
      nav.showToast(_blocked ? 'مشتری مسدود شد' : 'مسدودی برداشته شد',
          kind: 'success', icon: 'check');
    } else {
      nav.showToast(r.error ?? 'تغییر وضعیت مسدودی ناموفق بود', kind: 'error', icon: 'alert');
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
            sub: _blocked ? 'مسدود · ${info.fa}' : info.fa,
            onBack: () => AppScope.of(context).pop(),
            actions: [
              if (_hasContact)
                Semantics(
                  label: 'اطلاعات تماس مشتری',
                  button: true,
                  child: IconBtn(name: 'info', onClick: _openContactSheet),
                ),
              Semantics(
                label: _status == 'closed' ? 'بازگشایی گفتگو' : 'بستن گفتگو',
                button: true,
                child: IconBtn(
                  name: _status == 'closed' ? 'refresh' : 'check',
                  onClick: () => _setStatus(_status == 'closed' ? 'open' : 'closed'),
                ),
              ),
              Semantics(
                label: 'گزینه‌های بیشتر',
                button: true,
                child: IconBtn(name: 'dots', onClick: _openOverflow),
              ),
            ],
          ),
          Expanded(
            child: _loading && _msgs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _load(),
                    child: ListView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
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
    final List<Map<String, dynamic>> atts = (m['attachments'] is List)
        ? List<Map<String, dynamic>>.from((m['attachments'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)))
        : const <Map<String, dynamic>>[];

    if (isSystem) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(999)),
          child: Text(body, style: TextStyle(fontSize: 11.5, color: c.tx3)),
        ),
      );
    }

    // Outside-the-bubble download controls — one small icon per downloadable
    // attachment, rendered as a SIBLING of the bubble in the message row (#1).
    // Tapping one fetches the gated bytes and opens the system save/share sheet
    // so the user picks the destination (#2). Voice + file + image alike.
    final List<Widget> dlBtns = <Widget>[
      for (final Map<String, dynamic> a in atts)
        _AttachmentDownloadBtn(
          messageId: ((a['mid'] ?? 0) as num).toInt(),
          index: ((a['i'] ?? 0) as num).toInt(),
          kind: (a['kind'] ?? 'file').toString(),
          name: (a['name'] ?? 'فایل').toString(),
          ext: (a['ext'] ?? '').toString(),
        ),
    ];
    final Widget? dlColumn = dlBtns.isEmpty
        ? null
        : Padding(
            padding: EdgeInsets.only(left: isStaff ? 6 : 0, right: isStaff ? 0 : 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int d = 0; d < dlBtns.length; d++) ...[
                  if (d > 0) const SizedBox(height: 6),
                  dlBtns[d],
                ],
              ],
            ),
          );

    return Row(
      textDirection: TextDirection.ltr,
      mainAxisAlignment: isStaff ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // staff bubble: download icon sits to the RIGHT of the bubble.
        if (isStaff && dlColumn != null) dlColumn,
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
                      if (body.isNotEmpty)
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: internal ? const Color(0xFFB45309) : (isStaff ? c.txOnAccent : c.tx1),
                          ),
                        ),
                      for (int k = 0; k < atts.length; k++)
                        Padding(
                          padding: EdgeInsets.only(top: (k == 0 && body.isEmpty) ? 0 : 6),
                          child: _attachment(context, atts[k], isStaff),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Builder(builder: (_) {
                  final String label =
                      isStaff ? (who.isNotEmpty ? who : 'شما') : (_name.isNotEmpty ? _name : 'مشتری');
                  final String time = _msgTime(m['created_at']);
                  return Text(
                    time.isEmpty ? label : '$label · $time',
                    textAlign: isStaff ? TextAlign.left : TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontSize: 10, color: c.tx3),
                  );
                }),
              ),
            ],
          ),
        ),
        // customer bubble: download icon sits to the LEFT of the bubble.
        if (!isStaff && dlColumn != null) dlColumn,
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
          if (_recording)
            _recordingBar(context)
          else
            Row(
            children: [
              _roundBtn(context, 'clip', (_uploading || _sending) ? null : _pickAndSend,
                  label: 'پیوست فایل'),
              const SizedBox(width: 6),
              _roundBtn(context, 'reply', (_uploading || _sending) ? null : _openCanned,
                  label: 'پاسخ‌های آماده'),
              const SizedBox(width: 6),
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
                    focusNode: _inputFocus,
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
              if (_input.text.trim().isNotEmpty)
                _sendBtn(context)
              else
                _roundBtn(context, 'mic', (_uploading || _sending) ? null : _startRec,
                    label: 'ضبط پیام صوتی'),
            ],
          ),
        ],
      ),
    );
  }

  /// A 46×46 neutral round icon button (attach / mic). [onTap] null = disabled.
  /// [label] is the accessibility/tooltip text for the icon-only control.
  Widget _roundBtn(BuildContext context, String icon, VoidCallback? onTap,
      {required String label}) {
    final c = context.c;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        enabled: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.bg1, shape: BoxShape.circle, border: Border.all(color: c.line, width: 1)),
            child: WcpIcon(icon, size: 20, color: onTap == null ? c.tx3 : c.tx2),
          ),
        ),
      ),
    );
  }

  /// The accent send button (spinner while sending/uploading).
  Widget _sendBtn(BuildContext context) {
    final c = context.c;
    final bool busy = _sending || _uploading;
    return Tooltip(
      message: 'ارسال پیام',
      child: Semantics(
        label: 'ارسال پیام',
        button: true,
        enabled: !busy,
        child: GestureDetector(
          onTap: busy ? null : _send,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: busy ? c.bg3 : c.accent, shape: BoxShape.circle),
            child: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : WcpIcon('send', size: 20, color: c.txOnAccent),
          ),
        ),
      ),
    );
  }

  /// The active voice-recording bar: cancel · blinking dot + timer · send.
  Widget _recordingBar(BuildContext context) {
    final c = context.c;
    String dur(int s) {
      final int m = s ~/ 60;
      final int r = s % 60;
      return Fmt.fa('$m:${r < 10 ? '0$r' : r}');
    }

    return Row(
      children: [
        Tooltip(
          message: 'لغو ضبط',
          child: Semantics(
            label: 'لغو ضبط',
            button: true,
            child: GestureDetector(
              onTap: () => _stopRec(false),
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.bg1, shape: BoxShape.circle, border: Border.all(color: c.line, width: 1)),
                child: const WcpIcon('trash', size: 20, color: Color(0xFFEF4444)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text('در حال ضبط…  ${dur(_recSecs)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.tx1)),
        ),
        Tooltip(
          message: 'ارسال پیام صوتی',
          child: Semantics(
            label: 'ارسال پیام صوتی',
            button: true,
            enabled: !_uploading,
            child: GestureDetector(
              onTap: _uploading ? null : () => _stopRec(true),
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _uploading ? c.bg3 : c.accent, shape: BoxShape.circle),
                child: _uploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : WcpIcon('send', size: 20, color: c.txOnAccent),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Render one attachment descriptor {kind,name,size,ext,dur,mid,i}.
  Widget _attachment(BuildContext context, Map<String, dynamic> a, bool isStaff) {
    final int mid = ((a['mid'] ?? 0) as num).toInt();
    final int idx = ((a['i'] ?? 0) as num).toInt();
    final String kind = (a['kind'] ?? 'file').toString();
    final String name = (a['name'] ?? 'فایل').toString();
    final int size = ((a['size'] ?? 0) as num).toInt();
    final int durSec = ((a['dur'] ?? 0) as num).toInt();
    final String ext = (a['ext'] ?? '').toString();
    if (kind == 'image') {
      // Smaller thumbnail (#3): max ~190×200, cover-cropped, rounded; tapping it
      // opens the image full-size in a dialog. The save control lives OUTSIDE the
      // bubble (#1) so there is no in-bubble download button here.
      // Align gives the child LOOSE constraints so the 190-wide cap actually
      // applies — the bubble Column is crossAxisAlignment.stretch (tight width),
      // which would otherwise override the ConstrainedBox and stretch the image.
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: GestureDetector(
          onTap: () => _openImageViewer(context, mid, idx),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 190),
              child: Image.network(
              StoreApi.chatAttachmentUrl(mid, idx),
              headers: StoreApi.mediaAuthHeaders,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _FileChip(
                  messageId: mid, index: idx, name: name, size: size, ext: ext, onAccent: isStaff, icon: 'image'),
              loadingBuilder: (ctx, child, p) => p == null
                  ? child
                  : Container(
                      width: 160,
                      height: 120,
                      alignment: Alignment.center,
                      child: const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            ),
          ),
        ),
      );
    }
    if (kind == 'voice') {
      return _VoiceBubble(messageId: mid, index: idx, seconds: durSec, onAccent: isStaff);
    }
    return _FileChip(
        messageId: mid, index: idx, name: name, size: size, ext: ext, onAccent: isStaff, icon: 'file');
  }

  /// Open an image attachment full-size in a tap-to-dismiss dialog (#3). Uses the
  /// same gated URL + auth headers as the thumbnail; pinch/scroll-free, just a
  /// big preview the staff can read.
  void _openImageViewer(BuildContext context, int mid, int idx) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(0xE0),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.network(
              StoreApi.chatAttachmentUrl(mid, idx),
              headers: StoreApi.mediaAuthHeaders,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
              loadingBuilder: (c2, child, p) => p == null
                  ? child
                  : const SizedBox(
                      width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        ),
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

// ── Voice attachment player (fetches gated bytes with auth, plays via audioplayers) ──
class _VoiceBubble extends StatefulWidget {
  const _VoiceBubble({
    required this.messageId,
    required this.index,
    required this.seconds,
    required this.onAccent,
  });
  final int messageId;
  final int index;
  final int seconds;
  final bool onAccent;
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;
  bool _loading = false;
  bool _playing = false;
  // BytesSource produced no sound on Android; instead the gated bytes are
  // written to a temp file once and replayed from disk via DeviceFileSource.
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _sub = _player.onPlayerStateChanged.listen((PlayerState s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    // Only remove the cached file on dispose (never mid-play).
    final String? p = _localPath;
    if (p != null) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    try {
      if (_localPath == null) {
        setState(() => _loading = true);
        final Uint8List? b =
            await StoreApi.chatAttachmentBytes(widget.messageId, widget.index);
        if (!mounted) return;
        if (b == null) {
          setState(() => _loading = false);
          AppScope.of(context)
              .showToast('پخش ویس ناموفق بود', kind: 'error', icon: 'alert');
          return;
        }
        final Directory dir = await getTemporaryDirectory();
        final String path =
            '${dir.path}/wcp_play_${widget.messageId}_${widget.index}.m4a';
        await File(path).writeAsBytes(b, flush: true);
        if (!mounted) return;
        setState(() => _loading = false);
        _localPath = path;
      }
      await _player.play(DeviceFileSource(_localPath!));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppScope.of(context)
          .showToast('پخش ویس ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  String _fmtDur(int s) {
    final int m = s ~/ 60;
    final int r = s % 60;
    return Fmt.fa('$m:${r < 10 ? '0$r' : r}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Color fg = widget.onAccent ? c.txOnAccent : c.tx1;
    return GestureDetector(
      onTap: _loading ? null : _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: widget.onAccent ? Colors.white.withAlpha(0x24) : c.bg3,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                : WcpIcon(_playing ? 'pause' : 'play', size: 18, color: fg),
            const SizedBox(width: 8),
            WcpIcon('mic', size: 13, color: fg.withAlpha(0xAA)),
            const SizedBox(width: 4),
            Text(_fmtDur(widget.seconds), style: TextStyle(fontSize: 12, color: fg)),
          ],
        ),
      ),
    );
  }
}

// ── File attachment chip — tap to download (gated bytes) + open natively ──
class _FileChip extends StatefulWidget {
  const _FileChip({
    required this.messageId,
    required this.index,
    required this.name,
    required this.size,
    required this.ext,
    required this.onAccent,
    required this.icon,
  });
  final int messageId;
  final int index;
  final String name;
  final int size;
  final String ext;
  final bool onAccent;
  final String icon;
  @override
  State<_FileChip> createState() => _FileChipState();
}

class _FileChipState extends State<_FileChip> {
  bool _busy = false;

  String _humanSize(int b) {
    if (b >= 1048576) return '${Fmt.fa((b / 1048576).toStringAsFixed(1))} مگابایت';
    if (b >= 1024) return '${Fmt.fa((b / 1024).round())} کیلوبایت';
    return '${Fmt.fa(b)} بایت';
  }

  /// Build a safe local filename: strip path separators, keep the extension
  /// (from the name, else fall back to the descriptor's `ext`).
  String _safeName() {
    String n = widget.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (n.isEmpty) n = 'file';
    if (!n.contains('.') && widget.ext.isNotEmpty) {
      n = '$n.${widget.ext.replaceAll('.', '')}';
    }
    return n;
  }

  /// Best-effort MIME from the file extension (the system viewer is forgiving).
  String _mimeFor(String ext) => _chatMimeForExt(ext);

  Future<void> _open() async {
    if (_busy) return;
    final AppScope nav = AppScope.of(context);
    setState(() => _busy = true);
    try {
      final Uint8List? b =
          await StoreApi.chatAttachmentBytes(widget.messageId, widget.index);
      if (!mounted) return;
      if (b == null) {
        setState(() => _busy = false);
        nav.showToast('دریافت فایل ناموفق بود', kind: 'error', icon: 'alert');
        return;
      }
      final String fname = _safeName();
      final Directory dir = await getTemporaryDirectory();
      final String path = '${dir.path}/$fname';
      await File(path).writeAsBytes(b, flush: true);
      if (!mounted) return;
      setState(() => _busy = false);
      final String ext =
          fname.contains('.') ? fname.split('.').last : widget.ext;
      final bool opened = await Native.openFile(path, mime: _mimeFor(ext));
      if (!mounted) return;
      if (!opened) {
        nav.showToast('فایل ذخیره شد: $path', kind: 'info', icon: 'check');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      nav.showToast('باز کردن فایل ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Color fg = widget.onAccent ? c.txOnAccent : c.tx1;
    return GestureDetector(
      onTap: _busy ? null : _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: widget.onAccent ? Colors.white.withAlpha(0x24) : c.bg3,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                : WcpIcon(widget.icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
                  if (widget.size > 0)
                    Text(_humanSize(widget.size),
                        style: TextStyle(fontSize: 10.5, color: fg.withAlpha(0xAA))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Best-effort MIME from a file extension (the system viewer/share sheet is
/// forgiving). Shared by the file chip's open action + the outside-the-bubble
/// download control.
String _chatMimeForExt(String ext) {
  switch (ext.toLowerCase().replaceAll('.', '')) {
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'zip':
      return 'application/zip';
    case 'rar':
      return 'application/vnd.rar';
    case 'txt':
      return 'text/plain';
    case 'csv':
      return 'text/csv';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    case 'mp4':
      return 'video/mp4';
    default:
      return 'application/octet-stream';
  }
}

/// Outside-the-bubble download control (#1) — a small icon rendered BESIDE the
/// bubble in the message row (not inside it). Tapping it fetches the gated
/// attachment bytes, writes a temp file, then hands it to the system save/share
/// sheet via Native.shareFile so the user picks the destination — Files / Drive
/// / anywhere (#2). Works for file, voice AND image attachments. Toast only on
/// failure. Holds its own busy state so multiple icons act independently.
class _AttachmentDownloadBtn extends StatefulWidget {
  const _AttachmentDownloadBtn({
    required this.messageId,
    required this.index,
    required this.kind,
    required this.name,
    required this.ext,
  });
  final int messageId;
  final int index;
  final String kind;
  final String name;
  final String ext;

  @override
  State<_AttachmentDownloadBtn> createState() => _AttachmentDownloadBtnState();
}

class _AttachmentDownloadBtnState extends State<_AttachmentDownloadBtn> {
  bool _busy = false;

  /// A safe, extensioned local filename for the saved temp file.
  String _safeName() {
    if (widget.kind == 'voice') {
      return 'voice_${widget.messageId}_${widget.index}.m4a';
    }
    String n = widget.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (n.isEmpty) n = 'file_${widget.messageId}_${widget.index}';
    if (!n.contains('.') && widget.ext.isNotEmpty) {
      n = '$n.${widget.ext.replaceAll('.', '')}';
    }
    if (widget.kind == 'image' && !n.contains('.')) n = '$n.jpg';
    return n;
  }

  String _mime() {
    if (widget.kind == 'voice') return 'audio/mp4';
    final String fname = _safeName();
    final String ext = fname.contains('.') ? fname.split('.').last : widget.ext;
    return _chatMimeForExt(ext);
  }

  Future<void> _save() async {
    if (_busy) return;
    final AppScope nav = AppScope.of(context);
    setState(() => _busy = true);
    try {
      final Uint8List? b =
          await StoreApi.chatAttachmentBytes(widget.messageId, widget.index);
      if (!mounted) return;
      if (b == null) {
        setState(() => _busy = false);
        nav.showToast('دریافت فایل ناموفق بود', kind: 'error', icon: 'alert');
        return;
      }
      final String fname = _safeName();
      final Directory dir = await getTemporaryDirectory();
      final String path = '${dir.path}/$fname';
      await File(path).writeAsBytes(b, flush: true);
      if (!mounted) return;
      final bool shared = await Native.shareFile(path, mime: _mime());
      if (!mounted) return;
      setState(() => _busy = false);
      if (!shared) {
        nav.showToast('ذخیره فایل ناموفق بود', kind: 'error', icon: 'alert');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      nav.showToast('ذخیره فایل ناموفق بود', kind: 'error', icon: 'alert');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: 'ذخیره فایل',
      child: Semantics(
        label: 'ذخیره فایل',
        button: true,
        enabled: !_busy,
        child: GestureDetector(
          onTap: _busy ? null : _save,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.bg2,
              shape: BoxShape.circle,
              border: Border.all(color: c.line, width: 1),
            ),
            child: _busy
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.tx2))
                : WcpIcon('download', size: 16, color: c.tx2),
          ),
        ),
      ),
    );
  }
}

// ── Customer contact sheet — email/phone/department, tap-to-call + copy ──
class _ContactSheet extends StatelessWidget {
  const _ContactSheet({required this.email, required this.phone, required this.department});
  final String email;
  final String phone;
  final String department;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phone.isNotEmpty)
          _row(context, icon: 'phone', label: 'تلفن', value: phone, dial: 'tel:$phone'),
        if (email.isNotEmpty)
          _row(context, icon: 'email', label: 'ایمیل', value: email, dial: 'mailto:$email'),
        if (department.isNotEmpty)
          _row(context, icon: 'layers', label: 'دپارتمان', value: department),
        const SizedBox(height: 6),
        Text('برای تماس روی شماره، و برای کپی روی نماد کنار هر مورد بزنید.',
            style: TextStyle(fontSize: 11, color: c.tx3)),
      ],
    );
  }

  Widget _row(BuildContext context,
      {required String icon, required String label, required String value, String? dial}) {
    final c = context.c;
    final AppScope nav = AppScope.of(context);
    Future<void> doDial() async {
      if (dial == null) return;
      try {
        await launchUrl(Uri.parse(dial), mode: LaunchMode.externalApplication);
      } catch (_) {
        nav.showToast('امکان برقراری تماس نبود', kind: 'error', icon: 'alert');
      }
    }

    Future<void> doCopy() async {
      await Clipboard.setData(ClipboardData(text: value));
      nav.showToast('کپی شد', kind: 'success', icon: 'check');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(10)),
            child: WcpIcon(icon, size: 18, color: c.tx2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dial != null ? doDial : doCopy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: c.tx3)),
                  const SizedBox(height: 2),
                  Text(label == 'تلفن' ? Fmt.fa(value) : value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.tx1)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'کپی $label',
            button: true,
            child: IconBtn(name: 'clip', onClick: doCopy),
          ),
        ],
      ),
    );
  }
}

// ── Conversation overflow actions — block/unblock + delete ──────────
class _OverflowSheet extends StatelessWidget {
  const _OverflowSheet({required this.blocked});
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WcpButton(
          variant: 'soft',
          full: true,
          icon: 'layers',
          label: 'تغییر دپارتمان',
          onClick: () => Navigator.of(context).pop('dept'),
        ),
        const SizedBox(height: 10),
        WcpButton(
          variant: 'soft',
          full: true,
          icon: 'shield',
          label: blocked ? 'رفع مسدودی' : 'مسدود کردن مشتری',
          onClick: () => Navigator.of(context).pop('block'),
        ),
        const SizedBox(height: 10),
        WcpButton(
          variant: 'ghost',
          full: true,
          icon: 'trash',
          label: 'حذف گفتگو',
          onClick: () => Navigator.of(context).pop('delete'),
        ),
      ],
    );
  }
}

// ── Department picker sheet — lists departments, returns the chosen id ──
class _DeptPickerSheet extends StatelessWidget {
  const _DeptPickerSheet({required this.departments, required this.currentName});
  final List<Map<String, dynamic>> departments;
  final String currentName;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (departments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text('هنوز دپارتمانی ساخته نشده است.',
            style: TextStyle(fontSize: 13, color: c.tx3)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in departments)
          Builder(builder: (_) {
            final int id = ((d['id'] ?? 0) as num).toInt();
            final String name = (d['name'] ?? '').toString();
            final bool active =
                currentName.isNotEmpty && name == currentName;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(<String, dynamic>{'id': id, 'name': name}),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: c.bg2, borderRadius: BorderRadius.circular(10)),
                      child: WcpIcon('layers', size: 17, color: c.tx2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.tx1)),
                    ),
                    if (active) WcpIcon('check', size: 18, color: c.accent),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ── BATCH3 #5 — canned-replies sheet (insert + manage CRUD) ──────────
// Two modes: a LIST that inserts a reply into the composer (via onInsert) and a
// per-row edit/delete + «پاسخ جدید»; and an EDIT form (title + text). All
// mutations persist via onSave (chatSaveConfig) and reflect after the round-trip.
class _CannedSheet extends StatefulWidget {
  const _CannedSheet({
    required this.replies,
    required this.onInsert,
    required this.onSave,
  });
  final List<Map<String, dynamic>> replies;
  final void Function(String text) onInsert;
  final Future<bool> Function(List<Map<String, dynamic>> list) onSave;

  @override
  State<_CannedSheet> createState() => _CannedSheetState();
}

class _CannedSheetState extends State<_CannedSheet> {
  late List<Map<String, dynamic>> _list = <Map<String, dynamic>>[
    for (final Map<String, dynamic> e in widget.replies)
      <String, dynamic>{
        'title': (e['title'] ?? '').toString(),
        'text': (e['text'] ?? '').toString(),
      },
  ];

  // Edit-mode state. _editIndex == -1 means «add new»; null means list mode.
  int? _editIndex;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _text = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  void _startAdd() {
    _title.text = '';
    _text.text = '';
    setState(() => _editIndex = -1);
  }

  void _startEdit(int i) {
    _title.text = (_list[i]['title'] ?? '').toString();
    _text.text = (_list[i]['text'] ?? '').toString();
    setState(() => _editIndex = i);
  }

  Future<void> _commitEdit() async {
    if (_saving) return;
    final String title = _title.text.trim();
    final String text = _text.text.trim();
    if (text.isEmpty) {
      AppScope.of(context)
          .showToast('متن پاسخ نمی‌تواند خالی باشد', kind: 'error', icon: 'alert');
      return;
    }
    final Map<String, dynamic> entry = <String, dynamic>{
      'title': title.isEmpty ? text : title,
      'text': text,
    };
    final List<Map<String, dynamic>> next =
        List<Map<String, dynamic>>.from(_list);
    if (_editIndex == -1 || _editIndex == null) {
      next.add(entry);
    } else {
      next[_editIndex!] = entry;
    }
    setState(() => _saving = true);
    final bool ok = await widget.onSave(next);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _list = next;
        _editIndex = null;
      }
    });
  }

  Future<void> _delete(int i) async {
    if (_saving) return;
    final List<Map<String, dynamic>> next =
        List<Map<String, dynamic>>.from(_list)..removeAt(i);
    setState(() => _saving = true);
    final bool ok = await widget.onSave(next);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _list = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_editIndex != null) return _editForm(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text('هنوز پاسخ آماده‌ای ندارید.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.tx3)),
          )
        else
          for (int i = 0; i < _list.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.onInsert((_list[i]['text'] ?? '').toString());
                  Navigator.of(context).pop(_list);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.bg1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.line, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text((_list[i]['title'] ?? '').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.tx1)),
                            const SizedBox(height: 2),
                            Text((_list[i]['text'] ?? '').toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: c.tx3)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Semantics(
                        label: 'ویرایش پاسخ',
                        button: true,
                        child: IconBtn(name: 'edit', size: 16, onClick: () => _startEdit(i)),
                      ),
                      const SizedBox(width: 6),
                      Semantics(
                        label: 'حذف پاسخ',
                        button: true,
                        child: IconBtn(name: 'trash', size: 16, onClick: () => _delete(i)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(height: 4),
        WcpButton(
          variant: 'soft',
          full: true,
          icon: 'plus',
          label: 'پاسخ جدید',
          onClick: _startAdd,
        ),
        if (_list.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('برای درج، روی هر پاسخ بزنید.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: c.tx3)),
        ],
      ],
    );
  }

  Widget _editForm(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_editIndex == -1 ? 'پاسخ جدید' : 'ویرایش پاسخ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.tx2)),
        const SizedBox(height: 12),
        _field(context, controller: _title, hint: 'عنوان (اختیاری)', maxLines: 1),
        const SizedBox(height: 10),
        _field(context, controller: _text, hint: 'متن پاسخ', maxLines: 4),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: WcpButton(
                variant: 'secondary',
                full: true,
                label: 'انصراف',
                onClick: _saving ? null : () => setState(() => _editIndex = null),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: WcpButton(
                variant: 'primary',
                full: true,
                label: _saving ? 'در حال ذخیره…' : 'ذخیره',
                onClick: _saving ? null : _commitEdit,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(BuildContext context,
      {required TextEditingController controller,
      required String hint,
      required int maxLines}) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line, width: 1),
      ),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: maxLines,
        cursorColor: c.accent,
        style: TextStyle(fontFamily: T.family, fontSize: 14, color: c.tx1),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          hintText: hint,
          hintStyle: TextStyle(fontFamily: T.family, fontSize: 14, color: c.tx3),
        ),
      ),
    );
  }
}
