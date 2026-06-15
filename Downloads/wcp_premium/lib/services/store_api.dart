// ════════════════════════════════════════════════════════════════
// store_api.dart — client for the MERCHANT'S OWN WC+ store.
//
// Distinct from portal_api.dart (which talks to the central panel for the
// app SUBSCRIPTION). This connects to the user's WordPress/WooCommerce site
// to actually MANAGE it: orders, products, customers (standard WooCommerce
// REST `wc/v3`) and the WC+ extras (`woocommerce-plus/v1` — dashboard
// analytics, tickets, Q&A, blocklist).
//
// AUTH: WooCommerce REST consumer key/secret over HTTPS via HTTP Basic
// (base64(ck:cs) in the Authorization header) — never in the query string,
// so credentials don't leak into logs/proxies. Credentials are stored in
// shared_preferences after a successful connection test.
//
// Everything is best-effort: transport failures resolve to
// StoreResult(ok:false, error:<Persian message>) so the UI can show a
// graceful state instead of throwing.
// ════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Uniform result. [data] is the decoded JSON (a List for collection
/// endpoints, a Map for single resources). [total] mirrors wc/v3's
/// `X-WP-Total` header for paginated lists.
class StoreResult {
  final bool ok;
  final dynamic data;
  final String? error;
  final int statusCode;
  final int total;
  const StoreResult({
    required this.ok,
    this.data,
    this.error,
    this.statusCode = 0,
    this.total = 0,
  });

  /// The list payload of a response. Handles BOTH shapes the API uses:
  ///   • a bare top-level JSON array (wc/v3 list endpoints), and
  ///   • a `{ok, total, items:[…]}` envelope (the WC+ `/app/*` endpoints —
  ///     tickets / qa / notifications / slider / …).
  /// Anything else yields an empty list.
  List<Map<String, dynamic>> get list {
    final dynamic src = data is List
        ? data
        : (data is Map && (data as Map)['items'] is List)
            ? (data as Map)['items']
            : null;
    if (src is List) {
      return List<Map<String, dynamic>>.from(
          src.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> get map =>
      data is Map ? Map<String, dynamic>.from(data as Map) : const <String, dynamic>{};
}

class StoreApi {
  StoreApi._();

  static const String _kUrl = 'store_url';
  static const String _kCk = 'store_ck';
  static const String _kCs = 'store_cs';
  // Multi-store: the full list of connected stores (Instagram-style switch).
  // Each entry: {url, ck, cs, name}. The active one mirrors _kUrl/_kCk/_kCs.
  static const String _kStores = 'store_list';
  static List<Map<String, dynamic>> _stores = <Map<String, dynamic>>[];

  /// All connected stores. Read by the «فروشگاه‌های من» switcher.
  static List<Map<String, dynamic>> get stores =>
      List<Map<String, dynamic>>.unmodifiable(_stores);

  /// Bumped on every store switch so the shell subtree rebuilds and every
  /// screen re-fetches against the newly-active store (no logout needed).
  static final ValueNotifier<int> storeEpoch = ValueNotifier<int>(0);
  static const Duration _timeout = Duration(seconds: 25);

  static String? _siteUrl; // normalized, no trailing slash
  static String? _ck;
  static String? _cs;

  static bool get hasStore =>
      (_siteUrl?.isNotEmpty ?? false) &&
      (_ck?.isNotEmpty ?? false) &&
      (_cs?.isNotEmpty ?? false);

  static String? get siteUrl => _siteUrl;

  static String? _storeName;
  static String? _storeLogo;

  /// The connected store's display name (WordPress site title, from the REST
  /// root). Null until [fetchStoreInfo] resolves; callers fall back to a
  /// placeholder. The bare host of [siteUrl] makes a good domain label.
  static String? get storeName => _storeName;

  /// The store's logo/site-icon URL (from the WP REST root `site_icon_url`),
  /// or null/empty when the merchant hasn't set one — callers then fall back
  /// to the initials avatar. Shown next to the store name.
  static String? get storeLogo =>
      (_storeLogo != null && _storeLogo!.isNotEmpty) ? _storeLogo : null;

  /// Host portion of [siteUrl] (no scheme / trailing slash), or null.
  static String? get siteHost =>
      _siteUrl?.replaceFirst(RegExp(r'^https?://'), '').replaceAll('/', '');

  /// Load saved store credentials. Call once in main() before runApp.
  static Future<void> init() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      _siteUrl = p.getString(_kUrl);
      _ck = p.getString(_kCk);
      _cs = p.getString(_kCs);

      // Multi-store list.
      _stores = _decodeStores(p.getString(_kStores));
      // Migrate a pre-multi-store single connection into the list.
      if (_stores.isEmpty && hasStore) {
        _stores = <Map<String, dynamic>>[
          {'url': _siteUrl, 'ck': _ck, 'cs': _cs, 'name': ''},
        ];
        await _persistStores();
      }
    } catch (_) {
      _siteUrl = _ck = _cs = null;
      _stores = <Map<String, dynamic>>[];
    }
  }

  static List<Map<String, dynamic>> _decodeStores(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final dynamic d = jsonDecode(raw);
      if (d is List) {
        return d
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => (e['url'] ?? '').toString().isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  static Future<void> _persistStores() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setString(_kStores, jsonEncode(_stores));
    } catch (_) {/* in-memory list still works this session */}
  }

  /// Insert or update a store in the list (keyed by normalized url).
  static void _upsertStore(String url, String ck, String cs, {String name = ''}) {
    final int i = _stores.indexWhere((e) => (e['url'] ?? '') == url);
    if (i >= 0) {
      _stores[i]['ck'] = ck;
      _stores[i]['cs'] = cs;
      if (name.isNotEmpty) _stores[i]['name'] = name;
    } else {
      _stores.add({'url': url, 'ck': ck, 'cs': cs, 'name': name});
    }
  }

  /// Switch the ACTIVE store to [url] (must already be in the list). Persists
  /// the new active creds, clears the cached name/logo, and bumps [storeEpoch]
  /// so the whole shell rebuilds against the new store. Instagram-style — no
  /// logout. Returns false when [url] isn't a known store.
  static Future<bool> switchTo(String url) async {
    final int i = _stores.indexWhere((e) => (e['url'] ?? '') == url);
    if (i < 0) return false;
    _siteUrl = (_stores[i]['url'] ?? '').toString();
    _ck = (_stores[i]['ck'] ?? '').toString();
    _cs = (_stores[i]['cs'] ?? '').toString();
    _storeName = null;
    _storeLogo = null;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setString(_kUrl, _siteUrl!);
      await p.setString(_kCk, _ck!);
      await p.setString(_kCs, _cs!);
    } catch (_) {}
    storeEpoch.value++;
    return true;
  }

  /// Remove a store from the list. If it was the active one, switch to the
  /// first remaining store (or fully disconnect when none remain).
  static Future<bool> removeStore(String url) async {
    final bool wasActive = url == _siteUrl;
    _stores.removeWhere((e) => (e['url'] ?? '') == url);
    await _persistStores();
    if (wasActive) {
      if (_stores.isNotEmpty) {
        await switchTo((_stores.first['url'] ?? '').toString());
      } else {
        await disconnect();
        storeEpoch.value++;
      }
    }
    return true;
  }

  /// Normalize a user-typed site URL → https, no trailing slash, no path.
  static String normalizeUrl(String raw) {
    String s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://$s';
    }
    s = s.replaceAll(RegExp(r'/+$'), ''); // strip trailing slashes
    return s;
  }

  // ── connection ─────────────────────────────────────────────────
  /// Verify the URL + keys against the live store, and (on success) persist
  /// them. A lightweight `products?per_page=1` call proves both that the
  /// site is reachable AND that WooCommerce + the keys are valid.
  static Future<StoreResult> connect({
    required String url,
    required String ck,
    required String cs,
  }) async {
    final String u = normalizeUrl(url);
    if (u.isEmpty || ck.trim().isEmpty || cs.trim().isEmpty) {
      return const StoreResult(ok: false, error: 'آدرس و کلیدها را کامل وارد کنید.');
    }

    final StoreResult probe = await _request(
      'GET',
      '$u/wp-json/wc/v3/products',
      query: <String, String>{'per_page': '1', '_fields': 'id'},
      ck: ck,
      cs: cs,
    );

    if (!probe.ok) {
      final String msg = probe.statusCode == 401
          ? 'کلیدها نامعتبرند یا دسترسی ندارند.'
          : (probe.statusCode == 404
              ? 'ووکامرس روی این آدرس پیدا نشد.'
              : (probe.error ?? 'اتصال ناموفق بود.'));
      return StoreResult(ok: false, error: msg, statusCode: probe.statusCode);
    }

    _siteUrl = u;
    _ck = ck.trim();
    _cs = cs.trim();
    _storeName = null;
    _storeLogo = null;
    // Add/update this store in the multi-store list + make it the active one.
    _upsertStore(u, _ck!, _cs!);
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setString(_kUrl, _siteUrl!);
      await p.setString(_kCk, _ck!);
      await p.setString(_kCs, _cs!);
      await p.setString(_kStores, jsonEncode(_stores));
    } catch (_) {/* in-memory creds still work this session */}

    return const StoreResult(ok: true);
  }

  /// Decode a `WPP1:<base64url(JSON{url,ck,cs,name})>` pairing code emitted by
  /// the WC+ «اتصال اپ» admin page. Returns null when the string isn't valid.
  static Map<String, String>? parseConnectionCode(String raw) {
    String s = raw.trim();
    final int i = s.indexOf('WPP1:');
    if (i >= 0) s = s.substring(i + 5);
    s = s.trim();
    if (s.isEmpty) return null;
    try {
      final String norm = s.replaceAll('-', '+').replaceAll('_', '/');
      final int pad = (4 - norm.length % 4) % 4;
      final String json = utf8.decode(base64.decode(norm + ('=' * pad)));
      final dynamic m = jsonDecode(json);
      if (m is! Map) return null;
      final String url = (m['url'] ?? '').toString();
      final String ck = (m['ck'] ?? '').toString();
      final String cs = (m['cs'] ?? '').toString();
      if (url.isEmpty || ck.isEmpty || cs.isEmpty) return null;
      return <String, String>{'url': url, 'ck': ck, 'cs': cs, 'name': (m['name'] ?? '').toString()};
    } catch (_) {
      return null;
    }
  }

  /// Connect using a scanned/pasted `WPP1:` pairing code.
  static Future<StoreResult> connectFromCode(String code) async {
    final Map<String, String>? d = parseConnectionCode(code);
    if (d == null) {
      return const StoreResult(ok: false, error: 'کد اتصال نامعتبر است.');
    }
    return connect(url: d['url']!, ck: d['ck']!, cs: d['cs']!);
  }

  /// Full logout — clears the active store AND the whole multi-store list.
  static Future<void> disconnect() async {
    _siteUrl = _ck = _cs = null;
    _storeName = null;
    _storeLogo = null;
    _stores = <Map<String, dynamic>>[];
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.remove(_kUrl);
      await p.remove(_kCk);
      await p.remove(_kCs);
      await p.remove(_kStores);
    } catch (_) {}
  }

  // ── WooCommerce wc/v3 ──────────────────────────────────────────
  static Future<StoreResult> wcGet(String path, {Map<String, String>? query}) =>
      _request('GET', _wc(path), query: query);

  static Future<StoreResult> wcPost(String path, Map<String, dynamic> body) =>
      _request('POST', _wc(path), body: body);

  static Future<StoreResult> wcPut(String path, Map<String, dynamic> body) =>
      _request('PUT', _wc(path), body: body);

  static Future<StoreResult> wcDelete(String path, {Map<String, String>? query}) =>
      _request('DELETE', _wc(path), query: query);

  // ── WC+ woocommerce-plus/v1 (dashboard / tickets / qa / blocklist) ──
  static Future<StoreResult> wcpGet(String path, {Map<String, String>? query}) =>
      _request('GET', _wcp(path), query: query);

  static Future<StoreResult> wcpPost(String path, Map<String, dynamic> body) =>
      _request('POST', _wcp(path), body: body);

  /// Extended dashboard analytics (heatmap / category share / device split /
  /// store health) from the WC+ BI endpoint. [range] ∈ today|week|month|year.
  static Future<StoreResult> dashboardExtras(String range) =>
      wcpGet('/analytics/dashboard', query: <String, String>{'range': range});

  // ── WC+ mobile-admin endpoints (woocommerce-plus/v1/app/*) ──────
  static Future<StoreResult> appPing() => wcpGet('/app/ping');
  static Future<StoreResult> appOverview() => wcpGet('/app/overview');

  /// In-app notification feed for the «اعلان‌ها» screen — REAL store
  /// events (recent orders / low-stock / open tickets / pending Q&A).
  /// Iran-safe: no push infra, the app fetches this on open. Returns
  /// `{ok, items:[{id,cat,icon,color,title,body,time,ts,unread,route,
  /// params}], total}`.
  static Future<StoreResult> appNotifications() => wcpGet('/app/notifications');

  /// Merchant-controlled promo carousel for the «بیشتر» tab (managed in
  /// WP-admin → اتصال اپ → اسلایدر). Returns only ENABLED slides:
  /// `{ok, items:[{id,title,subtitle,image,link}], total}`. `link` is
  /// either an absolute URL (opened externally) or an in-app route token.
  static Future<StoreResult> appSlider() => wcpGet('/app/slider');

  /// Real speed/cache/SEO metrics for the «سرعت و کش» screen
  /// (`analytics/cache`): {overall, speed_ms, speed_score, seo_score,
  /// seo_checks[], cache_bytes, cache_files, cache_score, transients}.
  static Future<StoreResult> cacheAnalytics() => wcpGet('/analytics/cache');

  /// Really clear every cache layer (page cache + CDN + object-cache +
  /// dashboard transients) via the editable /app/cache/purge endpoint.
  /// Returns `{ok, purged, ran}`.
  static Future<StoreResult> purgeCache() =>
      wcpPost('/app/cache/purge', const <String, dynamic>{});

  // ── P5 — Content (posts + pages + custom post types + ACF) ──────
  /// Public post-type catalog: `[{type,label,count,draft,hierarchical}]`.
  static Future<StoreResult> contentTypes() => wcpGet('/content/types');

  /// List items of [type] (post / page / any CPT). Returns a Map
  /// `{items:[…], total, pages, type}`.
  static Future<StoreResult> contentList({
    String type = 'post',
    int page = 1,
    int perPage = 20,
    String? search,
  }) {
    final Map<String, String> q = {
      'type': type,
      'page': '$page',
      'per_page': '$perPage',
    };
    if (search != null && search.trim().isNotEmpty) q['search'] = search.trim();
    return wcpGet('/content', query: q);
  }

  /// Single content item with rendered body + ACF/meta fields: `{item:{…}}`.
  static Future<StoreResult> contentItem(int id) =>
      wcpGet('/content', query: <String, String>{'id': '$id'});

  /// Move a post/page/CPT item between `draft` and `publish`. Server enforces
  /// the caller's `edit_post` capability (403 otherwise). Returns `{ok,id,status}`.
  static Future<StoreResult> setContentStatus(int id, String status) =>
      wcpPost('/app/content/status', <String, dynamic>{'id': id, 'status': status});

  /// Reversibly trash a content item (recoverable from the site's trash —
  /// never a permanent delete). Server enforces `delete_post` (403 otherwise).
  /// Returns `{ok,id,trashed}`.
  static Future<StoreResult> trashContent(int id) =>
      wcpPost('/app/content/delete', <String, dynamic>{'id': id});

  // ── Store currency (WC general settings) ────────────────────────
  /// Read WooCommerce's active currency. Response carries `value` (the code,
  /// e.g. `IRT`) plus `options` (map of all supported `code → label`), so the
  /// app's «واحد پول» can mirror WooCommerce instead of a hardcoded label.
  static Future<StoreResult> getWcCurrency() =>
      wcGet('/settings/general/woocommerce_currency');

  /// Write the store currency back to WooCommerce — the change applies to the
  /// whole site, so the app stays the single source of truth in both
  /// directions (read + write).
  static Future<StoreResult> setWcCurrency(String code) =>
      wcPut('/settings/general/woocommerce_currency',
          <String, dynamic>{'value': code});

  // ── Payment gateways (manage in-app, no site visit) ─────────────
  /// All registered WooCommerce payment gateways:
  /// `[{id,title,description,enabled,method_title,method_description,order}]`.
  static Future<StoreResult> paymentGateways() => wcGet('/payment_gateways');

  /// Enable/disable a single gateway by id (e.g. `cod`, `wooplus_idpay`).
  static Future<StoreResult> setGatewayEnabled(String id, bool enabled) =>
      wcPut('/payment_gateways/$id', <String, dynamic>{'enabled': enabled});

  // ── Shipping (zones → methods, manage in-app) ───────────────────
  /// Shipping zones: `[{id,name,order}]` (plus the implicit zone 0 «rest of
  /// the world»).
  static Future<StoreResult> shippingZones() => wcGet('/shipping/zones');

  /// Methods inside a zone: `[{instance_id,title,method_id,enabled,settings}]`.
  static Future<StoreResult> shippingZoneMethods(int zoneId) =>
      wcGet('/shipping/zones/$zoneId/methods');

  /// Enable/disable a shipping method instance within a zone.
  static Future<StoreResult> setShippingMethodEnabled(
          int zoneId, int instanceId, bool enabled) =>
      wcPut('/shipping/zones/$zoneId/methods/$instanceId',
          <String, dynamic>{'enabled': enabled});

  static Future<StoreResult> appWallet({int? userId}) =>
      wcpGet('/app/wallet', query: userId != null ? {'user_id': '$userId'} : null);

  /// Paginated store-wide wallet ledger («مشاهدهٔ همهٔ تراکنش‌ها»). Returns
  /// `{ok, total, page, items:[…]}`.
  static Future<StoreResult> walletTransactions({int page = 1, int perPage = 30}) =>
      wcpGet('/app/wallet/transactions',
          query: <String, String>{'page': '$page', 'per_page': '$perPage'});

  /// Transfer credit between two customer wallets (debit sender + credit
  /// receiver, atomic with rollback on the server). `reason` is required.
  static Future<StoreResult> walletTransfer({
    required int fromUser,
    required int toUser,
    required int amount,
    required String reason,
  }) =>
      wcpPost('/app/wallet/transfer', <String, dynamic>{
        'from_user': fromUser,
        'to_user': toUser,
        'amount': amount,
        'reason': reason,
      });

  static Future<StoreResult> appLoyalty({int? userId}) =>
      wcpGet('/app/loyalty', query: userId != null ? {'user_id': '$userId'} : null);

  /// Replace the whole club tier set (add/edit/delete handled client-side by
  /// mutating the list then saving it). Returns `{tiers:[...]}` (normalized).
  static Future<StoreResult> saveLoyaltyTiers(List<Map<String, dynamic>> tiers) =>
      wcpPost('/app/loyalty/tiers', <String, dynamic>{'tiers': tiers});

  static Future<StoreResult> appGiftcards({String? status, int page = 1, int perPage = 30}) {
    final Map<String, String> q = {'page': '$page', 'per_page': '$perPage'};
    if (status != null && status.isNotEmpty && status != 'all') q['status'] = status;
    return wcpGet('/app/giftcards', query: q);
  }

  static Future<StoreResult> appTickets({String? status, int page = 1, int perPage = 20}) {
    final Map<String, String> q = {'page': '$page', 'per_page': '$perPage'};
    if (status != null && status.isNotEmpty && status != 'all') q['status'] = status;
    return wcpGet('/app/tickets', query: q);
  }

  static Future<StoreResult> appTicket(int id) => wcpGet('/app/tickets/$id');

  static Future<StoreResult> appQa({String? status, int page = 1, int perPage = 30}) {
    final Map<String, String> q = {'page': '$page', 'per_page': '$perPage'};
    if (status != null && status.isNotEmpty && status != 'all') q['status'] = status;
    return wcpGet('/app/qa', query: q);
  }

  static Future<StoreResult> appAnswerQa(int id, {String? answer, String? status}) {
    final Map<String, dynamic> b = {};
    if (answer != null) b['answer'] = answer;
    if (status != null) b['status'] = status;
    return wcpPost('/app/qa/$id', b);
  }

  /// Block / re-activate a gift card (status flag only). status ∈ active|blocked.
  static Future<StoreResult> giftcardStatus(int id, String status) =>
      wcpPost('/app/giftcards/$id/status', <String, dynamic>{'status': status});

  /// Reopen/close a ticket and/or assign it to a staff member.
  static Future<StoreResult> ticketStatus(int id,
          {String? status, int? assigneeId, String? priority, String? department}) =>
      wcpPost('/app/tickets/$id/status', <String, dynamic>{
        if (status != null) 'status': status,
        if (assigneeId != null) 'assignee_id': assigneeId,
        if (priority != null) 'priority': priority,
        if (department != null) 'department': department,
      });

  /// Ticketing module config the app mirrors: `{departments:[{slug,name,color}],
  /// priorities:[{slug,label}], statuses:[...]}`.
  static Future<StoreResult> ticketMeta() => wcpGet('/app/tickets/meta');

  /// Open a NEW ticket from the app (merchant-side). Returns `{ticket_id}`.
  static Future<StoreResult> ticketCreate({
    required String subject,
    required String body,
    required String customerEmail,
    String customerName = '',
    String customerPhone = '',
    String department = 'general',
    String priority = 'normal',
  }) =>
      wcpPost('/app/tickets/new', <String, dynamic>{
        'subject': subject,
        'body': body,
        'customer_email': customerEmail,
        if (customerName.isNotEmpty) 'customer_name': customerName,
        if (customerPhone.isNotEmpty) 'customer_phone': customerPhone,
        'department': department,
        'priority': priority,
      });

  /// Record a customer-satisfaction rating (1..5 + optional comment) on a ticket.
  static Future<StoreResult> ticketRate(int id,
          {required int rating, String comment = ''}) =>
      wcpPost('/app/tickets/$id/rate', <String, dynamic>{
        'rating': rating,
        if (comment.isNotEmpty) 'comment': comment,
      });

  /// Post an agent reply to a ticket. Returns `{message: {...}}` on success
  /// (the server-rendered message, identical to a reload). `attachmentIds` are
  /// media-library IDs from [uploadMedia] — body may be empty if there's ≥1.
  static Future<StoreResult> ticketReply(int id,
          {String body = '',
          bool internal = false,
          List<int> attachmentIds = const <int>[]}) =>
      wcpPost('/app/tickets/$id/reply', <String, dynamic>{
        'body': body,
        if (internal) 'internal': true,
        if (attachmentIds.isNotEmpty) 'attachments': attachmentIds,
      });

  // ── Live Chat (woocommerce-plus/v1/app/chat/*) ──────────────────
  // Content lives on the merchant WP (this store); the central server is only a
  // content-free change beacon. The app reads/writes messages here.
  /// Staff conversation list. status ∈ open|pending|closed|all.
  static Future<StoreResult> chatConversations({String status = 'all'}) {
    final Map<String, String> q = <String, String>{};
    if (status.isNotEmpty && status != 'all') q['status'] = status;
    return wcpGet('/app/chat/conversations', query: q.isEmpty ? null : q);
  }

  /// Messages of a conversation after [afterId] (staff also sees internal notes).
  static Future<StoreResult> chatMessages(int id, {int afterId = 0}) =>
      wcpGet('/app/chat/conversations/$id/messages',
          query: <String, String>{'after_id': '$afterId'});

  /// Post a staff reply (first non-internal reply auto-claims the thread).
  /// [internal] makes it a private note invisible to the customer.
  static Future<StoreResult> chatReply(int id, String body,
          {bool internal = false}) =>
      wcpPost('/app/chat/conversations/$id/reply', <String, dynamic>{
        'body': body,
        if (internal) 'internal': true,
      });

  /// Set a conversation's status (open|pending|closed).
  static Future<StoreResult> chatStatus(int id, String status) =>
      wcpPost('/app/chat/conversations/$id/status',
          <String, dynamic>{'status': status});

  /// Content-free relay credentials for the live beacon (central /s/changes).
  static Future<StoreResult> chatRelayCredentials() =>
      wcpGet('/app/chat/relay-credentials');

  // ── Chat access model (manager-only on the server) ──────────────
  /// Departments + (on /staff) the staff list with each user's role + depts.
  static Future<StoreResult> chatDepartments() => wcpGet('/app/chat/departments');
  static Future<StoreResult> chatCreateDepartment(String name, {String? color}) =>
      wcpPost('/app/chat/departments',
          <String, dynamic>{'name': name, if (color != null) 'color': color});
  static Future<StoreResult> chatDeleteDepartment(int id) =>
      wcpPost('/app/chat/departments/$id/delete', const <String, dynamic>{});
  static Future<StoreResult> chatStaff() => wcpGet('/app/chat/staff');
  static Future<StoreResult> chatSetStaff(int userId, String role, List<int> departments) =>
      wcpPost('/app/chat/staff',
          <String, dynamic>{'user_id': userId, 'role': role, 'departments': departments});
  /// Route a conversation to a department and/or a staff member.
  static Future<StoreResult> chatAssign(int convId, {int? departmentId, int? staffId}) =>
      wcpPost('/app/chat/conversations/$convId/assign', <String, dynamic>{
        if (departmentId != null) 'department_id': departmentId,
        if (staffId != null) 'staff_id': staffId,
      });

  static Future<StoreResult> appBlocklist() => wcpGet('/app/blocklist');
  static Future<StoreResult> appBlock({required String type, required String action, required String value}) =>
      wcpPost('/app/blocklist', {'type': type, 'action': action, 'value': value});

  static Future<StoreResult> appModules() => wcpGet('/app/modules');
  static Future<StoreResult> appSetModule({required String module, required bool enabled}) =>
      wcpPost('/app/modules', {'module': module, 'enabled': enabled});

  // Native WP/WC modules (coming-soon / catalog / maintenance / cache) —
  // separate endpoint because they write WC/WP options, not wooplus_settings.
  static Future<StoreResult> appNative() => wcpGet('/app/native');
  static Future<StoreResult> appSetNative({required String module, required bool enabled}) =>
      wcpPost('/app/native', {'module': module, 'enabled': enabled});

  // Per-module settings (data/fields). GET returns a typed field schema for the
  // module's REAL option (reflected; secrets masked); POST saves it back.
  static Future<StoreResult> moduleSettings(String key) =>
      wcpGet('/app/module-settings', query: <String, String>{'key': key});
  static Future<StoreResult> setModuleSettings(String key, Map<String, dynamic> fields) =>
      wcpPost('/app/module-settings', {'key': key, 'fields': fields});

  // Rich, REAL config (same JSON shape as moduleSettings, but typed/curated):
  // key 'general' → store-wide controls from the master wooplus_settings;
  // any other key → that module's own option, reflected. Backed by the
  // editable /app/module-config endpoint (capability-checked server-side).
  static Future<StoreResult> storeConfig(String key) =>
      wcpGet('/app/module-config', query: <String, String>{'key': key});
  static Future<StoreResult> saveStoreConfig(String key, Map<String, dynamic> fields) =>
      wcpPost('/app/module-config', {'key': key, 'fields': fields});

  // multilingual + SEO (used by the product-edit screen)
  static Future<StoreResult> appMultilingual({int? productId}) =>
      wcpGet('/app/multilingual', query: productId != null ? {'product_id': '$productId'} : null);
  static Future<StoreResult> appSaveTranslation({required int productId, required String lang, required Map<String, dynamic> fields}) =>
      wcpPost('/app/multilingual', {'product_id': productId, 'lang': lang, 'fields': fields});
  static Future<StoreResult> appAiTranslate({required int productId, required String lang, bool save = false}) =>
      wcpPost('/app/multilingual/ai', {'product_id': productId, 'lang': lang, 'save': save});

  /// AI assistant status: `{available, configured, provider}`.
  static Future<StoreResult> aiStatus() => wcpGet('/app/ai/status');

  /// Full editable AI config (grouped, schema-driven; API keys masked).
  static Future<StoreResult> aiSettings() => wcpGet('/app/ai/settings');

  /// Save AI config. `values` = changed `{key:value}` (secrets only when newly
  /// typed). Returns the fresh masked payload.
  static Future<StoreResult> aiSaveSettings(Map<String, dynamic> values) =>
      wcpPost('/app/ai/settings', <String, dynamic>{'values': values});

  /// Store-grounded AI chat (manager assistant). `messages` is the conversation
  /// as `[{role:'user'|'assistant', content}]`; the server prepends a system
  /// persona + live store snapshot. Returns `{reply}` on success.
  static Future<StoreResult> aiChat(List<Map<String, String>> messages) =>
      wcpPost('/app/ai/chat', <String, dynamic>{'messages': messages});

  /// «تست اتصال» — fire a tiny prompt at the configured provider/key.
  /// Returns `{ok, reply}` on success, or `{ok:false, message}` with the
  /// provider's real error / “no key” notice.
  static Future<StoreResult> aiTest({String? prompt}) =>
      wcpPost('/app/ai/test',
          <String, dynamic>{if (prompt != null && prompt.isNotEmpty) 'prompt': prompt});

  // ── Curated per-module settings (grouped, schema-driven editor) ──
  /// Full editable settings for a module as `{ok, available, title,
  /// subtitle?, groups:[...], actions?:[...]}` (same field schema as AI).
  static Future<StoreResult> moduleSchema(String id) =>
      wcpGet('/app/module/$id/settings');

  /// Save a module's settings. `values` = changed `{key:value}` (secrets
  /// only when newly typed). Returns the fresh masked payload.
  static Future<StoreResult> moduleSchemaSave(
          String id, Map<String, dynamic> values) =>
      wcpPost('/app/module/$id/settings', <String, dynamic>{'values': values});

  // ── Notice-bar CRUD (نوار اعلان) ─────────────────────────────────
  /// List bars + available templates (each template carries its `fields`
  /// schema for the «add» editor).
  static Future<StoreResult> noticeBars() => wcpGet('/app/notice-bars');

  /// One bar's editable fields (with current values), for editing.
  static Future<StoreResult> noticeBar(String id) =>
      wcpGet('/app/notice-bars/$id');

  static Future<StoreResult> noticeBarCreate(
          String template, Map<String, dynamic> values) =>
      wcpPost('/app/notice-bars',
          <String, dynamic>{'template': template, 'values': values});

  static Future<StoreResult> noticeBarUpdate(
          String id, Map<String, dynamic> values) =>
      wcpPost('/app/notice-bars/$id', <String, dynamic>{'values': values});

  static Future<StoreResult> noticeBarDelete(String id) =>
      wcpPost('/app/notice-bars/$id/delete', <String, dynamic>{});

  // ── Stop-sale rules CRUD (قوانینِ توقفِ فروش) ─────────────────────
  /// List rules + the `add_fields` schema (category/role options prefilled).
  static Future<StoreResult> stopSaleRules() => wcpGet('/app/stop-sale-rules');
  static Future<StoreResult> stopSaleRule(String id) =>
      wcpGet('/app/stop-sale-rules/$id');
  static Future<StoreResult> stopSaleRuleCreate(Map<String, dynamic> values) =>
      wcpPost('/app/stop-sale-rules', <String, dynamic>{'values': values});
  static Future<StoreResult> stopSaleRuleUpdate(
          String id, Map<String, dynamic> values) =>
      wcpPost('/app/stop-sale-rules/$id', <String, dynamic>{'values': values});
  static Future<StoreResult> stopSaleRuleDelete(String id) =>
      wcpPost('/app/stop-sale-rules/$id/delete', <String, dynamic>{});

  // ── Team goals (اهداف تیم) — CRUD + status/reply/rate ────────────
  /// List goals + meta (`statuses`, `roles`, `users` for the create form).
  static Future<StoreResult> teamGoals() => wcpGet('/app/team-goals');
  static Future<StoreResult> teamGoal(String id) => wcpGet('/app/team-goals/$id');
  static Future<StoreResult> teamGoalCreate(Map<String, dynamic> values) =>
      wcpPost('/app/team-goals', values);
  static Future<StoreResult> teamGoalStatus(String id, String status) =>
      wcpPost('/app/team-goals/$id/status', <String, dynamic>{'status': status});
  static Future<StoreResult> teamGoalReply(String id, String message) =>
      wcpPost('/app/team-goals/$id/reply', <String, dynamic>{'message': message});
  static Future<StoreResult> teamGoalRate(String id, int rating) =>
      wcpPost('/app/team-goals/$id/rate', <String, dynamic>{'rating': rating});
  static Future<StoreResult> teamGoalDelete(String id) =>
      wcpPost('/app/team-goals/$id/delete', <String, dynamic>{});

  /// Run a declared module action (e.g. a test/sync button).
  static Future<StoreResult> moduleAction(String id, String action,
          {Map<String, dynamic>? values}) =>
      wcpPost('/app/module/$id/action', <String, dynamic>{
        'action': action,
        if (values != null) 'values': values,
      });
  static Future<StoreResult> appSeo(int productId) =>
      wcpGet('/app/seo', query: {'product_id': '$productId'});
  static Future<StoreResult> appSaveSeo(int productId, Map<String, dynamic> fields) =>
      wcpPost('/app/seo', {'product_id': productId, ...fields});

  /// Fetch the store's display name from the WP REST root (`/wp-json` → `name`).
  /// Cheap, cached in [_storeName]. Best-effort — leaves the previous value
  /// untouched on any failure, so callers can read [storeName] synchronously.
  static Future<void> fetchStoreInfo() async {
    final String? u = _siteUrl;
    if (u == null || u.isEmpty) return;
    final StoreResult r = await _request('GET', '$u/wp-json');
    if (r.ok) {
      final dynamic n = r.map['name'];
      if (n != null && n.toString().trim().isNotEmpty) {
        _storeName = n.toString().trim();
        // Remember the resolved name on the active store entry so the
        // «فروشگاه‌های من» switcher shows real names, not bare hosts.
        final int i = _stores.indexWhere((e) => (e['url'] ?? '') == u);
        if (i >= 0 && (_stores[i]['name'] ?? '').toString().trim().isEmpty) {
          _stores[i]['name'] = _storeName;
          await _persistStores();
        }
      }
      // WP 5.9+ exposes the Site Icon URL on the REST root; use it as the
      // store logo shown next to the name. Empty string ⇒ none set.
      final dynamic ico = r.map['site_icon_url'];
      if (ico != null) _storeLogo = ico.toString().trim();
    }
  }

  // ── convenience helpers for the core screens ───────────────────
  static Future<StoreResult> orders({int page = 1, int perPage = 20, String? status, String? search}) {
    final Map<String, String> q = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      'orderby': 'date',
      'order': 'desc',
    };
    if (status != null && status.isNotEmpty && status != 'all') q['status'] = status;
    if (search != null && search.isNotEmpty) q['search'] = search;
    return wcGet('/orders', query: q);
  }

  static Future<StoreResult> order(int id) => wcGet('/orders/$id');

  /// A customer's most recent orders (newest first) — for the profile's
  /// "recent orders" list. Standard wc/v3 with the `customer` filter.
  /// [perPage] defaults to 5 (the visible list); the profile asks for a
  /// larger page so it can derive the REAL order count + total spend from
  /// the actual order records (the analytics report can lag / read 0).
  static Future<StoreResult> customerOrders(int customerId,
          {int perPage = 5}) =>
      wcGet('/orders', query: <String, String>{
        'customer': '$customerId',
        'per_page': '$perPage',
        'orderby': 'date',
        'order': 'desc',
      });

  /// A single customer's full record (wc/v3) — carries billing (phone +
  /// address), username and date_created, which the analytics customers
  /// report omits. Used by the profile to fill the header + address card.
  static Future<StoreResult> customer(int id) => wcGet('/customers/$id');

  // ── Customer actions (writes) via woocommerce-plus/v1/app/customer/* ──
  // Each one mirrors a button in the profile's 3-dot sheet. Server-side they
  // enforce: refuse admin-cap accounts; whitelisted target roles only; the
  // wallet credit endpoint requires a non-empty `reason`.

  /// Credit a customer's WC+ wallet by [amount] minor units (e.g. tomans).
  /// The server REQUIRES a non-empty [reason] for admin-scope credits.
  static Future<StoreResult> appCustomerWalletCredit({
    required int userId,
    required int amount,
    required String reason,
  }) =>
      wcpPost('/app/customer/wallet-credit', <String, dynamic>{
        'user_id': userId,
        'amount': amount,
        'reason': reason,
      });

  /// Push the customer's billing email and/or phone into the WC+ blocklist.
  /// [scope] is one of 'both' | 'email' | 'phone'.
  static Future<StoreResult> appCustomerBlock({
    required int userId,
    String scope = 'both',
  }) =>
      wcpPost('/app/customer/block', <String, dynamic>{
        'user_id': userId,
        'scope': scope,
      });

  /// Change a customer's WordPress role. The server WHITELISTS the target
  /// role to `[customer, subscriber, contributor, shop_manager]` — anything
  /// else (esp. administrator) is rejected with `wpac_bad_role`.
  static Future<StoreResult> appCustomerRole({
    required int userId,
    required String role,
  }) =>
      wcpPost('/app/customer/role', <String, dynamic>{
        'user_id': userId,
        'role': role,
      });

  /// List staff members (WP users with shop-management caps) — powers
  /// the «تیم و دسترسی‌ها» screen in the «بیشتر» tab.
  static Future<StoreResult> appTeam() => wcpGet('/app/team');

  /// Create a customer (wc/v3). `email` is required + must be unique; WC
  /// auto-generates a username/password when omitted.
  static Future<StoreResult> createCustomer(Map<String, dynamic> data) =>
      wcPost('/customers', data);

  /// Update a customer (wc/v3) — e.g. {'billing': {...}, 'first_name': …}.
  static Future<StoreResult> updateCustomer(int id, Map<String, dynamic> data) =>
      wcPut('/customers/$id', data);

  /// Permanently delete a customer (wc/v3 has no trash for customers, so
  /// `force=true` is mandatory). Triggered only by an explicit user tap.
  static Future<StoreResult> deleteCustomer(int id) => wcDelete(
        '/customers/$id',
        query: <String, String>{'force': 'true'},
      );

  static Future<StoreResult> updateOrderStatus(int id, String status) =>
      wcPut('/orders/$id', <String, dynamic>{'status': status});

  static Future<StoreResult> orderNotes(int id) => wcGet('/orders/$id/notes');
  static Future<StoreResult> addOrderNote(int id, String note, {bool customerNote = false}) =>
      wcPost('/orders/$id/notes', <String, dynamic>{'note': note, 'customer_note': customerNote});

  static Future<StoreResult> updateOrder(int id, Map<String, dynamic> body) =>
      wcPut('/orders/$id', body);

  /// Trash an order (force:false → recoverable). Never hard-deletes.
  static Future<StoreResult> deleteOrder(int id, {bool force = false}) =>
      wcDelete('/orders/$id', query: <String, String>{'force': '$force'});

  static Future<StoreResult> products({int page = 1, int perPage = 20, String? search}) {
    final Map<String, String> q = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (search != null && search.isNotEmpty) q['search'] = search;
    return wcGet('/products', query: q);
  }

  static Future<StoreResult> product(int id) => wcGet('/products/$id');

  static Future<StoreResult> updateProduct(int id, Map<String, dynamic> fields) =>
      wcPut('/products/$id', fields);

  static Future<StoreResult> createProduct(Map<String, dynamic> fields) =>
      wcPost('/products', fields);

  /// Upload a base64 image into the WP media library via the app-connect
  /// endpoint (WC keys can't reach core wp/v2/media). Returns `{id, url}`.
  static Future<StoreResult> uploadMedia({
    required String data,
    required String mime,
    required String filename,
  }) =>
      wcpPost('/app/media', <String, dynamic>{
        'data': data,
        'mime': mime,
        'filename': filename,
      });

  /// Customers list. Prefers the WC-Admin analytics report (it carries
  /// orders_count + total_spent), but **falls back to plain wc/v3/customers**
  /// when that report is empty — which happens on stores whose WC-Admin
  /// analytics lookup tables aren't populated (e.g. orders created
  /// programmatically). Without the fallback the list looked empty even
  /// though registered customers existed. [customerFromWoo] reads both shapes.
  static Future<StoreResult> customers(
      {int page = 1, int perPage = 20, String? search}) async {
    final Map<String, String> q = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      // WC-Admin analytics customers report orders by `total_spend`
      // (NOT `total_spent` — that value is rejected with rest_invalid_param,
      // which forced the empty wc/v3 fallback and a blank list).
      'orderby': 'total_spend',
      'order': 'desc',
    };
    if (search != null && search.isNotEmpty) q['search'] = search;
    final StoreResult a = await wcaGet('/reports/customers', query: q);
    if (a.ok && a.list.isNotEmpty) return a;
    // Fallback — lists every registered customer regardless of analytics.
    final Map<String, String> q2 = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      'orderby': 'registered_date',
      'order': 'desc',
    };
    if (search != null && search.isNotEmpty) q2['search'] = search;
    return wcGet('/customers', query: q2);
  }

  // ── coupons (standard wc/v3/coupons) ────────────────────────────
  static Future<StoreResult> coupons({int page = 1, int perPage = 30, String? search}) {
    final Map<String, String> q = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      'orderby': 'date',
      'order': 'desc',
    };
    if (search != null && search.isNotEmpty) q['search'] = search;
    return wcGet('/coupons', query: q);
  }

  static Future<StoreResult> createCoupon(Map<String, dynamic> body) =>
      wcPost('/coupons', body);

  /// Update an existing coupon (wc/v3/coupons/{id}). Used to toggle a coupon
  /// active/inactive via `{status: publish|draft}`.
  static Future<StoreResult> updateCoupon(int id, Map<String, dynamic> body) =>
      wcPut('/coupons/$id', body);

  // ── product reviews (standard wc/v3/products/reviews) ───────────
  static Future<StoreResult> reviews({int page = 1, int perPage = 30, String? status}) {
    final Map<String, String> q = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (status != null && status.isNotEmpty && status != 'all') q['status'] = status;
    return wcGet('/products/reviews', query: q);
  }

  /// Moderate a review — [status] ∈ approved | hold | spam | trash.
  static Future<StoreResult> updateReviewStatus(int id, String status) =>
      wcPut('/products/reviews/$id', <String, dynamic>{'status': status});

  // ── manual order creation (standard wc/v3/orders) ───────────────
  static Future<StoreResult> createOrder(Map<String, dynamic> body) =>
      wcPost('/orders', body);

  // ── dashboard analytics (wc-analytics reports) ──────────────────
  /// Revenue stats over [after,before] bucketed by [interval]
  /// ('hour'|'day'|'week'|'month'). The response carries `totals`
  /// (net_revenue, orders_count, …) + `intervals[]` (per-bucket subtotals)
  /// — enough to build both the KPI numbers and the sales chart series.
  static Future<StoreResult> revenueStats({
    required String after,
    required String before,
    String interval = 'day',
  }) =>
      wcaGet('/reports/revenue/stats', query: <String, String>{
        'after': after,
        'before': before,
        'interval': interval,
        'order': 'asc',
        'per_page': '100',
      });

  /// New-customers stats over [after,before] (totals.customers_count +
  /// per-interval subtotals for the sparkline).
  static Future<StoreResult> customersStats({
    required String after,
    required String before,
    String interval = 'day',
  }) =>
      wcaGet('/reports/customers/stats', query: <String, String>{
        'after': after,
        'before': before,
        'interval': interval,
        'order': 'asc',
        'per_page': '100',
      });

  /// Count of published products — reads `X-WP-Total` without pulling bodies.
  static Future<StoreResult> productsTotal() =>
      wcGet('/products', query: <String, String>{
        'per_page': '1',
        'status': 'publish',
        '_fields': 'id',
      });

  /// Best-selling products over [after,before] (items_sold desc), with the
  /// product name/image folded in via `extended_info`.
  static Future<StoreResult> topProductsReport({
    required String after,
    required String before,
    int perPage = 5,
  }) =>
      wcaGet('/reports/products', query: <String, String>{
        'after': after,
        'before': before,
        'orderby': 'items_sold',
        'order': 'desc',
        'per_page': '$perPage',
        'extended_info': 'true',
      });

  /// Current + previous ISO date windows (+ chart interval) for a dashboard
  /// range ('today'|'week'|'month'|'year'). The previous window is the same
  /// span immediately before the current one, so deltas are like-for-like.
  static ({
    String after,
    String before,
    String prevAfter,
    String prevBefore,
    String interval,
  }) periodRange(String range) {
    final DateTime now = DateTime.now();
    final DateTime before = now;
    late DateTime after;
    late String interval;
    switch (range) {
      case 'today':
        after = DateTime(now.year, now.month, now.day);
        interval = 'hour';
        break;
      case 'month':
        after = now.subtract(const Duration(days: 29));
        interval = 'day';
        break;
      case 'year':
        after = DateTime(now.year - 1, now.month, now.day);
        interval = 'month';
        break;
      case 'week':
      default:
        after = now.subtract(const Duration(days: 6));
        interval = 'day';
    }
    final Duration span = before.difference(after);
    final DateTime prevBefore = after;
    final DateTime prevAfter = after.subtract(span);
    String iso(DateTime d) => d.toIso8601String().split('.').first;
    return (
      after: iso(after),
      before: iso(before),
      prevAfter: iso(prevAfter),
      prevBefore: iso(prevBefore),
      interval: interval,
    );
  }

  // ───────────────────────────────────────────────────────────────
  static String _wc(String path) => '$_siteUrl/wp-json/wc/v3${_slash(path)}';
  static String _wcp(String path) => '$_siteUrl/wp-json/woocommerce-plus/v1${_slash(path)}';
  static String _wca(String path) => '$_siteUrl/wp-json/wc-analytics${_slash(path)}';
  static String _slash(String p) => p.startsWith('/') ? p : '/$p';

  /// WC Admin analytics (wc-analytics namespace) — orders_count, total_spent,
  /// sales stats, etc. Same WC REST auth as wc/v3.
  static Future<StoreResult> wcaGet(String path, {Map<String, String>? query}) =>
      _request('GET', _wca(path), query: query);

  static Map<String, String> _headers({String? ck, String? cs}) {
    final String k = ck ?? _ck ?? '';
    final String s = cs ?? _cs ?? '';
    final String basic = base64Encode(utf8.encode('$k:$s'));
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Basic $basic',
    };
  }

  static Future<StoreResult> _request(
    String method,
    String url, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? ck,
    String? cs,
  }) async {
    if ((_siteUrl == null || _siteUrl!.isEmpty) && ck == null) {
      return const StoreResult(ok: false, error: 'فروشگاه متصل نیست.');
    }
    Uri uri = Uri.parse(url);
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: <String, String>{...uri.queryParameters, ...query});
    }

    try {
      final Map<String, String> h = _headers(ck: ck, cs: cs);
      late http.Response r;
      switch (method) {
        case 'POST':
          r = await http.post(uri, headers: h, body: jsonEncode(body ?? <String, dynamic>{})).timeout(_timeout);
          break;
        case 'PUT':
          r = await http.put(uri, headers: h, body: jsonEncode(body ?? <String, dynamic>{})).timeout(_timeout);
          break;
        default:
          r = await http.get(uri, headers: h).timeout(_timeout);
      }
      return _parse(r);
    } catch (e) {
      return StoreResult(
          ok: false, error: 'ارتباط با فروشگاه برقرار نشد (${e.runtimeType}).');
    }
  }

  static StoreResult _parse(http.Response r) {
    dynamic decoded;
    try {
      decoded = jsonDecode(r.body);
    } catch (_) {/* non-JSON */}
    final bool ok = r.statusCode >= 200 && r.statusCode < 300;
    final int total = int.tryParse(r.headers['x-wp-total'] ?? '') ?? 0;
    String? err;
    if (!ok) {
      err = (decoded is Map && decoded['message'] is String)
          ? decoded['message'] as String
          : 'خطای فروشگاه (${r.statusCode})';
    }
    return StoreResult(ok: ok, data: decoded, error: err, statusCode: r.statusCode, total: total);
  }
}
