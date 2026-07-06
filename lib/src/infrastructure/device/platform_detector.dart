import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

enum PlatformKind { web, android, ios, macos, windows, linux, unknown }

extension PlatformKindLabel on PlatformKind {
  String get wire => name;
}

class PlatformDetector {
  static PlatformKind? _cached;

  static PlatformKind detect() {
    final cached = _cached;
    if (cached != null) return cached;

    if (kIsWeb) return _cache(PlatformKind.web);

    try {
      if (Platform.isAndroid) return _cache(PlatformKind.android);
      if (Platform.isIOS) return _cache(PlatformKind.ios);
      if (Platform.isMacOS) return _cache(PlatformKind.macos);
      if (Platform.isWindows) return _cache(PlatformKind.windows);
      if (Platform.isLinux) return _cache(PlatformKind.linux);
    } catch (_) {}

    return _cache(PlatformKind.unknown);
  }

  static PlatformKind _cache(PlatformKind kind) {
    _cached = kind;
    return kind;
  }
}
