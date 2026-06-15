// ════════════════════════════════════════════════════════════════
// native.dart — thin Dart wrapper over the `wcp/native` MethodChannel
// implemented in MainActivity.kt. Keeps the app free of pub.dev plugins
// for contacts / permissions / biometric (Iran-resilience preference);
// everything is compiled-in native code with no runtime network use.
//
// All methods are best-effort and never throw to the caller — they swallow
// PlatformException (e.g. unsupported OS) and return a safe default, so UI
// code can call them unconditionally.
// ════════════════════════════════════════════════════════════════
import 'package:flutter/services.dart';

class Native {
  static const MethodChannel _ch = MethodChannel('wcp/native');

  /// Open the system contact editor pre-filled with the customer's name +
  /// phone and a «مشتری» note. The user taps Save in the Contacts app, so no
  /// WRITE_CONTACTS permission is needed. Returns false if it couldn't launch.
  static Future<bool> saveContact({
    required String name,
    required String phone,
    String note = 'مشتری',
  }) async {
    try {
      final bool? ok = await _ch.invokeMethod<bool>('insertContact', {
        'name': name,
        'phone': phone,
        'note': note,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ask for the runtime permissions the app needs (currently
  /// POST_NOTIFICATIONS on Android 13+). Safe to call once at startup.
  static Future<void> requestStartupPermissions() async {
    try {
      await _ch.invokeMethod('requestStartupPermissions');
    } catch (_) {}
  }

  /// Whether the device can do biometric (or device-credential) auth.
  static Future<bool> biometricAvailable() async {
    try {
      final bool? v = await _ch.invokeMethod<bool>('biometricAvailable');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prompt for biometric/device-credential auth. Returns true on success.
  static Future<bool> biometricAuthenticate({
    String reason = 'برای ورود به ووکامرس+ احراز هویت کنید',
  }) async {
    try {
      final bool? v = await _ch
          .invokeMethod<bool>('biometricAuthenticate', {'reason': reason});
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Toggle the real device flashlight (torch) via CameraManager. Returns true
  /// if the hardware flash was switched; false when the device has no flash.
  static Future<bool> setTorch(bool on) async {
    try {
      final bool? v = await _ch.invokeMethod<bool>('setTorch', {'on': on});
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open the system image picker and return the chosen image as
  /// `{data: base64, mime, filename}`, or null if the user cancelled / failed.
  static Future<Map<String, String>?> pickImage() async {
    try {
      final Map<dynamic, dynamic>? m =
          await _ch.invokeMethod<Map<dynamic, dynamic>>('pickImage');
      if (m == null) return null;
      return <String, String>{
        'data': (m['data'] ?? '').toString(),
        'mime': (m['mime'] ?? 'image/jpeg').toString(),
        'filename': (m['filename'] ?? 'image.jpg').toString(),
      };
    } catch (_) {
      return null;
    }
  }

  /// Open the system file picker (any type) and return the chosen file as
  /// `{data: base64, mime, filename}`, or null if cancelled / failed.
  static Future<Map<String, String>?> pickFile() async {
    try {
      final Map<dynamic, dynamic>? m =
          await _ch.invokeMethod<Map<dynamic, dynamic>>('pickFile');
      if (m == null) return null;
      return <String, String>{
        'data': (m['data'] ?? '').toString(),
        'mime': (m['mime'] ?? 'application/octet-stream').toString(),
        'filename': (m['filename'] ?? 'file').toString(),
      };
    } catch (_) {
      return null;
    }
  }

  /// Open a local file with the system viewer (ACTION_VIEW via a FileProvider
  /// content:// URI). Returns false when no app can handle the type or it
  /// couldn't launch — the caller then falls back to a «saved» toast + path.
  static Future<bool> openFile(String path, {String? mime}) async {
    try {
      final bool? ok = await _ch.invokeMethod<bool>('openFile', {
        'path': path,
        if (mime != null) 'mime': mime,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
