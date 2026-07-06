import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_umami_analytics/flutter_umami_analytics.dart';

const _basePayload = UmamiPayload(website: 'w1', url: '/test');

void main() {
  group('UmamiPayload.toJson', () {
    test('pageview omits name (Umami v2 uses type=event without name)', () {
      final json = _basePayload.toJson();
      expect(json['type'], 'event');
      expect(json['payload'], containsPair('website', 'w1'));
      expect(json['payload'], containsPair('url', '/test'));
      expect((json['payload'] as Map).containsKey('name'), false);
      expect((json['payload'] as Map).containsKey('data'), false);
    });

    test('event includes name and data', () {
      final json = const UmamiPayload(
        website: 'w1',
        url: '/test',
        name: 'signup',
        data: {'plan': 'pro'},
      ).toJson();
      expect(json['type'], 'event');
      expect(json['payload']['name'], 'signup');
      expect(json['payload']['data']['plan'], 'pro');
    });

    test('includes optional fields when set', () {
      final json = const UmamiPayload(
        website: 'w1',
        url: '/test',
        hostname: 'app.com',
        language: 'en-US',
        referrer: 'https://google.com',
        screen: '1920x1080',
        title: 'Home',
        id: 'device-1',
        ipAddress: '127.0.0.1',
      ).toJson();
      final p = json['payload'];
      expect(p, isA<Map<String, dynamic>>());
      final pm = p as Map<String, dynamic>;
      expect(pm['hostname'], 'app.com');
      expect(pm['language'], 'en-US');
      expect(pm['referrer'], 'https://google.com');
      expect(pm['screen'], '1920x1080');
      expect(pm['title'], 'Home');
      expect(pm['id'], 'device-1');
      expect(pm['ip_address'], '127.0.0.1');
    });

    test('omits null optional fields', () {
      final json = _basePayload.toJson();
      final p = json['payload'];
      expect(p, isA<Map<String, dynamic>>());
      final pm = p as Map<String, dynamic>;
      expect(pm.containsKey('hostname'), false);
      expect(pm.containsKey('language'), false);
      expect(pm.containsKey('referrer'), false);
      expect(pm.containsKey('screen'), false);
      expect(pm.containsKey('title'), false);
      expect(pm.containsKey('id'), false);
      expect(pm.containsKey('ip_address'), false);
    });

    test('serializes to valid JSON', () {
      const payload = UmamiPayload(
        website: 'w1',
        url: '/test',
        data: {
          'nested': {'key': true},
        },
      );
      final encoded = jsonEncode(payload.toJson());
      expect(jsonDecode(encoded), equals(payload.toJson()));
    });

    test('all optional fields populated', () {
      final json = const UmamiPayload(
        website: 'w1',
        url: '/test',
        hostname: 'app.com',
        language: 'en-US',
        referrer: 'https://google.com',
        screen: '1920x1080',
        title: 'Home',
        name: 'signup',
        data: {'plan': 'pro'},
        id: 'device-1',
        ipAddress: '127.0.0.1',
        sessionId: 'session-1',
      ).toJson();
      final p = json['payload'];
      expect(p, isA<Map<String, dynamic>>());
      final pm = p as Map<String, dynamic>;
      expect(pm['hostname'], 'app.com');
      expect(pm['language'], 'en-US');
      expect(pm['referrer'], 'https://google.com');
      expect(pm['screen'], '1920x1080');
      expect(pm['title'], 'Home');
      expect(pm['name'], 'signup');
      expect(pm['data'], {'plan': 'pro'});
      expect(pm['id'], 'device-1');
      expect(pm['ip_address'], '127.0.0.1');
      expect(pm['session_id'], 'session-1');
    });
  });

  group('UmamiIdentifyPayload.toJson', () {
    test('identify payload wraps sessionId/data/website under type=identify',
        () {
      final json = const UmamiIdentifyPayload(
        website: 'w1',
        sessionId: 's1',
        data: {'tier': 'gold'},
      ).toJson();
      expect(json['type'], 'identify');
      expect(json['payload']['sessionId'], 's1');
      expect(json['payload']['data']['tier'], 'gold');
      expect(json['payload']['website'], 'w1');
    });

    test('omits empty data map (also UmamiPayload)', () {
      final json = const UmamiIdentifyPayload(
        website: 'w1',
        sessionId: 'test-session',
        data: {},
      ).toJson();
      final p = json['payload'];
      expect(p, isA<Map<String, dynamic>>());
      expect((p as Map<String, dynamic>).containsKey('data'), false);
    });
  });
}
