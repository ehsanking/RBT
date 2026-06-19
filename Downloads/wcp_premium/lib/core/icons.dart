// ════════════════════════════════════════════════════════════════
// icons.dart — Icon library ported verbatim from helpers.jsx PATHS.
// ~90 stroke-based 24×24 SVG paths + WcpIcon (CustomPaint renderer).
// Stroke when fill==false (round cap/join, strokeWidth sw); else fill.
// "currentColor" resolves to passed `color` or the nearest
// DefaultTextStyle color. viewBox 24×24 scaled to `size`.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

/// All ~90 SVG path strings, copied VERBATIM from helpers.jsx `PATHS`.
const Map<String, String> kIconPaths = {
  'home': 'M3 10.5 12 3l9 7.5M5 9.5V20a1 1 0 0 0 1 1h4v-6h4v6h4a1 1 0 0 0 1-1V9.5',
  'orders': 'M6 2h9l4 4v14a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1ZM14 2v5h5M8.5 12h7M8.5 16h7',
  'products': 'M21 8 12 3 3 8l9 5 9-5ZM3 8v8l9 5 9-5V8M12 13v8',
  'modules': 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z',
  'more': 'M4 7h16M4 12h16M4 17h10',
  'search': 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM21 21l-4.3-4.3',
  'bell': 'M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0',
  'scan': 'M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2M7 12h10',
  'plus': 'M12 5v14M5 12h14',
  'minus': 'M5 12h14',
  'chevronL': 'M15 5l-7 7 7 7',
  'chevronR': 'M9 5l7 7-7 7',
  'chevronD': 'M6 9l6 6 6-6',
  'chevronU': 'M6 15l6-6 6 6',
  'arrowUp': 'M12 19V5M6 11l6-6 6 6',
  'arrowDown': 'M12 5v14M6 13l6 6 6-6',
  'trendUp': 'M3 17 9 11l4 4 8-8M21 7v5h-5',
  'trendDown': 'M3 7l6 6 4-4 8 8M21 17v-5h-5',
  'wallet': 'M3 7a2 2 0 0 1 2-2h13a1 1 0 0 1 1 1v2M3 7v10a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1v-3M3 7h16M21 11h-4a2 2 0 0 0 0 4h4v-4Z',
  'gift': 'M20 12v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-8M2 7h20v5H2zM12 21V7M12 7S10.5 3 8 3 5 7 8 7M12 7s1.5-4 4-4 1 4-2 4',
  'coupon': 'M3 9a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2 2 2 0 0 0 0 4 2 2 0 0 1-2 2H5a2 2 0 0 1-2-2 2 2 0 0 0 0-4ZM9 8v8',
  'megaphone': 'M3 11v2a1 1 0 0 0 1 1h2l8 5V6L6 11H4a1 1 0 0 0-1 1ZM18 8a4 4 0 0 1 0 8',
  'store': 'M4 9V6h16v3M4 9l-1-3h18l-1 3M4 9a2 2 0 0 0 4 0 2 2 0 0 0 4 0 2 2 0 0 0 4 0 2 2 0 0 0 4 0M5 11v9h14v-9',
  'truck': 'M3 6a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v9H3zM14 9h3l3 3v3h-6M7 19a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM18 19a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z',
  'users': 'M16 20v-1a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v1M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM22 20v-1a4 4 0 0 0-3-3.8M16 3.2A4 4 0 0 1 16 11',
  'user': 'M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z',
  'sparkles': 'M12 3l1.8 4.7L18 9.5l-4.2 1.8L12 16l-1.8-4.7L6 9.5l4.2-1.8ZM18 14l.9 2.3 2.1.9-2.1.9L18 21l-.9-2.3-2.1-.9 2.1-.9ZM5 14l.7 1.8L7.5 16.5l-1.8.7L5 19l-.7-1.8L2.5 16.5l1.8-.7Z',
  'bolt': 'M13 2 4 14h7l-1 8 9-12h-7z',
  'shield': 'M12 3 5 6v5c0 4.5 3 8 7 10 4-2 7-5.5 7-10V6z',
  'gauge': 'M12 13l4-4M21 12a9 9 0 1 0-18 0M3 12h2M19 12h2M12 5V3',
  'filter': 'M3 5h18l-7 8v6l-4-2v-4z',
  'sort': 'M3 6h12M3 12h9M3 18h6M17 7v11M17 18l3-3M17 18l-3-3',
  'dots': 'M12 6h.01M12 12h.01M12 18h.01',
  'check': 'M5 12l5 5 9-10',
  'checkCircle': 'M22 11.5A10 10 0 1 1 12 2M8 12l3 3 7-7',
  'x': 'M6 6l12 12M18 6 6 18',
  'alert': 'M12 3 2 20h20zM12 9v5M12 17.5h.01',
  'info': 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20ZM12 11v5M12 7.5h.01',
  'refresh': 'M3 12a9 9 0 0 1 15-6.7L21 8M21 3v5h-5M21 12a9 9 0 0 1-15 6.7L3 16M3 21v-5h5',
  'share': 'M4 12v7a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-7M16 6l-4-4-4 4M12 2v13',
  'printer': 'M6 9V3h12v6M6 18H4a1 1 0 0 1-1-1v-5a1 1 0 0 1 1-1h16a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-2M6 14h12v7H6z',
  'phone': 'M5 3h4l2 5-3 2a12 12 0 0 0 5 5l2-3 5 2v4a1 1 0 0 1-1 1A16 16 0 0 1 4 4a1 1 0 0 1 1-1Z',
  'message': 'M21 12a8 8 0 0 1-11.5 7.2L3 21l1.8-6.5A8 8 0 1 1 21 12Z',
  // Rounded chat bubble with three dots — a friendlier «live chat» glyph for the FAB.
  'chatDots': 'M4 5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H9l-4 4v-4a2 2 0 0 1-1-1.7ZM8.5 9.5h.01M12 9.5h.01M15.5 9.5h.01',
  // Curved reply arrow — the canned-replies quick-reply button in the composer.
  'reply': 'M9 17l-5-5 5-5M4 12h9a7 7 0 0 1 7 7v1',
  // Envelope — customer email row + the header contact hint.
  'email': 'M3 7a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM3.5 7l8.5 6 8.5-6',
  // Download — arrow into a tray (save file / voice to device Downloads).
  'download': 'M12 3v12M7 11l5 5 5-5M4 19h16',
  'camera': 'M3 8a2 2 0 0 1 2-2h2l1.5-2h7L17 6h2a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z',
  'image': 'M3 5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM3 16l5-5 4 4 3-3 6 6M9 9a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z',
  'edit': 'M4 20h4L19 9l-4-4L4 16zM14 6l4 4',
  'trash': 'M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13',
  'star': 'M12 3l2.6 5.8 6.4.6-4.8 4.3 1.4 6.3L12 17l-5.6 3 1.4-6.3L3 9.4l6.4-.6z',
  'tag': 'M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9zM7.5 7.5h.01',
  'calendar': 'M4 6a1 1 0 0 1 1-1h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1zM4 10h16M8 3v4M16 3v4',
  'clock': 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20ZM12 7v5l3 2',
  'eye': 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7ZM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z',
  'eyeOff': 'M3 3l18 18M10.5 5.2A10 10 0 0 1 12 5c6 0 10 7 10 7a17 17 0 0 1-3 3.6M6.5 6.6A17 17 0 0 0 2 12s4 7 10 7a10 10 0 0 0 3.5-.6M9.9 9.9a3 3 0 0 0 4.2 4.2',
  'lock': 'M5 11a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1zM8 10V7a4 4 0 0 1 8 0v3',
  'fingerprint': 'M12 11v3a4 4 0 0 1-1 3M8 11a4 4 0 0 1 8 0v2M5 12a7 7 0 0 1 11.5-5.4M12 7a4 4 0 0 0-4 4M19 13a13 13 0 0 1-.7 4M15 13v1a8 8 0 0 1-1 4',
  'faceid': 'M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M9 9v1M15 9v1M12 9v3l-1 1M9 15s1 1.5 3 1.5S15 15 15 15',
  'qr': 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2v2h-2zM18 14h2M14 18v2M18 18h2v2h-2',
  'sun': 'M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10ZM12 1v3M12 20v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M1 12h3M20 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1',
  'moon': 'M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z',
  'settings': 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM19.4 13.5l2 1.2-2 3.5-2.3-.9a7.6 7.6 0 0 1-1.6.9l-.4 2.3h-4l-.4-2.3a7.6 7.6 0 0 1-1.6-.9l-2.3.9-2-3.5 2-1.2a7.6 7.6 0 0 1 0-1.9l-2-1.2 2-3.5 2.3.9a7.6 7.6 0 0 1 1.6-.9l.4-2.3h4l.4 2.3a7.6 7.6 0 0 1 1.6.9l2.3-.9 2 3.5-2 1.2a7.6 7.6 0 0 1 0 1.9Z',
  'percent': 'M19 5 5 19M7.5 9a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3ZM16.5 18a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z',
  'layers': 'M12 2 2 7l10 5 10-5zM2 12l10 5 10-5M2 17l10 5 10-5',
  'globe': 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20ZM2 12h20M12 2a15 15 0 0 1 0 20 15 15 0 0 1 0-20Z',
  // Instagram glyph (rounded square + camera circle + top-right dot), stroke-based.
  'instagram': 'M7 4h10a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3V7a3 3 0 0 1 3-3z'
      'M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0z'
      'M17.5 6.6h0.01',
  'send': 'M22 2 11 13M22 2l-7 20-4-9-9-4z',
  'clip': 'M21 11.5 12 20.5a5 5 0 0 1-7-7l8.5-8.5a3 3 0 0 1 4.5 4.5L9.5 18a1.5 1.5 0 0 1-2-2l7.5-7.5',
  'mic': 'M12 3a3 3 0 0 1 3 3v6a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3ZM5 11a7 7 0 0 0 14 0M12 18v3',
  'stop': 'M7 7h10v10H7z',
  'play': 'M8 5l11 7-11 7z',
  'pause': 'M9 5v14M15 5v14',
  'file': 'M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9zM14 3v6h6',
  'card': 'M3 7a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM3 10h18M7 15h4',
  'power': 'M12 4v8M7.5 6.5a7 7 0 1 0 9 0',
  'database': 'M12 8c5 0 8-1.3 8-3s-3-3-8-3-8 1.3-8 3 3 3 8 3ZM4 5v6c0 1.7 3 3 8 3s8-1.3 8-3V5M4 11v6c0 1.7 3 3 8 3s8-1.3 8-3v-6',
  'seo': 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14ZM21 21l-5-5M8 11h6M8 8h6M8 14h3',
  'link': 'M9 15l6-6M10.5 6.5 12 5a4 4 0 0 1 6 6l-1.5 1.5M13.5 17.5 12 19a4 4 0 0 1-6-6l1.5-1.5',
  'coin': 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20ZM12 7v10M14.5 9.2A2.5 2 0 0 0 12 8c-1.4 0-2.5.7-2.5 1.8s1.1 1.7 2.5 1.7 2.5.6 2.5 1.7-1.1 1.8-2.5 1.8a2.5 2 0 0 1-2.5-1.2',
  'chartBar': 'M3 21h18M7 21V11M12 21V5M17 21v-7',
  'location': 'M12 22s7-6.3 7-12a7 7 0 1 0-14 0c0 5.7 7 12 7 12ZM12 12a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z',
  'devices': 'M3 6a1 1 0 0 1 1-1h11a1 1 0 0 1 1 1v3M3 6v8a1 1 0 0 0 1 1h7M16 11h3a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1h-3a1 1 0 0 1-1-1v-7a1 1 0 0 1 1-1ZM8 19h3',
  'logout': 'M15 4h3a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-3M10 12H3M3 12l3-3M3 12l3 3',
  'help': 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20ZM9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.8.4-1 .9-1 1.7M12 17h.01',
  'crown': 'M3 7l4 4 5-7 5 7 4-4-2 12H5zM5 19h14',
  'heart': 'M12 20s-7-4.6-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.4-7 10-7 10Z',
  'package': 'M21 8 12 3 3 8v8l9 5 9-5zM3 8l9 5 9-5M12 13v8',
  'online': 'M12 12a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM6 18a6 6 0 0 1 12 0',
  'droplet': 'M12 3s6 5.7 6 10a6 6 0 0 1-12 0c0-4.3 6-10 6-10Z',
  'grid2': 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
  'list': 'M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01',
  'flame': 'M12 22a7 7 0 0 0 7-7c0-3-2-5-3-7-1 1.5-2 2-3 2 0-3-1-5-3-7 0 4-5 5-5 12a7 7 0 0 0 7 7Z',
  'slider': 'M4 8h10M18 8h2M4 16h2M10 16h10M14 6v4M6 14v4',
  'inbox': 'M4 13l2.5-8h11L20 13M4 13v6a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-6M4 13h5l1 2h4l1-2h5',
  'ticketSupport': 'M21 8v-.5A1.5 1.5 0 0 0 19.5 6h-15A1.5 1.5 0 0 0 3 7.5V8a2 2 0 0 1 0 4v.5A1.5 1.5 0 0 0 4.5 14M21 16v.5a1.5 1.5 0 0 1-1.5 1.5M9 14a3 3 0 1 0 6 0',
  'growth': 'M3 3v18h18M7 14l3-4 4 3 5-7',
  'eye2': 'M12 5C6 5 2 12 2 12s4 7 10 7 10-7 10-7-4-7-10-7Z',
};

/// Renders a [kIconPaths] entry by [name] via [CustomPaint].
///
/// - Strokes when [fill] is false (round cap/join, width [sw]);
///   fills otherwise.
/// - The drawing color is [color] when given, else the nearest
///   [DefaultTextStyle] color (the "currentColor" of the JSX original),
///   falling back to [AppColors.tx1]/black.
/// - SVG viewBox is 24×24, uniformly scaled to a [size]×[size] box.
class WcpIcon extends StatelessWidget {
  final String name;
  final double size;
  final double sw;
  final bool fill;
  final Color? color;
  final double opacity;

  const WcpIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.sw = 1.7,
    this.fill = false,
    this.color,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final data = kIconPaths[name];
    // "currentColor": passed color, else inherited text color.
    final resolved = color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF000000);
    final paintColor =
        opacity >= 1 ? resolved : resolved.withValues(alpha: opacity.clamp(0.0, 1.0));

    if (data == null || data.isEmpty) {
      return SizedBox(width: size, height: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _IconPainter(
          data: data,
          color: paintColor,
          sw: sw,
          fill: fill,
        ),
      ),
    );
  }
}

/// True when [d] encloses a 2D area that a fill can actually paint.
///
/// Some glyphs (e.g. the `more` hamburger `M4 7h16M4 12h16M4 17h10`, or
/// `minus`) are made of OPEN line segments only — filling them paints
/// nothing, so an active/selected state that requests `fill: true` makes the
/// icon vanish (this is exactly the dark-mode «بیشتر» tab bug). Such paths use
/// only move/horizontal/vertical/line commands with no close (`Z`) and no
/// curve/arc. A genuine fillable shape always carries at least one close
/// command or a curve/arc command (`C S Q T A`, any case). We use that as the
/// fillability test and fall back to stroking when it fails, so every truly
/// closed glyph still fills identically while line glyphs stay visible.
bool _pathIsFillable(String d) =>
    RegExp(r'[ZzCcSsQqTtAa]').hasMatch(d);

class _IconPainter extends CustomPainter {
  final String data;
  final Color color;
  final double sw;
  final bool fill;

  _IconPainter({
    required this.data,
    required this.color,
    required this.sw,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = parseSvgPathData(data);
    // viewBox 24×24 → scale uniformly to the target box.
    final double scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Fill only when the glyph actually encloses area; otherwise stroke even if
    // `fill` was requested, so open-line icons (more/minus) never disappear.
    final bool doFill = fill && _pathIsFillable(data);

    final paint = Paint()..color = color;
    if (doFill) {
      paint
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
    } else {
      paint
        ..style = PaintingStyle.stroke
        // Keep visual stroke width constant after the canvas scale.
        ..strokeWidth = sw / scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) =>
      old.data != data ||
      old.color != color ||
      old.sw != sw ||
      old.fill != fill;
}
