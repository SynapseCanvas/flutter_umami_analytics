/// Payload models that mirror the Umami `/api/send` wire format.
///
/// Part of the domain layer (pure Dart, no Flutter, no http, no sqflite).
library;

/// Represents a single analytics event sent to Umami's `/api/send` endpoint.
///
/// Covers both pageviews (when [name] is null) and named events (when [name]
/// is set). Owns no I/O; serialization happens via [toJson] which emits the
/// envelope produced by [wrapPayload]. Layer: domain (pure Dart).
class UmamiPayload {
  /// Umami website identifier the event is attributed to.
  final String website;

  /// Fully qualified URL where the event occurred.
  final String url;

  /// Optional hostname override; falls back to the value derived from [url].
  final String? hostname;

  /// Optional ISO language tag (e.g. `en-US`) sent as the event language.
  final String? language;

  /// Optional referring URL; only attached to the first pageview when
  /// consumed via [FlutterUmamiConfig.firstReferrer].
  final String? referrer;

  /// Optional screen size string (e.g. `1920x1080`).
  final String? screen;

  /// Optional page title; usually set by the [UmamiNavigatorObserver].
  final String? title;

  /// Optional event name; when non-null marks the payload as a named event
  /// rather than a pageview.
  final String? name;

  /// Optional arbitrary custom data attached to the event.
  final Map<String, dynamic>? data;

  /// Optional caller-supplied event id used for client-side de-duplication.
  final String? id;

  /// Optional IP override; when null, Umami infers it from the request.
  final String? ipAddress;

  /// Optional session id; when null the server groups events by session.
  final String? sessionId;

  /// Builds a payload. [website] and [url] are required; every other field is
  /// optional and only included in [toJson] when populated.
  const UmamiPayload({
    required this.website,
    required this.url,
    this.hostname,
    this.language,
    this.referrer,
    this.screen,
    this.title,
    this.name,
    this.data,
    this.id,
    this.ipAddress,
    this.sessionId,
  });

  /// Serializes to the Umami wire envelope `{type: 'event', payload: {...}}`
  /// via [wrapPayload]. Null optional fields are omitted from the body.
  Map<String, dynamic> toJson() => wrapPayload('event', _buildFields());

  Map<String, dynamic> _buildFields() {
    final data = this.data;
    final fields = <String, dynamic>{
      'website': website,
      'url': url,
    };
    addIfPresent(fields, 'hostname', hostname);
    addIfPresent(fields, 'language', language);
    addIfPresent(fields, 'referrer', referrer);
    addIfPresent(fields, 'screen', screen);
    addIfPresent(fields, 'title', title);
    addIfPresent(fields, 'name', name);
    if (data != null && data.isNotEmpty) fields['data'] = data;
    addIfPresent(fields, 'id', id);
    addIfPresent(fields, 'ip_address', ipAddress);
    addIfPresent(fields, 'session_id', sessionId);
    return fields;
  }

  /// Inserts [value] into [map] under [key] only when [value] is non-null;
  /// used by [toJson] to keep the wire body compact.
  static void addIfPresent(
    Map<String, dynamic> map,
    String key,
    String? value,
  ) {
    if (value != null) map[key] = value;
  }
}

/// Represents the payload of a `identify` call binding custom data to a
/// session. Layer: domain (pure Dart).
class UmamiIdentifyPayload {
  /// Umami website identifier the identify call targets.
  final String website;

  /// Session id issued (or reused) by [FlutterUmamiAnalytics.identify].
  final String sessionId;

  /// Optional custom data to associate with the session.
  final Map<String, dynamic>? data;

  /// Builds an identify payload. [website] and [sessionId] are required;
  /// [data] is optional and only serialized when non-empty.
  const UmamiIdentifyPayload({
    required this.website,
    required this.sessionId,
    this.data,
  });

  /// Serializes to the envelope `{type: 'identify', payload: {...}}` via
  /// [wrapPayload]. Null/empty [data] is omitted from the body.
  Map<String, dynamic> toJson() {
    final data = this.data;
    return wrapPayload(
      'identify',
      <String, dynamic>{
        'website': website,
        'sessionId': sessionId,
        if (data != null && data.isNotEmpty) 'data': data,
      },
    );
  }
}

/// Wraps [body] under a `{type, payload}` envelope as expected by the Umami
/// `/api/send` endpoint. [type] is the event kind (`event`, `identify`, …).
Map<String, dynamic> wrapPayload(String type, Map<String, dynamic> body) =>
    <String, dynamic>{
      'type': type,
      'payload': body,
    };
