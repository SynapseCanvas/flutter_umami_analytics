import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/ports/http_client_port.dart';
import 'package:flutter_umami_analytics/src/infrastructure/http/http_headers.dart';

class DefaultHttpClient implements HttpClientPort {
  static const _kHttpOk = HttpStatus.ok;
  static const _kBodySnippetMax = 200;
  static const _kCacheHeader = HttpHeaderNames.cacheControl;

  final http.Client _client;
  final bool _ownsClient;
  final UmamiLogger _logger;
  final Duration _timeout;
  final Map<String, String> _baseHeaders;
  String? _lastCacheToken;

  DefaultHttpClient({
    http.Client? client,
    required UmamiLogger logger,
    Duration timeout = const Duration(seconds: 5),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _logger = logger,
        _timeout = timeout,
        _baseHeaders = buildBaseHeaders();

  @override
  Future<bool> send(String endpoint, Map<String, dynamic> body) async {
    final stopwatch = Stopwatch()..start();
    try {
      final headers = _buildHeaders();
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode != _kHttpOk) {
        _logNon200(endpoint, response);
        return false;
      }

      final cache = response.headers[_kCacheHeader];
      if (cache != null && cache.isNotEmpty) _lastCacheToken = cache;
      return true;
    } on SocketException catch (e) {
      _logError(endpoint, 'Network', e.message, stopwatch.elapsedMilliseconds,
          osErrorCode: e.osError?.errorCode);
      return false;
    } on Exception catch (e) {
      final isHttp = e is HttpException;
      final kind = isHttp
          ? 'HTTP'
          : e is FormatException
              ? 'Encoding'
              : 'Request';
      _logError(endpoint, kind, '$e', stopwatch.elapsedMilliseconds,
          severe: !isHttp);
      return false;
    } finally {
      stopwatch.stop();
    }
  }

  @override
  String? get cacheToken => _lastCacheToken;

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Map<String, String> _buildHeaders() {
    final token = _lastCacheToken;
    if (token == null) return _baseHeaders;
    return <String, String>{..._baseHeaders, _kCacheHeader: token};
  }

  void _logError(
    String endpoint,
    String kind,
    String message,
    int elapsedMs, {
    int? osErrorCode,
    bool severe = false,
  }) {
    final suffix = osErrorCode != null ? ' ($osErrorCode)' : '';
    final formatted =
        '$kind error on $endpoint after ${elapsedMs}ms$suffix: $message';
    if (severe) {
      _logger.error(formatted);
    } else {
      _logger.warning(formatted);
    }
  }

  void _logNon200(String endpoint, http.Response response) {
    final body = response.body;
    final snippet = body.length > _kBodySnippetMax
        ? '${body.substring(0, _kBodySnippetMax)}…'
        : body;
    _logger.warning('POST $endpoint -> ${response.statusCode}: $snippet');
  }
}
