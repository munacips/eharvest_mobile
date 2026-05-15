import 'dart:async';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/models/chat_models.dart';
import 'package:eharvest_mobile/pages/chat_conversation_page.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({super.key});

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> {
  final ChatService _chatService = ChatService.instance;
  final DateFormat _timeFormat = DateFormat('MMM d, HH:mm');

  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<ChatConnectionStatus>? _connectionSubscription;

  List<ChatConversation> _conversations = const <ChatConversation>[];
  bool _isLoading = true;
  bool _isCreatingConversation = false;
  String? _errorMessage;
  int? _userId;
  int? _activeConversationId;

  @override
  void initState() {
    super.initState();
    _messageSubscription = _chatService.messages.listen(_handleIncomingMessage);
    _connectionSubscription = _chatService.connectionStatus.listen((status) {
      if (!mounted) {
        return;
      }
      if (status == ChatConnectionStatus.connected) {
        unawaited(_loadConversations(showLoader: false));
      } else if (status == ChatConnectionStatus.authExpired) {
        setState(() {
          _errorMessage = 'Your chat session expired. Please log in again.';
        });
      } else {
        setState(() {});
      }
    });
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      _userId = await AuthService.getUserId();
      await _chatService.ensureConnected();
      await _loadConversations(showLoader: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadConversations({required bool showLoader}) async {
    if (_userId == null) {
      _userId = await AuthService.getUserId();
    }
    if (_userId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Authentication required to load chat.';
        _isLoading = false;
      });
      return;
    }

    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final conversations = await _chatService.fetchConversations(userId: _userId);
      conversations.sort((a, b) {
        final aDate = a.lastMessage?.createdAt ?? a.createdAt ?? DateTime(1970);
        final bDate = b.lastMessage?.createdAt ?? b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _conversations = conversations;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _handleIncomingMessage(ChatMessage message) {
    if (!mounted) {
      return;
    }

    final index = _conversations.indexWhere(
      (conversation) => conversation.id == message.conversationId,
    );

    if (index == -1) {
      unawaited(_loadConversations(showLoader: false));
      return;
    }

    final conversation = _conversations[index];
    final unreadCount =
        message.senderId == _userId || _activeConversationId == message.conversationId
        ? 0
        : conversation.unreadCount + 1;

    final updatedConversation = conversation.copyWith(
      lastMessage: message.copyWith(isPending: false, isQueued: false),
      unreadCount: unreadCount,
    );

    final updatedList = List<ChatConversation>.from(_conversations);
    updatedList[index] = updatedConversation;
    updatedList.sort((a, b) {
      final aDate = a.lastMessage?.createdAt ?? a.createdAt ?? DateTime(1970);
      final bDate = b.lastMessage?.createdAt ?? b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    setState(() {
      _conversations = updatedList;
    });
  }

  Future<void> _openConversation(ChatConversation conversation) async {
    _activeConversationId = conversation.id;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationPage(conversation: conversation),
      ),
    );
    _activeConversationId = null;
    await _loadConversations(showLoader: false);
  }

  Future<void> _showCreateConversationDialog() async {
    final memberIdsController = TextEditingController();
    final nameController = TextEditingController();
    var isGroup = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New conversation'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: memberIdsController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'Member IDs',
                        hintText: 'Example: 12, 34',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Conversation name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Group conversation'),
                      value: isGroup,
                      onChanged: (value) {
                        setDialogState(() {
                          isGroup = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _isCreatingConversation
                      ? null
                      : () async {
                          final parsedIds = memberIdsController.text
                              .split(',')
                              .map((value) => int.tryParse(value.trim()))
                              .whereType<int>()
                              .toSet()
                              .toList();

                          if (_userId != null && !parsedIds.contains(_userId)) {
                            parsedIds.add(_userId!);
                          }

                          if (parsedIds.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter at least one other member ID.',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.of(context).pop();
                          await _createConversation(
                            memberIds: parsedIds,
                            name: nameController.text.trim(),
                            isGroup: isGroup,
                          );
                        },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    memberIdsController.dispose();
    nameController.dispose();
  }

  Future<void> _createConversation({
    required List<int> memberIds,
    required String name,
    required bool isGroup,
  }) async {
    setState(() {
      _isCreatingConversation = true;
      _errorMessage = null;
    });

    try {
      final conversation = await _chatService.createConversation(
        CreateConversationRequest(
          memberIds: memberIds,
          name: name.isEmpty ? null : name,
          isGroup: isGroup,
        ),
      );

      if (!mounted) {
        return;
      }

      await _loadConversations(showLoader: false);
      await _openConversation(conversation);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingConversation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(backgroundLight),
      body: Column(
        children: [
          _ConnectionBanner(status: _chatService.status),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadConversations(showLoader: false),
              child: _buildBody(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreatingConversation ? null : _showCreateConversationDialog,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('New chat'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _loadConversations(showLoader: true),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 72),
          Icon(Icons.forum_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No conversations yet. Start one from the button below.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final title = conversation.titleFor(_userId ?? 0);
        final preview = conversation.lastMessage?.preview ?? 'No messages yet';
        final timestamp = conversation.lastMessage?.createdAt ?? conversation.createdAt;

        return ListTile(
          onTap: () => _openConversation(conversation),
          leading: CircleAvatar(
            backgroundColor: Color(primaryColour).withValues(alpha: 0.12),
            child: Icon(
              conversation.isGroup ? Icons.groups_2_outlined : Icons.person_outline,
              color: const Color(primaryDarkColour),
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timestamp == null ? '' : _timeFormat.format(timestamp),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              if (conversation.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(primaryColour),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    conversation.unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final ChatConnectionStatus status;

  const _ConnectionBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == ChatConnectionStatus.connected ||
        status == ChatConnectionStatus.disconnected) {
      return const SizedBox.shrink();
    }

    final (Color background, String message) = switch (status) {
      ChatConnectionStatus.connecting => (
        Colors.blue.shade50,
        'Connecting to chat...',
      ),
      ChatConnectionStatus.reconnecting => (
        Colors.orange.shade50,
        'Reconnecting to chat...',
      ),
      ChatConnectionStatus.authExpired => (
        Colors.red.shade50,
        'Chat authentication expired.',
      ),
      ChatConnectionStatus.connected || ChatConnectionStatus.disconnected => (
        Colors.transparent,
        '',
      ),
    };

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(message),
    );
  }
}
