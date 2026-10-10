import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/logistics.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/logistics_service.dart';
import '../widgets/logistics_ui.dart';

class ChatConversationScreen extends StatefulWidget {
  final ChatContact contact;

  const ChatConversationScreen({super.key, required this.contact});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _bodyController = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  Timer? _poller;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  int get _lastId => _messages.isEmpty ? 0 : _messages.last.id;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    // Same 5s polling as the web chat.
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _bodyController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final messages = await LogisticsService.getMessages(widget.contact.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _error = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _poll() async {
    if (_loading) return;
    try {
      final newer = await LogisticsService.getMessages(widget.contact.id, afterId: _lastId);
      _append(newer);
    } catch (_) {
      // Ignore polling hiccups; the next tick retries.
    }
  }

  void _append(List<ChatMessage> messages) {
    if (!mounted) return;
    final known = _messages.map((m) => m.id).toSet();
    final fresh = messages.where((m) => !known.contains(m.id)).toList();
    if (fresh.isEmpty) return;
    setState(() => _messages.addAll(fresh));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await LogisticsService.sendMessage(widget.contact.id, body);
      _bodyController.clear();
      _append([message]);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;

    return Scaffold(
      backgroundColor: LogisticsColors.background,
      appBar: AppBar(
        backgroundColor: LogisticsColors.primary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contact.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text(widget.contact.roleLabel, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(myId)),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessages(int? myId) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LogisticsColors.primary));
    }
    if (_error != null && _messages.isEmpty) {
      return ErrorState(message: _error!, onRetry: () {
        setState(() => _loading = true);
        _loadInitial();
      });
    }
    if (_messages.isEmpty) {
      return const EmptyState(message: 'No messages yet. Say hello!', icon: Icons.chat_bubble_outline);
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        final mine = msg.senderId == myId;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: mine ? LogisticsColors.primary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
              border: mine ? null : Border.all(color: LogisticsColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(msg.body, style: TextStyle(color: mine ? Colors.white : LogisticsColors.text)),
                const SizedBox(height: 4),
                Text(
                  msg.createdAt != null ? DateFormat('h:mm a').format(msg.createdAt!) : '',
                  style: TextStyle(
                    fontSize: 11,
                    color: mine ? Colors.white70 : LogisticsColors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  maxLength: 2000,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: LogisticsColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(backgroundColor: LogisticsColors.primary),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
