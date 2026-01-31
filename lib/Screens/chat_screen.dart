import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;

  const ChatScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  String? _currentUserId;
  RealtimeChannel? _messagesChannel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final myAuthId = supabase.auth.currentUser?.id;
    if (myAuthId == null) {
      // Handle not logged in case
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    final profileResponse = await supabase.from('profiles').select('id').eq('auth_uid', myAuthId).single();
    if (!mounted) return;

    _currentUserId = profileResponse['id'];
    await _fetchInitialMessages();
    _subscribeToNewMessages();

    setState(() => _isLoading = false);
  }

  Future<void> _fetchInitialMessages() async {
    if (_currentUserId == null) return;
    try {
      final data = await supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$_currentUserId,receiver_id.eq.${widget.friendId}),and(sender_id.eq.${widget.friendId},receiver_id.eq.$_currentUserId)')
          .order('created_at', ascending: true);
      
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(data);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _subscribeToNewMessages() {
    if (_currentUserId == null) return;
    _messagesChannel = supabase.channel('public:messages:chat');
    _messagesChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.inFilter,
        column: 'sender_id',
        value: [_currentUserId, widget.friendId],
      ),
      callback: (payload) {
        final newMessage = payload.newRecord;
        // Ensure the message belongs to this conversation
        if ((newMessage['sender_id'] == _currentUserId && newMessage['receiver_id'] == widget.friendId) ||
            (newMessage['sender_id'] == widget.friendId && newMessage['receiver_id'] == _currentUserId)) {
          if (mounted) {
            setState(() {
              _messages.add(newMessage);
            });
          }
        }
      },
    ).subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _currentUserId == null) {
      return;
    }

    _textController.clear();

    try {
      // The subscription will handle adding the message to the UI
      await supabase.from('messages').insert({
        'sender_id': _currentUserId,
        'receiver_id': widget.friendId,
        'content': text,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: Text(widget.friendName),
        backgroundColor: const Color(0xFF192233),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('Henüz mesaj yok.', style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['sender_id'] == _currentUserId;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFF135BEC) : const Color(0xFF192233),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  message['content'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF192233),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF135BEC)),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}