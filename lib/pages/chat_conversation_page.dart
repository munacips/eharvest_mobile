import 'dart:async';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/models/chat_models.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatConversationPage extends StatefulWidget {
  final ChatConversation conversation;

  const ChatConversationPage({super.key, required this.conversation});

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final ChatService _chatService = ChatService.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DateFormat _timeFormat = DateFormat('HH:mm');

  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<ChatConnectionStatus>? _connectionSubscription;

  List<ChatMessage> _messages = const <ChatMessage>[];
  int? _userId;
  String _senderName = 'You';
  bool _isLoading = true;
  bool _isSending = false;
  bool _needsReconnectRefresh = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _messageSubscription = _chatService.messages.listen(_handleIncomingMessage);
    _connectionSubscription = _chatService.connectionStatus.listen((status) {
      if (status == ChatConnectionStatus.reconnecting) {
        _needsReconnectRefresh = true;
      } else if (status == ChatConnectionStatus.connected && _needsReconnectRefresh) {
        _needsReconnectRefresh = false;
        unawaited(_loadMessages(markRead: false));
      } else if (status == ChatConnectionStatus.authExpired && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat session expired. Please log in again.')),
        );
      }
      if (mounted) {
        setState(() {});
      }
    });
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      _userId = await AuthService.getUserId();
      _senderName = _resolveSenderName(_userId ?? 0);
      await _chatService.ensureConnected();
      await _loadMessages(markRead: true);
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

  String _resolveSenderName(int userId) {
    final self = widget.conversation.members.where((member) => member.userId == userId);
    if (self.isNotEmpty && self.first.fullName.trim().isNotEmpty) {
      return self.first.fullName.trim();
    }
    return 'You';
  }

  Future<void> _loadMessages({required bool markRead}) async {
    try {
      final messages = await _chatService.fetchMessages(widget.conversation.id);
      if (markRead) {
        await _chatService.markConversationRead(widget.conversation.id);
      }

      if (!mounted) {
        return;
      }

      final pendingMessages = _messages.where((message) => message.isPending).toList();
      final reconciled = List<ChatMessage>.from(messages);
      for (final pending in pendingMessages) {
        final hasServerCopy = reconciled.any(
          (message) =>
              message.senderId == pending.senderId &&
              message.content == pending.content &&
              message.conversationId == pending.conversationId,
        );
        if (!hasServerCopy) {
          reconciled.add(pending);
        }
      }

      reconciled.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      setState(() {
        _messages = reconciled;
        _isLoading = false;
        _errorMessage = null;
      });
      _jumpToBottom();
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
    if (message.conversationId != widget.conversation.id || !mounted) {
      return;
    }

    final index = _messages.indexWhere(
      (existing) =>
          existing.id == message.id ||
          (existing.isPending &&
              existing.senderId == message.senderId &&
              existing.content == message.content),
    );

    final nextMessages = List<ChatMessage>.from(_messages);
    if (index >= 0) {
      nextMessages[index] = message.copyWith(isPending: false, isQueued: false);
    } else {
      nextMessages.add(message);
    }
    nextMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    setState(() {
      _messages = nextMessages;
    });

    if (message.senderId != _userId) {
      unawaited(_chatService.markConversationRead(widget.conversation.id));
    }
    _jumpToBottom();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _userId == null || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final optimisticMessage = await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: _userId!,
        senderName: _senderName,
        content: content,
      );

      _messageController.clear();
      setState(() {
        _messages = List<ChatMessage>.from(_messages)..add(optimisticMessage);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      _jumpToBottom();
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
          _isSending = false;
        });
      }
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    if (message.id == null) {
      setState(() {
        _messages = _messages.where((item) => item.localId != message.localId).toList();
      });
      return;
    }

    try {
      await _chatService.deleteMessage(message.id!);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = _messages.where((item) => item.id != message.id).toList();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.conversation.titleFor(_userId ?? 0);

    return Scaffold(
      backgroundColor: const Color(backgroundLight),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(primaryColour),
      ),
      body: Column(
        children: [
          if (_chatService.status == ChatConnectionStatus.reconnecting)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text('Reconnecting. New messages will sync shortly.'),
            ),
          Expanded(child: _buildBody()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _loadMessages(markRead: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(child: Text('No messages yet.'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMine = message.senderId == _userId;
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            child: GestureDetector(
              onLongPress: isMine ? () => _showMessageActions(message) : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMine
                      ? const Color(primaryColour)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMine)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(primaryDarkColour),
                          ),
                        ),
                      ),
                    Text(
                      message.preview,
                      style: TextStyle(
                        color: isMine ? Colors.white : Colors.black87,
                        fontStyle: message.isPending ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _timeFormat.format(message.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: isMine ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        if (message.isQueued) ...[
                          const SizedBox(width: 6),
                          Text(
                            'queued',
                            style: TextStyle(
                              fontSize: 12,
                              color: isMine ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ] else if (message.isPending) ...[
                          const SizedBox(width: 6),
                          Text(
                            'sending',
                            style: TextStyle(
                              fontSize: 12,
                              color: isMine ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Write a message',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _isSending ? null : _sendMessage,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(primaryColour),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'delete') {
      await _deleteMessage(message);
    }
  }
}
