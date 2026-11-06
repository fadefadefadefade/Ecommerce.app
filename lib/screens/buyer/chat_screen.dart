import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/buyer_api.dart';
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
                  Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No conversations yet.', style: TextStyle(color: context.bc.muted)))),
                ])
              : ListView.separated(
                  itemCount: threads.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: context.bc.border),
                  itemBuilder: (_, i) {
                    final t = threads[i];
                    final key = (t['key'] as String).split(':');
                    final unread = asNum(t['unread']).toInt();
                    return ListTile(
                      tileColor: context.bc.surface,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFF1EE),
                        child: Icon(t['type'] == 'order' ? Icons.receipt_long : Icons.person, color: kOrange),
                      ),
                      title: Text(t['label'] ?? '', style: TextStyle(fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500)),
                      subtitle: Text(
                        (t['last_body'] ?? '').toString().isEmpty ? t['position'] ?? '' : t['last_body'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(t['last_at'] ?? '', style: TextStyle(fontSize: 11, color: context.bc.muted)),
                        if (unread > 0) Badge(label: Text('$unread'), backgroundColor: kOrange),
                      ]),
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(type: key[0], id: key[1], title: t['label'])));
                        _load();
                      },
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
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                final mine = m['mine'] == true;
                final newDay = i == 0 || messages[i - 1]['day'] != m['day'];
                return Column(children: [
                  if (newDay)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(m['day'] ?? '', style: TextStyle(fontSize: 11, color: context.bc.muted)),
                    ),
                  Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: mine ? kOrange : context.bc.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: mine ? null : Border.all(color: context.bc.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(m['body'] ?? '', style: TextStyle(color: mine ? Colors.white : context.bc.text)),
                        Text(m['time'] ?? '', style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : context.bc.muted)),
                      ]),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
            decoration: BoxDecoration(color: context.bc.surface, border: Border(top: BorderSide(color: context.bc.border))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Type a message…', counterText: '', border: InputBorder.none),
                ),
              ),
              IconButton(
                onPressed: sending ? null : _send,
                icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, color: kOrange),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
