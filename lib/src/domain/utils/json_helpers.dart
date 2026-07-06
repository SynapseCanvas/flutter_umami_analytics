import 'dart:convert';

T? tryDecode<T>(String? raw, T? Function(dynamic) cast, {T? fallback}) {
  if (raw == null || raw.isEmpty) return fallback;
  try {
    final decoded = jsonDecode(raw);
    return cast(decoded) ?? fallback;
  } catch (_) {
    return fallback;
  }
}

Map<String, dynamic>? decodeJsonObject(String? raw) =>
    tryDecode<Map<String, dynamic>>(
      raw,
      (dynamic v) => v is Map<String, dynamic> ? v : null,
    );

Object? decodeJsonValue(String? raw) =>
    tryDecode<Object?>(raw, (dynamic v) => v, fallback: null);
