import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

import '../../services/buyer_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/allie.dart';
import '../../widgets/buyer_kit.dart';
import '../../widgets/motion.dart';
import 'product_detail_screen.dart';

/// ALLIE, the website's assistant (the chat bubble on the shop pages): ask about products, orders and vouchers.
/// Answers can carry product cards and actions the buyer confirms (add to cart, cancel an order, contact support).
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  String _mode = 'ai';
  bool _loading = true;
  bool _asking = false;
  bool _happy = false;
  Timer? _happyTimer;
  // Messages from history appear as they are; only new ones rise in.
  int _historyCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _happyTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await BuyerApi.assistantHistory();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _mode = '${r.body['mode'] ?? 'ai'}';
        _messages
          ..clear()
          ..addAll(List.from(r.body['messages'] ?? []).map((m) => Map<String, dynamic>.from(m as Map)));
        _historyCount = _messages.length;
      }
    });
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _ask([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _asking) return;
    _input.clear();
    setState(() {
      _asking = true;
      _messages.add({'role': 'user', 'content': text});
    });
    _toBottom();
    final r = await BuyerApi.assistantAsk(text);
    if (!mounted) return;
    setState(() {
      _asking = false;
      _messages.add(r.ok
          ? {'role': 'assistant', 'content': '${r.body['reply'] ?? ''}', 'cards': r.body['cards'] ?? [], 'actions': r.body['actions'] ?? []}
          : {'role': 'assistant', 'content': r.message, 'error': true});
      if (r.ok && r.body['mode'] != null) _mode = '${r.body['mode']}';
      _happy = r.ok;
    });
    // She smiles for a moment when her answer arrives.
    _happyTimer?.cancel();
    _happyTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _happy = false);
    });
    _toBottom();
  }

  Future<void> _confirm(Map<String, dynamic> msg, Map<String, dynamic> action) async {
    final r = await BuyerApi.assistantConfirm('${action['token']}');
    if (!mounted) return;
    setState(() {
      msg['actions'] = [];   // a prepared action is used once
      _messages.add({'role': 'assistant', 'content': r.message.isEmpty ? (r.ok ? 'Done.' : 'That could not be done.') : r.message, 'error': !r.ok});
    });
    _toBottom();
  }

  Future<void> _reset() async {
    await BuyerApi.assistantReset();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _historyCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          AllieAvatar(size: 40, hello: true, mood: _asking ? AllieMood.thinking : (_happy ? AllieMood.happy : AllieMood.idle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ALLIE'),
              Text(_asking ? 'Thinking…' : (_mode == 'ai' ? 'Ask about products, orders and vouchers' : 'Quick help'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
        actions: [IconButton(tooltip: 'Start over', onPressed: _reset, icon: const Icon(Icons.refresh))],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kOrange))
              : ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), children: [
                  if (_messages.isEmpty) ...[
                    _bubble({'role': 'assistant', 'content': "Hi! I'm ALLIE. I can help you find products, check your orders and vouchers. What are you looking for?"}),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final q in const ['Where is my order?', 'Show me bags under ₱500', 'What vouchers can I use?'])
                        ActionChip(
                          avatar: const Icon(Icons.auto_awesome, size: 16, color: Alvy.orange),
                          label: Text(q, style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
                          backgroundColor: c.subtle,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          onPressed: () => _ask(q),
                        ),
                    ]),
                  ],
                  for (final (i, m) in _messages.indexed) RiseIn(enabled: i >= _historyCount, child: _bubble(m)),
                  if (_asking)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        const AllieAvatar(size: 30, mood: AllieMood.thinking),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
                          child: AllieTypingDots(color: c.muted),
                        ),
                      ]),
                    ),
                ]),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: c.surface,
              boxShadow: const [BoxShadow(color: Color(0x0F2A1A10), blurRadius: 10, offset: Offset(0, -2))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Ask ALLIE…',
                    counterText: '',
                    filled: true,
                    fillColor: c.subtle,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _ask(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filled(style: IconButton.styleFrom(backgroundColor: kOrange), onPressed: _asking ? null : _ask, icon: const Icon(Icons.send_rounded, size: 20)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final c = context.bc;
    final mine = m['role'] == 'user';
    final cards = List.from(m['cards'] ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final actions = List.from(m['actions'] ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final bubble = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (mine ? .82 : .74)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          // The chat's bubbles: orange for you, white cards for ALVY.
          decoration: BoxDecoration(
            color: mine ? kOrange : (m['error'] == true ? Alvy.dangerSoft : c.surface),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
            boxShadow: mine ? null : const [BoxShadow(color: Color(0x0F2A1A10), blurRadius: 10, offset: Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['content']}', style: TextStyle(color: mine ? Colors.white : c.text, height: 1.35)),
            for (final p in cards)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  dense: true,
                  leading: p['image'] != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network('${p['image']}', width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)))
                      : const Icon(Icons.shopping_bag_outlined),
                  title: Text('${p['name']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text([p['price'], if (p['was'] != null) 'was ${p['was']}', if (p['stock'] != null) p['stock']].join(' · '),
                      style: const TextStyle(color: Alvy.orange, fontWeight: FontWeight.w700)),
                  onTap: () {
                    final slug = '${p['link'] ?? ''}'.split('/products/').last;
                    if (slug.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: slug)));
                  },
                ),
              ),
            for (final a in actions)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kOrange),
                  onPressed: () => _confirm(m, a),
                  child: Text('Confirm: ${a['label']}'),
                ),
              ),
          ]),
        ),
      );
    if (mine) return Align(alignment: Alignment.centerRight, child: bubble);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.only(bottom: 10, right: 6), child: AllieAvatar(size: 30, animate: false)),
      Flexible(child: bubble),
    ]);
  }
}
