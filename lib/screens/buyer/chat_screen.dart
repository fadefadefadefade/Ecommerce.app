import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/buyer_api.dart';
import '../../theme/app_theme.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';

/// Chat list (the website's Messages): order and direct conversations with unread counts.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<dynamic> threads = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.threads();
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (r.ok) threads = r.body['threads'] ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar( title: const Text('Messages')),
      body: LoadState(
        loading: loading,
        error: error,
        onRetry: _load,
        child: RefreshIndicator(
          color: kOrange,
          onRefresh: _load,
          child: threads.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(color: Alvy.orangeSoft, shape: BoxShape.circle),
                      child: const Icon(Icons.chat_bubble_outline, size: 42, color: Alvy.orange),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: Text('No conversations yet', style: Alvy.display(size: 18, color: context.bc.text, weight: FontWeight.w700))),
                  const SizedBox(height: 4),
                  Center(child: Text('Chat with a store from its page or your order.', style: TextStyle(color: context.bc.muted))),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: threads.length,
                  itemBuilder: (_, i) {
                    final c = context.bc;
                    final t = threads[i];
                    final key = (t['key'] as String).split(':');
                    final unread = asNum(t['unread']).toInt();
                    final order = t['type'] == 'order';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: cardBox(context, radius: 16),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(type: key[0], id: key[1], title: t['label'])));
                            _load();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(color: order ? Alvy.orangeSoft : Alvy.slateSoft, borderRadius: BorderRadius.circular(14)),
                                child: Icon(order ? Icons.receipt_long_outlined : Icons.storefront_outlined, color: order ? Alvy.orange : Alvy.slate),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(t['label'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: c.text, fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    (t['last_body'] ?? '').toString().isEmpty ? t['position'] ?? '' : t['last_body'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: unread > 0 ? c.text : c.textSecondary),
                                  ),
                                ]),
                              ),
                              const SizedBox(width: 8),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(t['last_at'] ?? '', style: TextStyle(fontSize: 11, color: c.muted)),
                                const SizedBox(height: 4),
                                if (unread > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: Alvy.orange, borderRadius: BorderRadius.circular(99)),
                                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                  ),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// One conversation; new messages show up every few seconds, like the website's chat.
class ChatScreen extends StatefulWidget {
  final String type; // order / direct
  final String id;
  final String? title;

  const ChatScreen({super.key, required this.type, required this.id, this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<dynamic> messages = [];
  String? title;
  bool loading = true;
  bool sending = false;
  String? error;
  Timer? poll;

  @override
  void initState() {
    super.initState();
    title = widget.title;
    _load();
    poll = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final r = await BuyerApi.thread(widget.type, widget.id);
    if (!mounted) return;
    final grew = r.ok && (r.body['messages'] as List).length != messages.length;
    setState(() {
      loading = false;
      if (!r.ok) {
        if (!silent) error = r.message;
        return;
      }
      error = null;
      title = r.body['title'] ?? title;
      messages = r.body['messages'];
    });
    if (grew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => sending = true);
    final r = await BuyerApi.send(widget.type, widget.id, body);
    if (!mounted) return;
    setState(() => sending = false);
    if (!r.ok) return showResult(context, r);
    _text.clear();
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar( title: Text(title ?? 'Chat')),
      body: Column(children: [
        Expanded(
          child: LoadState(
            loading: loading,
            error: error,
            onRetry: _load,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                final mine = m['mine'] == true;
                final newDay = i == 0 || messages[i - 1]['day'] != m['day'];
                // The design's bubbles: orange for you (a sharp corner at the bottom right), white cards for them, the time under each.
                return Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                  if (newDay)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(99)),
                        child: Text(m['day'] ?? '', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.bc.textSecondary)),
                      ),
                    ),
                  Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: mine ? Alvy.orange : context.bc.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(mine ? 18 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 18),
                      ),
                      boxShadow: mine ? null : const [BoxShadow(color: Color(0x0F2A1A10), blurRadius: 10, offset: Offset(0, 2))],
                    ),
                    child: Text(m['body'] ?? '', style: TextStyle(color: mine ? Colors.white : context.bc.text, height: 1.35)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 3, 4, 6),
                    child: Text(m['time'] ?? '', style: TextStyle(fontSize: 10.5, color: context.bc.muted)),
                  ),
                ]);
              },
            ),
          ),
        ),
        SafeArea(
          // The design's composer: a beige rounded field and a round orange send button.
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: context.bc.surface,
              boxShadow: const [BoxShadow(color: Color(0x0F2A1A10), blurRadius: 10, offset: Offset(0, -2))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Write a message…',
                    counterText: '',
                    filled: true,
                    fillColor: context.bc.subtle,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filled(
                  onPressed: sending ? null : _send,
                  style: IconButton.styleFrom(backgroundColor: Alvy.orange),
                  icon: sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
