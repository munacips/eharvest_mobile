import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/models/tracking_update.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';

enum TrackingConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  authExpired,
}

class TrackingServiceException implements Exception {
  final String message;

  const TrackingServiceException(this.message);

  @override
  String toString() => message;
}

class TrackingService {
  TrackingService._();

  static final http.Client _httpClient = http.Client();

  static Future<TrackingUpdate?> fetchLastKnownLocation(int orderId) async {
    final response = await _authedRequest(
      () async => _httpClient.get(
        Uri.parse('${api}tracking/$orderId'),
        headers: await _headers(),
      ),
    );

    if (response.statusCode == 404 || response.body.trim().isEmpty) {
      return null;
    }

    final decoded = _decodeObject(
      response,
      'load the latest tracking location',
      allowNotFound: true,
    );
    if (decoded == null || decoded.isEmpty) {
      return null;
    }
    return TrackingUpdate.fromJson(decoded);
  }

  static Future<void> publishLocation(TrackingUpdate update) async {
    final response = await _authedRequest(
      () async => _httpClient.post(
        Uri.parse('${api}tracking/location'),
        headers: await _headers(),
        body: jsonEncode(update.toJson()..remove('timestamp')),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _parseError(response, 'publish the latest driver location');
    }
  }

  static Future<bool> ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  static Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
  }

  static OrderTrackingSubscription subscribeToOrderTracking({
    required int orderId,
    required void Function(TrackingUpdate update) onLocation,
    void Function(TrackingConnectionStatus status)? onStatusChanged,
    void Function(String message)? onError,
  }) {
    return OrderTrackingSubscription(
      orderId: orderId,
      onLocation: onLocation,
      onStatusChanged: onStatusChanged,
      onError: onError,
    )..connect();
  }

  static Future<http.Response> _authedRequest(
    Future<http.Response> Function() request,
  ) async {
    final response = await request();
    if (response.statusCode == 401) {
      throw const TrackingServiceException(
        'Your session has expired. Please log in again.',
      );
    }
    return response;
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw const TrackingServiceException('Authentication required.');
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic>? _decodeObject(
    http.Response response,
    String label, {
    bool allowNotFound = false,
  }) {
    if (allowNotFound && response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _parseError(response, label);
    }
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    throw TrackingServiceException('Unexpected response while trying to $label.');
  }

  static TrackingServiceException _parseError(http.Response response, String label) {
    var message = 'Failed to $label (${response.statusCode}).';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final candidate =
            decoded['message'] ?? decoded['error'] ?? decoded['details'];
        if (candidate != null && candidate.toString().trim().isNotEmpty) {
          message = candidate.toString().trim();
        }
      }
    } catch (_) {}
    return TrackingServiceException(message);
  }
}

class OrderTrackingSubscription {
  OrderTrackingSubscription({
    required this.orderId,
    required this.onLocation,
    this.onStatusChanged,
    this.onError,
  });

  final int orderId;
  final void Function(TrackingUpdate update) onLocation;
  final void Function(TrackingConnectionStatus status)? onStatusChanged;
  final void Function(String message)? onError;

  StompClient? _stompClient;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;
  bool _isConnecting = false;
  int _reconnectAttempt = 0;
  String? _token;
  TrackingConnectionStatus _status = TrackingConnectionStatus.disconnected;

  TrackingConnectionStatus get status => _status;

  Future<void> connect() async {
    if (_isConnecting || _status == TrackingConnectionStatus.connected) {
      return;
    }

    _manualDisconnect = false;
    _isConnecting = true;
    _setStatus(
      _reconnectAttempt > 0
          ? TrackingConnectionStatus.reconnecting
          : TrackingConnectionStatus.connecting,
    );

    try {
      _token = await AuthService.getToken();
      if (_token == null || _token!.isEmpty) {
        throw const TrackingServiceException('Authentication required.');
      }

      final headers = <String, String>{'Authorization': 'Bearer $_token'};
      _stompClient?.deactivate();
      _stompClient = StompClient(
        config: StompConfig.sockJS(
          url: AppConfig.trackingWebSocketUrl,
          stompConnectHeaders: headers,
          webSocketConnectHeaders: headers,
          heartbeatIncoming: const Duration(seconds: 20),
          heartbeatOutgoing: const Duration(seconds: 20),
          connectionTimeout: const Duration(seconds: 12),
          beforeConnect: () async {
            _token = await AuthService.getToken();
            if (_token == null || _token!.isEmpty) {
              throw const TrackingServiceException('Authentication required.');
            }
          },
          onConnect: _onConnect,
          onDisconnect: (_) => _handleSocketClosed(),
          onStompError: (frame) => _handleSocketError(
            frame.body ?? frame.headers['message'] ?? 'Tracking socket error',
          ),
          onWebSocketError: _handleSocketError,
          onUnhandledFrame: (frame) => _handleSocketError(
            frame.body ?? 'Unhandled tracking frame',
          ),
        ),
      );
      _stompClient!.activate();
    } catch (error) {
      _isConnecting = false;
      if (error is TrackingServiceException &&
          error.message.toLowerCase().contains('authentication')) {
        _setStatus(TrackingConnectionStatus.authExpired);
      } else {
        _scheduleReconnect();
      }
      onError?.call(error.toString());
    }
  }

  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stompClient?.deactivate();
    _stompClient = null;
    _isConnecting = false;
    _setStatus(TrackingConnectionStatus.disconnected);
  }

  void reconnectNow() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stompClient?.deactivate();
    _stompClient = null;
    _reconnectAttempt = 0;
    unawaited(connect());
  }

  void _onConnect(StompFrame frame) {
    _isConnecting = false;
    _reconnectAttempt = 0;
    _setStatus(TrackingConnectionStatus.connected);
    _stompClient?.subscribe(
      destination: '/topic/tracking/$orderId',
      callback: (stompFrame) {
        final body = stompFrame.body;
        if (body == null || body.trim().isEmpty) {
          return;
        }
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            onLocation(TrackingUpdate.fromJson(decoded));
            return;
          }
          if (decoded is Map) {
            onLocation(
              TrackingUpdate.fromJson(
                decoded.map((key, value) => MapEntry(key.toString(), value)),
              ),
            );
          }
        } catch (error) {
          onError?.call('Unable to parse live tracking update.');
        }
      },
    );
  }

  void _handleSocketClosed() {
    _isConnecting = false;
    if (_manualDisconnect) {
      _setStatus(TrackingConnectionStatus.disconnected);
      return;
    }
    _scheduleReconnect();
  }

  void _handleSocketError(dynamic error) {
    _isConnecting = false;
    final message = error.toString();
    if (message.contains('401') || message.toLowerCase().contains('forbidden')) {
      _setStatus(TrackingConnectionStatus.authExpired);
      onError?.call('Authentication expired for live tracking.');
      return;
    }
    onError?.call(message);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) {
      return;
    }
    if (_reconnectTimer?.isActive == true) {
      return;
    }

    _setStatus(TrackingConnectionStatus.reconnecting);
    final seconds = min(30, max(1, 1 << min(_reconnectAttempt, 4)));
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(connect());
    });
  }

  void _setStatus(TrackingConnectionStatus next) {
    _status = next;
    onStatusChanged?.call(next);
  }
}
