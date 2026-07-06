/// Outbound port for HTTP transport (domain layer, ports).
///
/// Abstracts the single-call POST endpoint used by the concrete tracking
/// collector to push payloads to Umami. Implemented by the default HTTP
/// client in the `infrastructure` layer.
library;

/// HTTP transport contract used by the collector.
///
/// Wraps a single `POST {endpoint, body}` call and an optional
/// etag/last-modified token for conditional sends.
abstract class HttpClientPort {
  /// Sends [body] as a JSON POST to [endpoint].
  ///
  /// Returns `true` for any 2xx upstream response, `false` on transport
  /// failure, non-2xx response, or thrown error. Caller is responsible
  /// for retry / queue fallback on `false`. Async.
  Future<bool> send(String endpoint, Map<String, dynamic> body);

  /// Optional etag/last-modified token for conditional sends.
  ///
  /// Returns `null` when the adapter does not maintain cache state.
  String? get cacheToken;

  /// Closes the underlying [http.Client] and releases resources.
  ///
  /// Called from the collector's `dispose`. After this call the port
  /// must not be reused. Synchronous from the caller's perspective but
  /// may flush in the background.
  void dispose();
}
