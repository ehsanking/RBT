// ════════════════════════════════════════════════════════════════
// shake_report.dart — Instagram-style "shake to report a bug".
//
// On a device shake (detected natively, see [Shake]) we snapshot the CURRENT
// screen with a pure-Dart RepaintBoundary (no plugin), then open a sheet with
// the screenshot preview + a text box; sending uploads both to the panel
// (PortalApi.submitErrorReport → «گزارش‌های خطا» admin inbox).
//
// Wiring (app.dart): wrap the app UI in `RepaintBoundary(key: shakeRepaintKey)`
// and host `ShakeReportHost(navigatorKey: …)` so the sheet can be shown from
// anywhere. The screenshot is captured BEFORE the sheet opens, so the report
// shows the screen the user was on — not the sheet.
// ════════════════════════════════════════════════════════════════
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/portal_api.dart';
import 'shake.dart';

/// Key on the RepaintBoundary that wraps the whole app UI (set in app.dart).
final GlobalKey shakeRepaintKey = GlobalKey();

/// App version label sent with the report — keep in sync with pubspec `version`.
const String kAppVersionLabel = '1.2.0+35';

/// User toggle for «گزارش خطا با تکان دادن» (Settings → نمایش). Default ON.
/// The host listens to this so flipping it in Settings starts/stops the
/// accelerometer immediately (no relaunch needed).
final ValueNotifier<bool> shakeReportEnabled = ValueNotifier<bool>(true);
const String _kShakeEnabled = 'shake_report_enabled';

Future<void> loadShakeReportEnabled() async {
  try {
    final SharedPreferences p = await SharedPreferences.getInstance();
    shakeReportEnabled.value = p.getBool(_kShakeEnabled) ?? true;
  } catch (_) {}
}

Future<void> setShakeReportEnabled(bool v) async {
  shakeReportEnabled.value = v;
  try {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool(_kShakeEnabled, v);
  } catch (_) {}
}

class ShakeReportHost extends StatefulWidget {
  const ShakeReportHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<ShakeReportHost> createState() => _ShakeReportHostState();
}

class _ShakeReportHostState extends State<ShakeReportHost> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    shakeReportEnabled.addListener(_applyEnabled);
    _initEnabled();
  }

  Future<void> _initEnabled() async {
    await loadShakeReportEnabled();
    _applyEnabled();
  }

  void _applyEnabled() {
    if (shakeReportEnabled.value) {
      Shake.start(_onShake);
    } else {
      Shake.stop();
    }
  }

  @override
  void dispose() {
    shakeReportEnabled.removeListener(_applyEnabled);
    Shake.stop();
    super.dispose();
  }

  Future<void> _onShake() async {
    if (_open) return;
    final BuildContext? ctx = widget.navigatorKey.currentContext;
    if (ctx == null) return;
    // Capture FIRST so the report shows the actual screen (not this sheet).
    final Uint8List? png = await _capture();
    if (png == null || !ctx.mounted) return;
    _open = true;
    try {
      await showModalBottomSheet<void>(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ReportSheet(png: png),
      );
    } finally {
      _open = false;
    }
  }

  Future<Uint8List?> _capture() async {
    try {
      final RenderObject? ro =
          shakeRepaintKey.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) return null;
      final ui.Image img = await ro.toImage(pixelRatio: 2.0);
      final ByteData? bd = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      return bd?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.png});
  final Uint8List png;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final TextEditingController _c = TextEditingController();
  bool _busy = false;
  static const Color _violet = Color(0xFF8B5CF6);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bool ok = await PortalApi.submitErrorReport(
      screenshot: widget.png,
      message: _c.text.trim(),
      appVersion: kAppVersionLabel,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        ok ? 'گزارش ارسال شد. متشکریم.' : 'ارسال گزارش ناموفق بود.',
        style: const TextStyle(fontFamily: 'Vazirmatn'),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.of(context).viewInsets.bottom;
    final ThemeData th = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: th.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
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
                  color: const Color(0x66888888),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'گزارش خطا',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'تصویر صفحه ضمیمه شد. توضیح مشکل را بنویسید.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12.5,
                color: Color(0xFF9A9A9A),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                widget.png,
                height: 190,
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              maxLines: 3,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'Vazirmatn'),
              decoration: InputDecoration(
                hintText: 'چه اتفاقی افتاد؟',
                hintStyle: const TextStyle(fontFamily: 'Vazirmatn'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'ارسال گزارش',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
