/// Optional REST API port for the Umami v2 admin endpoints
/// (domain layer, ports).
///
/// Mirrors `/api/admin/*` and `/api/websites/*`. Implemented by the
/// Umami REST API client in the `infrastructure` layer. Distinct from the
/// tracking collector — these endpoints are management/analytics queries
/// and are not part of the `/api/send` pipeline.
library;

/// Admin/management REST contract exposed alongside the collector.
///
/// All methods are async. Two return-value conventions apply throughout:
/// - `null` = upstream responded successfully but returned no body
///   (typically a 404 or empty list).
/// - `false` = the underlying send/HTTP call failed.
///
/// Callers should call [login] first; the other calls require an
/// authenticated session and will fail otherwise.
abstract class UmamiApiPort {
  /// `POST /api/auth/login` — authenticates with [username]/[password].
  ///
  /// Returns `true` on a successful login; `false` on bad credentials or
  /// transport failure. Async.
  Future<bool> login(String username, String password);

  /// `true` after a successful `login` until `dispose` is called.
  bool get isAuthenticated;

  /// Releases the underlying HTTP client.
  ///
  /// After this call the port must not be reused. Synchronous from the
  /// caller's perspective.
  void dispose();

  /// `GET /api/websites` — lists all websites visible to the user.
  ///
  /// Returns the parsed list, or `null` when the upstream returns empty.
  Future<List<Map<String, dynamic>>?> getWebsites();

  /// `GET /api/websites/{id}` — fetches a single website by [id].
  ///
  /// Returns the parsed record, or `null` when not found / empty.
  Future<Map<String, dynamic>?> getWebsite(String id);

  /// `POST /api/websites` — creates a website with the given [data].
  ///
  /// Returns the new record, or `null` when the upstream returns empty.
  Future<Map<String, dynamic>?> createWebsite(Map<String, dynamic> data);

  /// `POST /api/websites/{id}` — updates an existing website.
  ///
  /// Returns `true` on a successful update, `false` on transport or
  /// upstream error.
  Future<bool> updateWebsite(String id, Map<String, dynamic> data);

  /// `DELETE /api/websites/{id}` — deletes a website by [id].
  ///
  /// Returns `true` on a successful delete, `false` on transport or
  /// upstream error.
  Future<bool> deleteWebsite(String id);

  /// `GET /api/websites/{id}/stats` — aggregated stats over the
  /// `startAt..endAt` window.
  ///
  /// Returns the parsed stats object, or `null` when the upstream returns
  /// empty.
  Future<Map<String, dynamic>?> getWebsiteStats(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
  });

  /// `GET /api/websites/{id}/pageviews` — pageview series over the window.
  ///
  /// Optional [unit] and [timezone] are forwarded as query parameters.
  /// Returns the parsed series, or `null` when the upstream returns empty.
  Future<Map<String, dynamic>?> getWebsitePageviews(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  });

  /// `GET /api/websites/{id}/metrics` — typed metric query over the window.
  ///
  /// [type] selects which metric; [limit] optionally caps results.
  /// Returns the parsed payload, or `null` when the upstream returns empty.
  Future<Map<String, dynamic>?> getWebsiteMetrics(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    required String type,
    int? limit,
  });

  /// `GET /api/websites/{id}/active` — currently active visitor count.
  ///
  /// Returns the integer count, or `null` when the upstream returns
  /// empty/unparseable.
  Future<int?> getWebsiteActiveVisitors(String id);

  /// `GET /api/websites/{id}/events` — event totals series over the window.
  ///
  /// Optional [unit] and [timezone] are forwarded as query parameters.
  /// Returns the parsed series, or `null` when the upstream returns empty.
  Future<List<Map<String, dynamic>>?> getWebsiteEvents(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  });

  /// `GET /api/websites/{id}/sessions` — session totals series over the
  /// window.
  ///
  /// Optional [unit] and [timezone] are forwarded as query parameters.
  /// Returns the parsed series, or `null` when the upstream returns empty.
  Future<List<Map<String, dynamic>>?> getWebsiteSessions(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  });

  /// `GET /api/admin/teams` — lists all teams visible to the user.
  ///
  /// Returns the parsed list, or `null` when the upstream returns empty.
  Future<List<Map<String, dynamic>>?> getTeams();

  /// `POST /api/admin/teams` — creates a team with the given [data].
  ///
  /// Returns the new team record, or `null` when the upstream returns
  /// empty.
  Future<Map<String, dynamic>?> createTeam(Map<String, dynamic> data);

  /// `GET /api/admin/users` — lists all users visible to the user.
  ///
  /// Returns the parsed list, or `null` when the upstream returns empty.
  Future<List<Map<String, dynamic>>?> getAllUsers();

  /// `POST /api/admin/users` — creates a user with the given [data].
  ///
  /// Returns the new user record, or `null` when the upstream returns
  /// empty.
  Future<Map<String, dynamic>?> createUser(Map<String, dynamic> data);

  /// `DELETE /api/admin/users/{id}` — deletes a user by [id].
  ///
  /// Returns `true` on a successful delete, `false` on transport or
  /// upstream error.
  Future<bool> deleteUser(String id);
}
