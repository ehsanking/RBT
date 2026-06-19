// ════════════════════════════════════════════════════════════════
// booking_services.dart — رزرو: مدیریت کاملِ «خدمات» از اپ (CRUD).
//
// Full parity with the web panel's service editor — NOTHING dropped:
//   name · active · duration/buffer/notice/cancel-before · capacity · price
//   · payment mode (none/deposit/fixed/full) + deposit% / fixed amount
//   · weekly hours (multi window: day-set + start/end)
//   · add-ons (label + price)  · custom form fields (label + type + options…)
//
// Backed by the booking SERVICES REST (full parity):
//   GET  /app/booking/services            → list + field_types + pay_modes
//   POST /app/booking/services            → create/update (save_service)
//   POST /app/booking/services/{id}/delete
// Reached from a «خدمات» action on BookingsScreen.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/icons.dart';
import '../nav/shell.dart';
import '../services/store_api.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'registry.dart';

void registerBookingServicesScreen() {
  kScreens['mod_booking_services'] = (ctx, p) => const BookingServicesScreen();
}

// PHP weekday ints (0=Sun … 6=Sat); display in Persian week order (Sat first).
const List<({int n, String fa})> _kDays = [
  (n: 6, fa: 'شنبه'),
  (n: 0, fa: 'یکشنبه'),
  (n: 1, fa: 'دوشنبه'),
  (n: 2, fa: 'سه‌شنبه'),
  (n: 3, fa: 'چهارشنبه'),
  (n: 4, fa: 'پنجشنبه'),
  (n: 5, fa: 'جمعه'),
];

// A labeled switch row (WcpSwitch has no built-in label).
Widget _labeledSwitch(
    BuildContext ctx, String label, bool value, ValueChanged<bool> onChange) {
  return Row(
    children: [
      Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 13, color: ctx.c.tx1))),
      WcpSwitch(on: value, onChange: onChange),
    ],
  );
}

// ════════════════════════════════════════════════════════════════
// List screen.
// ════════════════════════════════════════════════════════════════
class BookingServicesScreen extends StatefulWidget {
  const BookingServicesScreen({super.key});
  @override
  State<BookingServicesScreen> createState() => _BookingServicesScreenState();
}

class _BookingServicesScreenState extends State<BookingServicesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _services = const <Map<String, dynamic>>[];
  Map<String, String> _payModes = const <String, String>{};
  Map<String, String> _fieldTypes = const <String, String>{};

  @override
  void initState() {
    super.initState();
    if (StoreApi.hasStore) {
      _load();
    } else {
      _loading = false;
      _error = 'برای مدیریت خدمات، فروشگاه را متصل کنید.';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final StoreResult r = await StoreApi.bookingServices();
    if (!mounted) return;
    if (!r.ok || r.map['available'] == false) {
      setState(() {
        _loading = false;
        _error = (r.map['message'] ?? r.error ?? 'دریافت خدمات ناموفق بود.')
            .toString();
      });
      return;
    }
    final dynamic items = r.map['items'];
    setState(() {
      _services = items is List
          ? items
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const <Map<String, dynamic>>[];
      _payModes = (r.map['pay_modes'] is Map)
          ? Map<String, String>.from((r.map['pay_modes'] as Map)
              .map((k, v) => MapEntry('$k', '$v')))
          : const <String, String>{};
      _fieldTypes = (r.map['field_types'] is Map)
          ? Map<String, String>.from((r.map['field_types'] as Map)
              .map((k, v) => MapEntry('$k', '$v')))
          : const <String, String>{};
      _loading = false;
    });
  }

  Future<void> _openEditor(Map<String, dynamic>? svc) async {
    final bool? saved = await AppScope.of(context).navigate.currentState!
        .push<bool>(MaterialPageRoute<bool>(
      builder: (_) => _ServiceEditorScreen(
        initial: svc,
        payModes: _payModes,
        fieldTypes: _fieldTypes,
      ),
    ));
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> svc) async {
    final nav = AppScope.of(context);
    final bool? yes = await showWcpDialog<bool>(
      context,
      icon: 'trash',
      iconColor: context.c.error,
      title: 'حذف خدمت',
      message:
          'خدمت «${(svc['name'] ?? '').toString()}» حذف شود؟ نوبت‌های آینده مانع حذف می‌شوند.',
      actions: [
        WcpButton(
            variant: 'secondary',
            label: 'انصراف',
            onClick: () => Navigator.of(context).pop(false)),
        WcpButton(
            variant: 'danger',
            label: 'حذف',
            onClick: () => Navigator.of(context).pop(true)),
      ],
    );
    if (yes != true) return;
    final StoreResult r =
        await StoreApi.bookingServiceDelete((svc['id'] as num?)?.toInt() ?? 0);
    if (!mounted) return;
    final bool ok = r.ok && r.map['ok'] == true;
    nav.showToast(
        (r.map['message'] ?? r.error ?? (ok ? 'حذف شد' : 'حذف ناموفق بود'))
            .toString(),
        kind: ok ? 'success' : 'error',
        icon: ok ? 'check' : 'alert');
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg0,
      floatingActionButton: (_error == null && !_loading)
          ? FloatingActionButton.extended(
              backgroundColor: c.accent,
              onPressed: () => _openEditor(null),
              icon: const WcpIcon('plus', size: 18, color: Colors.white),
              label: const Text('خدمت جدید',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: 'خدمات رزرو',
            sub: 'تعریف و ویرایش خدمات و ساعت‌بندی',
            onBack: () => AppScope.of(context).pop(),
          ),
          Expanded(
            child: _loading
                ? const SlowLoader()
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _services.isEmpty
                            ? ListView(children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    'هنوز خدمتی تعریف نشده.\nبا «خدمت جدید» اولین خدمت را بسازید.',
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(color: c.tx3, height: 1.8),
                                  ),
                                ),
                              ])
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 96),
                                itemCount: _services.length,
                                itemBuilder: (ctx, i) =>
                                    _card(ctx, _services[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext ctx, Map<String, dynamic> s) {
    final c = ctx.c;
    final bool active = s['active'] == true;
    final int dur = (s['duration_min'] as num?)?.toInt() ?? 0;
    final int price = (s['price'] as num?)?.toInt() ?? 0;
    final int cap = (s['capacity'] as num?)?.toInt() ?? 1;
    final int windows = (s['windows'] is List) ? (s['windows'] as List).length : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WcpCard(
        pad: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text((s['name'] ?? '').toString(),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                ),
                statusPillLocal(
                  active ? 'فعال' : 'غیرفعال',
                  active ? c.success : c.tx3,
                  active ? c.successSoft : c.bg3,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${Fmt.fa(dur)} دقیقه · ظرفیت ${Fmt.fa(cap)} · '
              '${price > 0 ? '${Fmt.toman(price)} ' : 'رایگان'} · ${Fmt.fa(windows)} بازه زمانی',
              style: TextStyle(fontSize: 12, color: c.tx2, height: 1.6),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: WcpButton(
                    variant: 'secondary',
                    icon: 'edit',
                    label: 'ویرایش',
                    onClick: () => _openEditor(s),
                  ),
                ),
                const SizedBox(width: 10),
                WcpButton(
                  variant: 'ghost',
                  icon: 'trash',
                  label: 'حذف',
                  onClick: () => _delete(s),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Local status pill (the dashboards one isn't imported here).
Widget statusPillLocal(String label, Color fg, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListView(children: [
      const SizedBox(height: 70),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.tx2, height: 1.8, fontSize: 13.5)),
      ),
      const SizedBox(height: 16),
      Center(
        child: WcpButton(
            variant: 'secondary', label: 'تلاش دوباره', onClick: onRetry),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// Editor — a mutable working copy of the service map.
// ════════════════════════════════════════════════════════════════
class _ServiceEditorScreen extends StatefulWidget {
  const _ServiceEditorScreen({
    required this.initial,
    required this.payModes,
    required this.fieldTypes,
  });
  final Map<String, dynamic>? initial;
  final Map<String, String> payModes;
  final Map<String, String> fieldTypes;

  @override
  State<_ServiceEditorScreen> createState() => _ServiceEditorScreenState();
}

class _ServiceEditorScreenState extends State<_ServiceEditorScreen> {
  late Map<String, dynamic> _s;
  late List<Map<String, dynamic>> _windows;
  late List<Map<String, dynamic>> _addons;
  late List<Map<String, dynamic>> _fields;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> src = widget.initial ?? const <String, dynamic>{};
    _s = <String, dynamic>{
      'id': (src['id'] as num?)?.toInt() ?? 0,
      'name': (src['name'] ?? '').toString(),
      'duration_min': (src['duration_min'] as num?)?.toInt() ?? 60,
      'buffer_min': (src['buffer_min'] as num?)?.toInt() ?? 0,
      'min_notice_min': (src['min_notice_min'] as num?)?.toInt() ?? 60,
      'cancel_before_min': (src['cancel_before_min'] as num?)?.toInt() ?? 120,
      'capacity': (src['capacity'] as num?)?.toInt() ?? 1,
      'price': (src['price'] as num?)?.toInt() ?? 0,
      'pay_mode': (src['pay_mode'] ?? 'none').toString(),
      'deposit_pct': (src['deposit_pct'] as num?)?.toInt() ?? 20,
      'fixed_amount': (src['fixed_amount'] as num?)?.toInt() ?? 0,
      'active': src['active'] == null ? true : src['active'] == true,
    };
    _windows = _cloneList(src['windows'], <String, dynamic>{
      'days': <int>[6, 0, 1, 2, 3],
      'start': '09:00',
      'end': '17:00',
    });
    _addons = _cloneList(src['addons'], null);
    _fields = _cloneList(src['fields'], null);
  }

  List<Map<String, dynamic>> _cloneList(dynamic raw, Map<String, dynamic>? fallback) {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) out.add(Map<String, dynamic>.from(e));
      }
    }
    if (out.isEmpty && fallback != null) out.add(Map<String, dynamic>.from(fallback));
    return out;
  }

  int _int(dynamic v, int def) => (v is num) ? v.toInt() : (int.tryParse('$v') ?? def);

  Future<void> _save() async {
    final nav = AppScope.of(context);
    if ((_s['name'] ?? '').toString().trim().isEmpty) {
      nav.showToast('نام خدمت لازم است.', kind: 'error', icon: 'alert');
      return;
    }
    setState(() => _saving = true);
    final Map<String, dynamic> body = <String, dynamic>{
      ..._s,
      'windows': _windows
          .map((w) => <String, dynamic>{
                'days': (w['days'] as List?)?.whereType<int>().toList() ??
                    <int>[],
                'start': (w['start'] ?? '').toString(),
                'end': (w['end'] ?? '').toString(),
              })
          .toList(),
      'addons': _addons
          .where((a) => (a['label'] ?? '').toString().trim().isNotEmpty)
          .map((a) => <String, dynamic>{
                'label': (a['label'] ?? '').toString(),
                'price': _int(a['price'], 0),
              })
          .toList(),
      'fields': _fields
          .where((f) => (f['label'] ?? '').toString().trim().isNotEmpty)
          .map((f) => <String, dynamic>{
                'label': (f['label'] ?? '').toString(),
                'type': (f['type'] ?? 'text').toString(),
                'options': (f['options'] ?? '').toString(),
                'required': f['required'] == true ? 1 : 0,
              })
          .toList(),
    };
    final StoreResult r = await StoreApi.bookingServiceSave(body);
    if (!mounted) return;
    setState(() => _saving = false);
    final bool ok = r.ok && r.map['ok'] == true;
    nav.showToast(
        (r.map['message'] ?? r.error ?? (ok ? 'ذخیره شد' : 'ذخیره ناموفق بود'))
            .toString(),
        kind: ok ? 'success' : 'error',
        icon: ok ? 'check' : 'alert');
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final String pay = (_s['pay_mode'] ?? 'none').toString();
    return Scaffold(
      backgroundColor: c.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WcpAppBar(
            title: _s['id'] == 0 ? 'خدمت جدید' : 'ویرایش خدمت',
            onBack: () => Navigator.of(context).pop(false),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _num(context, 'نام خدمت', 'name', isText: true),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _labeledSwitch(context, 'فعال', _s['active'] == true,
                      (v) => setState(() => _s['active'] = v)),
                ),
                _sectionTitle(context, 'زمان‌بندی'),
                _num(context, 'مدت (دقیقه)', 'duration_min'),
                _num(context, 'فاصله بین نوبت‌ها (دقیقه)', 'buffer_min'),
                _num(context, 'حداقل فاصله رزرو تا نوبت (دقیقه)', 'min_notice_min'),
                _num(context, 'مهلت لغو پیش از نوبت (دقیقه)', 'cancel_before_min'),
                _num(context, 'ظرفیت همزمان', 'capacity'),
                _sectionTitle(context, 'قیمت و پرداخت'),
                _num(context, 'قیمت (تومان)', 'price'),
                _payModeRow(context, pay),
                if (pay == 'deposit') _num(context, 'درصد بیعانه', 'deposit_pct'),
                if (pay == 'fixed') _num(context, 'مبلغ ثابت (تومان)', 'fixed_amount'),
                _sectionTitle(context, 'ساعات کاری هفتگی'),
                ..._windowEditors(context),
                Align(
                  alignment: Alignment.centerRight,
                  child: WcpButton(
                    variant: 'ghost',
                    icon: 'plus',
                    label: 'بازه زمانی',
                    onClick: () => setState(() => _windows.add(<String, dynamic>{
                          'days': <int>[6, 0, 1, 2, 3],
                          'start': '09:00',
                          'end': '17:00',
                        })),
                  ),
                ),
                _sectionTitle(context, 'آپشن‌ها (اختیاری)'),
                ..._addonEditors(context),
                Align(
                  alignment: Alignment.centerRight,
                  child: WcpButton(
                    variant: 'ghost',
                    icon: 'plus',
                    label: 'آپشن',
                    onClick: () => setState(
                        () => _addons.add(<String, dynamic>{'label': '', 'price': 0})),
                  ),
                ),
                _sectionTitle(context, 'فیلدهای سفارشی فرم (اختیاری)'),
                ..._fieldEditors(context),
                Align(
                  alignment: Alignment.centerRight,
                  child: WcpButton(
                    variant: 'ghost',
                    icon: 'plus',
                    label: 'فیلد',
                    onClick: () => setState(() => _fields.add(<String, dynamic>{
                          'label': '',
                          'type': 'text',
                          'options': '',
                          'required': false,
                        })),
                  ),
                ),
                const SizedBox(height: 20),
                WcpButton(
                  variant: 'primary',
                  full: true,
                  disabled: _saving,
                  icon: 'check',
                  label: _saving ? 'در حال ذخیره…' : 'ذخیره خدمت',
                  onClick: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext ctx, String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8, right: 2),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: ctx.c.accent)),
      );

  Widget _num(BuildContext ctx, String label, String key,
      {bool isText = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WcpField(
        label: label,
        value: '${_s[key] ?? ''}',
        dir: isText ? null : TextDirection.ltr,
        onChange: (v) => setState(() {
          _s[key] = isText ? v : (int.tryParse(v.trim()) ?? 0);
        }),
      ),
    );
  }

  Widget _payModeRow(BuildContext ctx, String pay) {
    final entries = widget.payModes.isNotEmpty
        ? widget.payModes.entries.toList()
        : const [
            MapEntry('none', 'بدون پرداخت'),
            MapEntry('deposit', 'بیعانه'),
            MapEntry('fixed', 'مبلغ ثابت'),
            MapEntry('full', 'کل مبلغ'),
          ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 2),
            child: Text('نوع پرداخت',
                style: TextStyle(fontSize: 12.5, color: ctx.c.tx2)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in entries)
                WcpChip(
                  active: pay == e.key,
                  onClick: () => setState(() => _s['pay_mode'] = e.key),
                  child: Text(e.value),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _windowEditors(BuildContext ctx) {
    final c = ctx.c;
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < _windows.length; i++) {
      final Map<String, dynamic> w = _windows[i];
      final List<int> days =
          (w['days'] as List?)?.whereType<int>().toList() ?? <int>[];
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: WcpCard(
          pad: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('بازه ${Fmt.fa(i + 1)}',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                  if (_windows.length > 1)
                    InkResponse(
                      onTap: () => setState(() => _windows.removeAt(i)),
                      child: WcpIcon('trash', size: 16, color: c.error),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in _kDays)
                    WcpChip(
                      active: days.contains(d.n),
                      onClick: () => setState(() {
                        if (days.contains(d.n)) {
                          days.remove(d.n);
                        } else {
                          days.add(d.n);
                        }
                        w['days'] = days;
                      }),
                      child: Text(d.fa),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: WcpField(
                      label: 'از ساعت',
                      value: (w['start'] ?? '').toString(),
                      placeholder: '09:00',
                      dir: TextDirection.ltr,
                      onChange: (v) => w['start'] = v.trim(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: WcpField(
                      label: 'تا ساعت',
                      value: (w['end'] ?? '').toString(),
                      placeholder: '17:00',
                      dir: TextDirection.ltr,
                      onChange: (v) => w['end'] = v.trim(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ));
    }
    return out;
  }

  List<Widget> _addonEditors(BuildContext ctx) {
    final c = ctx.c;
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < _addons.length; i++) {
      final Map<String, dynamic> a = _addons[i];
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 3,
              child: WcpField(
                label: 'عنوان آپشن',
                value: (a['label'] ?? '').toString(),
                onChange: (v) => a['label'] = v,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: WcpField(
                label: 'قیمت',
                value: '${a['price'] ?? 0}',
                dir: TextDirection.ltr,
                onChange: (v) => a['price'] = int.tryParse(v.trim()) ?? 0,
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkResponse(
                onTap: () => setState(() => _addons.removeAt(i)),
                child: WcpIcon('trash', size: 16, color: c.error),
              ),
            ),
          ],
        ),
      ));
    }
    return out;
  }

  List<Widget> _fieldEditors(BuildContext ctx) {
    final c = ctx.c;
    final entries = widget.fieldTypes.isNotEmpty
        ? widget.fieldTypes.entries.toList()
        : const [
            MapEntry('text', 'متن'),
            MapEntry('number', 'عدد'),
            MapEntry('tel', 'تلفن'),
            MapEntry('select', 'انتخابی'),
          ];
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < _fields.length; i++) {
      final Map<String, dynamic> f = _fields[i];
      final String type = (f['type'] ?? 'text').toString();
      final bool hasOptions = type == 'select' || type == 'radio' || type == 'checkbox';
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: WcpCard(
          pad: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: WcpField(
                      label: 'عنوان فیلد',
                      value: (f['label'] ?? '').toString(),
                      onChange: (v) => f['label'] = v,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InkResponse(
                      onTap: () => setState(() => _fields.removeAt(i)),
                      child: WcpIcon('trash', size: 16, color: c.error),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in entries)
                    WcpChip(
                      active: type == e.key,
                      onClick: () => setState(() => f['type'] = e.key),
                      child: Text(e.value),
                    ),
                ],
              ),
              if (hasOptions) ...[
                const SizedBox(height: 8),
                WcpField(
                  label: 'گزینه‌ها (با | یا ، جدا کنید)',
                  value: (f['options'] ?? '').toString(),
                  onChange: (v) => f['options'] = v,
                ),
              ],
              const SizedBox(height: 6),
              _labeledSwitch(ctx, 'اجباری', f['required'] == true,
                  (v) => setState(() => f['required'] = v)),
            ],
          ),
        ),
      ));
    }
    return out;
  }
}
