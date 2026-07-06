abstract class HttpClientPort {
  Future<bool> send(String endpoint, Map<String, dynamic> body);
  String? get cacheToken;
  void dispose();
}
