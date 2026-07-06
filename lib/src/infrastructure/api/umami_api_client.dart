import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/ports/api_port.dart';
import 'package:flutter_umami_analytics/src/domain/utils/json_helpers.dart';
import 'package:flutter_umami_analytics/src/domain/utils/safe_async.dart';
import 'package:flutter_umami_analytics/src/infrastructure/http/endpoint_builder.dart';
import 'package:flutter_umami_analytics/src/infrastructure/http/http_headers.dart';

class UmamiApiClient implements UmamiApiPort {
  static const _kStartAt = 'startAt';
  static const _kEndAt = 'endAt';
  static const _kUnit = 'unit';
  static const _kTimezone = 'timezone';
  static const _kType = 'type';
  static const _kLimit = 'limit';

  final String _baseUrl;
  final UmamiLogger _logger;
  final http.Client _client;
  final Map<String, String> _baseHeaders;
  Map<String, String> _currentHeaders;
  String? _token;
  bool _disposed = false;

  UmamiApiClient({
    required String baseUrl,
    UmamiLogger? logger,
    http.Client? client,
    String? token,
  })  : _baseUrl = EndpointBuilder.stripTrailingSlash(baseUrl),
        _logger = logger ?? const UmamiLogger(),
        _client = client ?? http.Client(),
        _baseHeaders = buildBaseHeaders(),
        _token = token,
        _currentHeaders = composeAuthHeaders(buildBaseHeaders(), token);

  @override
  bool get isAuthenticated => _token != null;

  bool _ensureAuthenticated(String op) {
    if (isAuthenticated) return true;
    _logger.warning('$op: not authenticated. Call login() first.');
    return false;
  }

  Future<http.Response?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool encodeJson = true,
  }) {
    if (_disposed) {
      _logger.warning('Attempted request after dispose: $method $path');
      return Future<http.Response?>.value(null);
    }
    final url = Uri.parse('$_baseUrl$path');
    final effectiveHeaders = headers ?? _currentHeaders;
    final encodedBody =
        body == null ? null : (encodeJson ? jsonEncode(body) : body.toString());

    Future<http.Response> invoke() => switch (method) {
          'GET' => _client.get(url, headers: effectiveHeaders),
          'DELETE' => _client.delete(url, headers: effectiveHeaders),
          'PUT' => _client.put(
              url,
              headers: effectiveHeaders,
              body: encodedBody,
            ),
          'POST' => _client.post(
              url,
              headers: effectiveHeaders,
              body: encodedBody,
            ),
          _ => throw ArgumentError.value(
              method, 'method', 'Unsupported HTTP method'),
        };

    return safeAsync<http.Response>(
      invoke,
      onError: (e) => _logger.error('$method $path error: $e'),
    );
  }

  int? _status(http.Response? response) => response?.statusCode;

  Future<http.Response?> _ensure2xx(
    Future<http.Response?> Function() send,
    String op,
  ) async {
    final response = await send();
    final code = _status(response);
    if (code != HttpStatus.ok && code != HttpStatus.noContent) {
      if (response != null) _logger.warning('$op -> $code');
    }
    return response;
  }

  Future<bool> _handleBool(
    Future<http.Response?> Function() send,
    String op,
  ) async {
    final response = await _ensure2xx(send, op);
    final code = _status(response);
    return code == HttpStatus.ok || code == HttpStatus.noContent;
  }

  @override
  Future<bool> login(String username, String password) async {
    final response = await _ensure2xx(
      () => _send(
        'POST',
        EndpointBuilder.authLogin(''),
        body: {'username': username, 'password': password},
        headers: {HttpHeaderNames.contentType: HttpContentType.json},
      ),
      'Login',
    );
    if (_status(response) != HttpStatus.ok) return false;
    final loginResponse = decodeJsonObject(response?.body);
    final token = loginResponse?['token'] as String?;
    if (token == null) return false;
    _token = token;
    _currentHeaders = composeAuthHeaders(_baseHeaders, token);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>?> getWebsites() =>
      _getList(EndpointBuilder.websites(''));

  @override
  Future<Map<String, dynamic>?> getWebsite(String id) =>
      _getMap(EndpointBuilder.website('', id));

  @override
  Future<Map<String, dynamic>?> createWebsite(Map<String, dynamic> data) =>
      _post(EndpointBuilder.websites(''), data);

  @override
  Future<bool> updateWebsite(String id, Map<String, dynamic> data) {
    final path = EndpointBuilder.website('', id);
    return _handleBool(
      () => _send('PUT', path, body: data),
      'PUT $path',
    );
  }

  @override
  Future<bool> deleteWebsite(String id) {
    final path = EndpointBuilder.website('', id);
    return _handleBool(
      () => _send('DELETE', path),
      'DELETE $path',
    );
  }

  @override
  Future<Map<String, dynamic>?> getWebsiteStats(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
  }) =>
      _getMap(_withQuery(
        EndpointBuilder.websiteStats('', id),
        {
          _kStartAt: startAt.millisecondsSinceEpoch.toString(),
          _kEndAt: endAt.millisecondsSinceEpoch.toString(),
        },
      ));

  @override
  Future<Map<String, dynamic>?> getWebsitePageviews(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  }) =>
      _getMap(_withQuery(
        EndpointBuilder.websitePageviews('', id),
        _timeRangeQuery(startAt, endAt, unit, timezone),
      ));

  @override
  Future<Map<String, dynamic>?> getWebsiteMetrics(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    required String type,
    int? limit,
  }) =>
      _getMap(
        _withQuery(
          EndpointBuilder.websiteMetrics('', id),
          {
            _kStartAt: startAt.millisecondsSinceEpoch.toString(),
            _kEndAt: endAt.millisecondsSinceEpoch.toString(),
            _kType: type,
            if (limit != null) _kLimit: limit.toString(),
          },
        ),
      );

  @override
  Future<int?> getWebsiteActiveVisitors(String id) async {
    final path = EndpointBuilder.websiteActive('', id);
    if (!_ensureAuthenticated('Get active visitors')) return null;
    final response = await _ensure2xx(
      () => _send('GET', path),
      'GET $path',
    );
    if (_status(response) != HttpStatus.ok) return null;
    final decoded = decodeJsonValue(response?.body);
    return decoded is int ? decoded : null;
  }

  @override
  Future<List<Map<String, dynamic>>?> getWebsiteEvents(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  }) =>
      _getList(_withQuery(
        EndpointBuilder.websiteEvents('', id),
        _timeRangeQuery(startAt, endAt, unit, timezone),
      ));

  @override
  Future<List<Map<String, dynamic>>?> getWebsiteSessions(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  }) =>
      _getList(_withQuery(
        EndpointBuilder.websiteSessions('', id),
        _timeRangeQuery(startAt, endAt, unit, timezone),
      ));

  @override
  Future<List<Map<String, dynamic>>?> getTeams() =>
      _getList(EndpointBuilder.teams(''));

  @override
  Future<Map<String, dynamic>?> createTeam(Map<String, dynamic> data) =>
      _post(EndpointBuilder.teams(''), data);

  @override
  Future<List<Map<String, dynamic>>?> getAllUsers() =>
      _getList(EndpointBuilder.adminUsers(''));

  @override
  Future<Map<String, dynamic>?> createUser(Map<String, dynamic> data) =>
      _post(EndpointBuilder.adminUsers(''), data);

  @override
  Future<bool> deleteUser(String id) {
    final path = EndpointBuilder.adminUser('', id);
    return _handleBool(
      () => _send('DELETE', path),
      'DELETE $path',
    );
  }

  String _withQuery(String path, Map<String, String> query) =>
      Uri(path: path, queryParameters: query).toString();

  Map<String, String> _timeRangeQuery(
    DateTime startAt,
    DateTime endAt,
    String? unit,
    String? timezone,
  ) =>
      <String, String>{
        _kStartAt: startAt.millisecondsSinceEpoch.toString(),
        _kEndAt: endAt.millisecondsSinceEpoch.toString(),
        if (unit != null) _kUnit: unit,
        if (timezone != null) _kTimezone: timezone,
      };

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required Set<int> okCodes,
    bool decodeAsObject = false,
  }) async {
    if (!_ensureAuthenticated('$method $path')) return null;
    final response = await _ensure2xx(
      () => _send(method, path, body: body),
      '$method $path',
    );
    final code = _status(response);
    if (!okCodes.contains(code)) return null;
    return decodeAsObject
        ? decodeJsonObject(response?.body)
        : decodeJsonValue(response?.body);
  }

  Future<T?> _getDecoded<T>(
    String path,
    T? Function(Object?) extract,
  ) async {
    final body = await _getRaw(path);
    if (body == null) return null;
    return extract(body);
  }

  Future<List<Map<String, dynamic>>?> _getList(String path) =>
      _getDecoded(path, _extractList);

  Future<Map<String, dynamic>?> _getMap(String path) =>
      _getDecoded(path, _extractMap);

  Future<Object?> _getRaw(String path) =>
      _request('GET', path, okCodes: {HttpStatus.ok});

  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final result = await _request(
      'POST',
      path,
      body: body,
      okCodes: {HttpStatus.ok, HttpStatus.created},
      decodeAsObject: true,
    );
    return result is Map<String, dynamic> ? result : null;
  }

  List<Map<String, dynamic>>? _extractList(Object? body) {
    if (body is List) return _castList(body.cast<Object?>());
    if (body is Map && body['data'] is List) {
      return _castList((body['data'] as List).cast<Object?>());
    }
    _logger.warning('_extractList: unexpected body type ${body.runtimeType}');
    return null;
  }

  Map<String, dynamic>? _extractMap(Object? body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) {
      final inner = body['data'];
      if (inner is Map<String, dynamic>) return inner;
    }
    _logger.warning('_extractMap: unexpected body type ${body.runtimeType}');
    return null;
  }

  List<Map<String, dynamic>> _castList(List<Object?> items) {
    final casted = <Map<String, dynamic>>[];
    for (final e in items) {
      if (e is Map<String, dynamic>) {
        casted.add(e);
      } else {
        _logger.warning(
          '_castList: dropping non-Map entry of type ${e.runtimeType}',
        );
      }
    }
    return List<Map<String, dynamic>>.unmodifiable(casted);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
}
