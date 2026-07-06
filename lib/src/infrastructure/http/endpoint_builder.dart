class EndpointBuilder {
  static String stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static String _join(String base, String path) =>
      '${stripTrailingSlash(base)}$path';

  static String sendEndpoint(String base) => _join(base, '/api/send');
  static String authLogin(String base) => _join(base, '/api/auth/login');
  static String websites(String base) => _join(base, '/api/websites');
  static String website(String base, String id) =>
      _join(base, '/api/websites/$id');
  static String websiteStats(String base, String id) =>
      _join(base, '/api/websites/$id/stats');
  static String websitePageviews(String base, String id) =>
      _join(base, '/api/websites/$id/pageviews');
  static String websiteMetrics(String base, String id) =>
      _join(base, '/api/websites/$id/metrics');
  static String websiteActive(String base, String id) =>
      _join(base, '/api/websites/$id/active');
  static String websiteEvents(String base, String id) =>
      _join(base, '/api/websites/$id/events');
  static String websiteSessions(String base, String id) =>
      _join(base, '/api/websites/$id/sessions');
  static String teams(String base) => _join(base, '/api/teams');
  static String adminUsers(String base) => _join(base, '/api/admin/users');
  static String adminUser(String base, String id) =>
      _join(base, '/api/admin/users/$id');
}
