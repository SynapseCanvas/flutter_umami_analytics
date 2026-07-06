import 'dart:io' show Platform;

import 'package:flutter_umami_analytics/src/infrastructure/device/platform_detector.dart';

class UserAgentService {
  static final String _cached = _buildFor(PlatformDetector.detect());

  static String get defaultUserAgent => _cached;

  static String _buildFor(PlatformKind kind) {
    switch (kind) {
      case PlatformKind.android:
        return 'Mozilla/5.0 (Linux; Android ${_osVersion()}) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.230 Mobile Safari/537.36';
      case PlatformKind.ios:
        return 'Mozilla/5.0 (iPhone; CPU iPhone OS ${_osVersion()} like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
      case PlatformKind.macos:
        return 'Mozilla/5.0 (Macintosh; Intel Mac OS X ${_osVersion()}) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15';
      case PlatformKind.windows:
        return 'Mozilla/5.0 (Windows NT ${_osVersion()}; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.230 Safari/537.36';
      case PlatformKind.linux:
        return 'Mozilla/5.0 (X11; Linux x86_64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.230 Safari/537.36';
      case PlatformKind.web:
      case PlatformKind.unknown:
        return 'Mozilla/5.0 (compatible; FlutterUmami/1.0)';
    }
  }

  static String _osVersion() {
    try {
      return Platform.operatingSystemVersion.replaceAll('.', '_');
    } catch (_) {
      return '';
    }
  }
}
