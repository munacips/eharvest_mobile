class TrackingUpdate {
  final int orderId;
  final int providerId;
  final double latitude;
  final double longitude;
  final double heading;
  final double speed;
  final DateTime? timestamp;

  const TrackingUpdate({
    required this.orderId,
    required this.providerId,
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.speed,
    this.timestamp,
  });

  factory TrackingUpdate.fromJson(Map<String, dynamic> json) {
    return TrackingUpdate(
      orderId: _readInt(json, const ['orderId', 'order_id']),
      providerId: _readInt(json, const ['providerId', 'provider_id']),
      latitude: _readDouble(json, const ['latitude']),
      longitude: _readDouble(json, const ['longitude']),
      heading: _readDouble(json, const ['heading']),
      speed: _readDouble(json, const ['speed']),
      timestamp: _readDateTime(json, const ['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'orderId': orderId,
      'providerId': providerId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }

  TrackingUpdate copyWith({
    int? orderId,
    int? providerId,
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
    DateTime? timestamp,
  }) {
    return TrackingUpdate(
      orderId: orderId ?? this.orderId,
      providerId: providerId ?? this.providerId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  static int _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) {
        return int.tryParse(value.toString()) ?? 0;
      }
    }
    return 0;
  }

  static double _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) {
        return double.tryParse(value.toString()) ?? 0;
      }
    }
    return 0;
  }

  static DateTime? _readDateTime(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) {
        return DateTime.tryParse(value.toString());
      }
    }
    return null;
  }
}
