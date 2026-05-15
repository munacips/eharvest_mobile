class ChatMember {
  final int userId;
  final String fullName;
  final DateTime? joinedAt;
  final DateTime? lastReadAt;

  const ChatMember({
    required this.userId,
    required this.fullName,
    required this.joinedAt,
    required this.lastReadAt,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    return ChatMember(
      userId: int.tryParse((json['userId'] ?? json['id'] ?? 0).toString()) ?? 0,
      fullName: (json['fullName'] ?? json['name'] ?? '').toString(),
      joinedAt: _parseDateTime(json['joinedAt']),
      lastReadAt: _parseDateTime(json['lastReadAt']),
    );
  }
}

class ChatMessage {
  final int? id;
  final String localId;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final bool isPending;
  final bool isQueued;
  final bool isDeleted;

  const ChatMessage({
    required this.id,
    required this.localId,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.isPending = false,
    this.isQueued = false,
    this.isDeleted = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: int.tryParse(json['id']?.toString() ?? ''),
      localId: (json['id'] ?? json['localId'] ?? '').toString(),
      conversationId:
          int.tryParse((json['conversationId'] ?? 0).toString()) ?? 0,
      senderId: int.tryParse((json['senderId'] ?? 0).toString()) ?? 0,
      senderName: (json['senderName'] ?? json['senderFullName'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      isDeleted: json['deleted'] == true || json['isDeleted'] == true,
    );
  }

  factory ChatMessage.optimistic({
    required String localId,
    required int conversationId,
    required int senderId,
    required String senderName,
    required String content,
    required bool isQueued,
  }) {
    return ChatMessage(
      id: null,
      localId: localId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      createdAt: DateTime.now(),
      isPending: true,
      isQueued: isQueued,
    );
  }

  ChatMessage copyWith({
    int? id,
    String? localId,
    int? conversationId,
    int? senderId,
    String? senderName,
    String? content,
    DateTime? createdAt,
    bool? isPending,
    bool? isQueued,
    bool? isDeleted,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
      isQueued: isQueued ?? this.isQueued,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  String get preview => isDeleted ? 'Message deleted' : content;
}

class ChatConversation {
  final int id;
  final String name;
  final bool isGroup;
  final DateTime? createdAt;
  final List<ChatMember> members;
  final ChatMessage? lastMessage;
  final int unreadCount;

  const ChatConversation({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.createdAt,
    required this.members,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'];
    final lastMessageJson = json['lastMessage'];

    return ChatConversation(
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      name: (json['name'] ?? '').toString(),
      isGroup: json['isGroup'] == true,
      createdAt: _parseDateTime(json['createdAt']),
      members: membersJson is List
          ? membersJson
                .whereType<Map>()
                .map(
                  (member) => ChatMember.fromJson(
                    member.map(
                      (key, value) => MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList()
          : const [],
      lastMessage: _parseLastMessage(lastMessageJson, json['id']),
      unreadCount: int.tryParse((json['unreadCount'] ?? 0).toString()) ?? 0,
    );
  }

  ChatConversation copyWith({
    int? id,
    String? name,
    bool? isGroup,
    DateTime? createdAt,
    List<ChatMember>? members,
    ChatMessage? lastMessage,
    bool replaceLastMessage = false,
    int? unreadCount,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      name: name ?? this.name,
      isGroup: isGroup ?? this.isGroup,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? this.members,
      lastMessage: replaceLastMessage ? lastMessage : (lastMessage ?? this.lastMessage),
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  String titleFor(int currentUserId) {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }

    final others = members.where((member) => member.userId != currentUserId).toList();
    if (others.isEmpty && members.isNotEmpty) {
      return members.first.fullName.isNotEmpty
          ? members.first.fullName
          : 'Conversation #$id';
    }

    final label = others
        .map((member) => member.fullName.trim())
        .where((name) => name.isNotEmpty)
        .join(', ');
    return label.isNotEmpty ? label : 'Conversation #$id';
  }
}

class CreateConversationRequest {
  final List<int> memberIds;
  final String? name;
  final bool isGroup;

  const CreateConversationRequest({
    required this.memberIds,
    required this.name,
    required this.isGroup,
  });

  Map<String, dynamic> toJson() {
    return {
      'memberIds': memberIds,
      'name': name,
      'isGroup': isGroup,
    };
  }
}

class SendMessageRequest {
  final int senderId;
  final int conversationId;
  final String content;

  const SendMessageRequest({
    required this.senderId,
    required this.conversationId,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'conversationId': conversationId,
      'content': content,
    };
  }
}

ChatMessage? _parseLastMessage(dynamic raw, dynamic conversationId) {
  final resolvedConversationId =
      int.tryParse((conversationId ?? 0).toString()) ?? 0;

  if (raw is Map<String, dynamic>) {
    return ChatMessage.fromJson(raw);
  }
  if (raw is Map) {
    return ChatMessage.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return ChatMessage(
      id: null,
      localId: 'preview-$resolvedConversationId',
      conversationId: resolvedConversationId,
      senderId: 0,
      senderName: '',
      content: raw.trim(),
      createdAt: DateTime.now(),
    );
  }
  return null;
}

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw.toString())?.toLocal();
}
