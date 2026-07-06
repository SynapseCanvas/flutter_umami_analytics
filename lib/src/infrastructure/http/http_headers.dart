import 'package:flutter_umami_analytics/src/infrastructure/device/user_agent_service.dart';

class HttpHeaderNames {
  const HttpHeaderNames._();

  static const contentType = 'Content-Type';
  static const accept = 'Accept';
  static const userAgent = 'User-Agent';
  static const authorization = 'Authorization';
  static const cacheControl = 'x-umami-cache';
}

class HttpContentType {
  const HttpContentType._();

  static const json = 'application/json';
}

class HttpStatus {
  const HttpStatus._();

  static const ok = 200;
  static const created = 201;
  static const noContent = 204;
}

Map<String, String> buildBaseHeaders({
  String? userAgent,
  String contentType = HttpContentType.json,
  String accept = HttpContentType.json,
}) {
  final ua = userAgent ?? UserAgentService.defaultUserAgent;
  return <String, String>{
    HttpHeaderNames.contentType: contentType,
    HttpHeaderNames.accept: accept,
    HttpHeaderNames.userAgent: ua,
  };
}

Map<String, String> composeAuthHeaders(
  Map<String, String> base,
  String? token,
) {
  if (token == null) return base;
  return <String, String>{
    ...base,
    HttpHeaderNames.authorization: 'Bearer $token',
  };
}
