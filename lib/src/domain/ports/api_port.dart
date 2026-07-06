abstract class UmamiApiPort {
  Future<bool> login(String username, String password);
  bool get isAuthenticated;
  void dispose();

  Future<List<Map<String, dynamic>>?> getWebsites();
  Future<Map<String, dynamic>?> getWebsite(String id);
  Future<Map<String, dynamic>?> createWebsite(Map<String, dynamic> data);
  Future<bool> updateWebsite(String id, Map<String, dynamic> data);
  Future<bool> deleteWebsite(String id);

  Future<Map<String, dynamic>?> getWebsiteStats(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
  });

  Future<Map<String, dynamic>?> getWebsitePageviews(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  });

  Future<Map<String, dynamic>?> getWebsiteMetrics(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    required String type,
    int? limit,
  });

  Future<int?> getWebsiteActiveVisitors(String id);

  Future<List<Map<String, dynamic>>?> getWebsiteEvents(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  });

  Future<List<Map<String, dynamic>>?> getWebsiteSessions(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  });

  Future<List<Map<String, dynamic>>?> getTeams();
  Future<Map<String, dynamic>?> createTeam(Map<String, dynamic> data);

  Future<List<Map<String, dynamic>>?> getAllUsers();
  Future<Map<String, dynamic>?> createUser(Map<String, dynamic> data);
  Future<bool> deleteUser(String id);
}
