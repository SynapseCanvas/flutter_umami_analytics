class UmamiPayload {
  final String website;
  final String url;
  final String? hostname;
  final String? language;
  final String? referrer;
  final String? screen;
  final String? title;
  final String? name;
  final Map<String, dynamic>? data;
  final String? id;
  final String? ipAddress;
  final String? sessionId;

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

  static void addIfPresent(
    Map<String, dynamic> map,
    String key,
    String? value,
  ) {
    if (value != null) map[key] = value;
  }
}

class UmamiIdentifyPayload {
  final String website;
  final String sessionId;
  final Map<String, dynamic>? data;

  const UmamiIdentifyPayload({
    required this.website,
    required this.sessionId,
    this.data,
  });

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

Map<String, dynamic> wrapPayload(String type, Map<String, dynamic> body) =>
    <String, dynamic>{
      'type': type,
      'payload': body,
    };
