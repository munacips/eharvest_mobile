import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/models/chat_models.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';

enum ChatConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  authExpired,
}

class ChatAuthException implements Exception {
  final String message;

  const ChatAuthException(this.message);

  @override
  String toString() => message;
}

class ChatApiException implements Exception {
  final String message;

  const ChatApiException(this.message);

  @override
  String toString() => message;
}

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  final http.Client _httpClient = http.Client();
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<ChatConnectionStatus> _connectionController =
      StreamController<ChatConnectionStatus>.broadcast();

  final List<_QueuedMessage> _outbox = <_QueuedMessage>[];

  StompClient? _stompClient;
  Timer? _reconnectTimer;
  ChatConnectionStatus _status = ChatConnectionStatus.disconnected;
  bool _isConnecting = false;
  bool _manualDisconnect = false;
  int _reconnectAttempt = 0;
  String? _token;
  int? _userId;

  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<ChatConnectionStatus> get connectionStatus =>
      _connectionController.stream;
  ChatConnectionStatus get status => _status;
  bool get isConnected => _status == ChatConnectionStatus.connected;

  Future<void> ensureConnected() async {
    if (_status == ChatConnectionStatus.connected || _isConnecting) {
      return;
    }

    _manualDisconnect = false;
    _setStatus(
      _reconnectAttempt > 0
          ? ChatConnectionStatus.reconnecting
          : ChatConnectionStatus.connecting,
    );
    _isConnecting = true;

    try {
      _token = await AuthService.getToken();
      _userId = await AuthService.getUserId();
      if (_token == null || _token!.isEmpty || _userId == null) {
        _setStatus(ChatConnectionStatus.authExpired);
        throw const ChatAuthException('Authentication required for chat.');
      }

      final headers = <String, String>{'Authorization': 'Bearer $_token'};
      _stompClient?.deactivate();
      _stompClient = StompClient(
        config: StompConfig.sockJS(
          url: AppConfig.chatWebSocketUrl,
          stompConnectHeaders: headers,
          webSocketConnectHeaders: headers,
          heartbeatIncoming: const Duration(seconds: 20),
          heartbeatOutgoing: const Duration(seconds: 20),
          connectionTimeout: const Duration(seconds: 12),
          beforeConnect: () async {
            _token = await AuthService.getToken();
            if (_token == null || _token!.isEmpty) {
              throw const ChatAuthException('Authentication required for chat.');
            }
          },
          onConnect: _onConnect,
          onDisconnect: (_) => _handleSocketClosed(),
          onStompError: (frame) => _handleSocketError(
            frame.body ?? frame.headers['message'] ?? 'STOMP error',
          ),
          onWebSocketError: _handleSocketError,
          onUnhandledFrame: (frame) => _handleSocketError(
            frame.body ?? 'Unhandled STOMP frame',
          ),
        ),
      );
      _stompClient!.activate();
    } catch (error) {
      _isConnecting = false;
      if (error is ChatAuthException) {
        _setStatus(ChatConnectionStatus.authExpired);
        rethrow;
      }
      _scheduleReconnect();
      rethrow;
    }
  }

  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stompClient?.deactivate();
    _stompClient = null;
    _isConnecting = false;
    _setStatus(ChatConnectionStatus.disconnected);
  }

  Future<List<ChatConversation>> fetchConversations({int? userId}) async {
    final resolvedUserId = userId ?? await _requireUserId();
    final uri = Uri.parse(
      '${api}chat/conversations',
    ).replace(queryParameters: {'userId': resolvedUserId.toString()});
    final response = await _authedRequest(() => _httpClient.get(uri, headers: _headers()));
    final payload = _decodeList(response, 'load conversations');
    return payload
        .whereType<Map>()
        .map(
          (item) => ChatConversation.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  Future<ChatConversation> createConversation(
    CreateConversationRequest request,
  ) async {
    final response = await _authedRequest(
      () => _httpClient.post(
        Uri.parse('${api}chat/conversations'),
        headers: _headers(),
        body: jsonEncode(request.toJson()),
      ),
    );
    return ChatConversation.fromJson(_decodeObject(response, 'create conversation'));
  }

  Future<List<ChatMessage>> fetchMessages(
    int conversationId, {
    int? userId,
    int? page,
    int? size,
  }) async {
    final resolvedUserId = userId ?? await _requireUserId();
    final queryParameters = <String, String>{'userId': resolvedUserId.toString()};
    if (page != null) {
      queryParameters['page'] = page.toString();
    }
    if (size != null) {
      queryParameters['size'] = size.toString();
    }

    final uri = Uri.parse(
      '${api}chat/conversations/$conversationId/messages',
    ).replace(queryParameters: queryParameters);
    final response = await _authedRequest(() => _httpClient.get(uri, headers: _headers()));
    final payload = _decodeList(response, 'load messages');
    final messages = payload
        .whereType<Map>()
        .map(
          (item) => ChatMessage.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  Future<void> markConversationRead(int conversationId, {int? userId}) async {
    final resolvedUserId = userId ?? await _requireUserId();
    final uri = Uri.parse(
      '${api}chat/conversations/$conversationId/read',
    ).replace(queryParameters: {'userId': resolvedUserId.toString()});
    await _authedRequest(() => _httpClient.post(uri, headers: _headers()));
  }

  Future<void> deleteMessage(int messageId, {int? requestingUserId}) async {
    final resolvedUserId = requestingUserId ?? await _requireUserId();
    final uri = Uri.parse(
      '${api}chat/messages/$messageId',
    ).replace(queryParameters: {'requestingUserId': resolvedUserId.toString()});
    await _authedRequest(() => _httpClient.delete(uri, headers: _headers()));
  }

  Future<ChatMessage> sendMessage({
    required int conversationId,
    required int senderId,
    required String senderName,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const ChatApiException('Message cannot be empty.');
    }

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final message = ChatMessage.optimistic(
      localId: localId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      content: trimmed,
      isQueued: !isConnected,
    );

    final request = SendMessageRequest(
      senderId: senderId,
      conversationId: conversationId,
      content: trimmed,
    );

    if (!isConnected) {
      _outbox.add(_QueuedMessage(localId: localId, request: request));
      unawaited(ensureConnected());
      return message;
    }

    _publishMessage(request);
    return message;
  }

  Future<void> refreshAuth() async {
    _token = await AuthService.getToken();
    _userId = await AuthService.getUserId();
    if (_token == null || _token!.isEmpty || _userId == null) {
      disconnect();
      _setStatus(ChatConnectionStatus.authExpired);
      throw const ChatAuthException('Authentication required for chat.');
    }

    if (isConnected || _isConnecting) {
      disconnect();
      await ensureConnected();
    }
  }

  void _onConnect(StompFrame frame) {
    _isConnecting = false;
    _reconnectAttempt = 0;
    _setStatus(ChatConnectionStatus.connected);
    _stompClient?.subscribe(
      destination: '/user/queue/messages',
      callback: (stompFrame) {
        final body = stompFrame.body;
        if (body == null || body.isEmpty) {
          return;
        }
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return;
        }
        _messageController.add(ChatMessage.fromJson(decoded));
      },
    );
    _flushOutbox();
  }

  void _flushOutbox() {
    if (!isConnected || _outbox.isEmpty) {
      return;
    }

    final pending = List<_QueuedMessage>.from(_outbox);
    _outbox.clear();
    for (final message in pending) {
      _publishMessage(message.request);
    }
  }

  void _publishMessage(SendMessageRequest request) {
    if (_stompClient == null || !isConnected) {
      _outbox.add(
        _QueuedMessage(
          localId: 'local-${DateTime.now().microsecondsSinceEpoch}',
          request: request,
        ),
      );
      _scheduleReconnect();
      return;
    }

    _stompClient!.send(
      destination: '/app/chat.send',
      headers: _token == null
          ? const <String, String>{}
          : <String, String>{'Authorization': 'Bearer $_token'},
      body: jsonEncode(request.toJson()),
    );
  }

  Future<int> _requireUserId() async {
    _userId ??= await AuthService.getUserId();
    if (_userId == null) {
      throw const ChatAuthException('Authentication required for chat.');
    }
    return _userId!;
  }

  Future<http.Response> _authedRequest(
    Future<http.Response> Function() request,
  ) async {
    _token ??= await AuthService.getToken();
    if (_token == null || _token!.isEmpty) {
      throw const ChatAuthException('Authentication required for chat.');
    }

    final response = await request();
    if (response.statusCode == 401) {
      _setStatus(ChatConnectionStatus.authExpired);
      throw const ChatAuthException('Your session has expired. Please log in again.');
    }
    return response;
  }

  Map<String, String> _headers() {
    return <String, String>{
      'Content-Type': 'application/json',
      if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
    };
  }

  Map<String, dynamic> _decodeObject(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _parseError(response, label);
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ChatApiException('Unexpected response while trying to $label.');
  }

  List<dynamic> _decodeList(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _parseError(response, label);
    }

    if (response.body.isEmpty) {
      return const <dynamic>[];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    if (decoded is Map<String, dynamic> && decoded['content'] is List<dynamic>) {
      return decoded['content'] as List<dynamic>;
    }
    throw ChatApiException('Unexpected response while trying to $label.');
  }

  Exception _parseError(http.Response response, String label) {
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

    if (response.statusCode == 401) {
      return ChatAuthException(message);
    }
    return ChatApiException(message);
  }

  void _handleSocketClosed() {
    _isConnecting = false;
    if (_manualDisconnect) {
      _setStatus(ChatConnectionStatus.disconnected);
      return;
    }
    _scheduleReconnect();
  }

  void _handleSocketError(dynamic error) {
    _isConnecting = false;
    final message = error.toString();
    if (message.contains('401') || message.toLowerCase().contains('forbidden')) {
      _setStatus(ChatConnectionStatus.authExpired);
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) {
      return;
    }
    if (_reconnectTimer?.isActive == true) {
      return;
    }

    _setStatus(ChatConnectionStatus.reconnecting);
    final seconds = min(30, max(1, 1 << min(_reconnectAttempt, 4)));
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(ensureConnected());
    });
  }

  void _setStatus(ChatConnectionStatus next) {
    _status = next;
    _connectionController.add(next);
  }
}

class _QueuedMessage {
  final String localId;
  final SendMessageRequest request;

  const _QueuedMessage({required this.localId, required this.request});
}
