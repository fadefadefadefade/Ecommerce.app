import 'package:flutter/material.dart';

import '../../services/buyer_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import 'product_detail_screen.dart';

/// The website's ALVY Assistant (the chat bubble on the shop pages): ask about products, orders and vouchers.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
    setState(() => _messages.clear());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ALVY Assistant'),
          Text(_mode == 'ai' ? 'Ask about products, orders and vouchers' : 'Quick help', style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [IconButton(tooltip: 'Start over', onPressed: _reset, icon: const Icon(Icons.refresh))],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kOrange))
              : ListView(controller: _scroll, padding: const EdgeInsets.all(12), children: [
                  if (_messages.isEmpty) ...[
                    _bubble({'role': 'assistant', 'content': 'Hi! I can help you find products, check your orders and vouchers. What are you looking for?'}),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final q in const ['Where is my order?', 'Show me bags under ₱500', 'What vouchers can I use?'])
                        ActionChip(label: Text(q), onPressed: () => _ask(q)),
                    ]),
                  ],
                  for (final m in _messages) _bubble(m),
                  if (_asking)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kOrange)), SizedBox(width: 8), Text('Thinking…')]),
                    ),
                ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(hintText: 'Ask ALVY…', counterText: '', isDense: true, border: OutlineInputBorder()),
                  onSubmitted: (_) => _ask(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(style: IconButton.styleFrom(backgroundColor: kOrange), onPressed: _asking ? null : _ask, icon: const Icon(Icons.send)),
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
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: mine ? kOrange : (m['error'] == true ? const Color(0xFFFEF2F2) : c.surface),
            borderRadius: BorderRadius.circular(12),
            border: mine ? null : Border.all(color: c.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['content']}', style: TextStyle(color: mine ? Colors.white : c.text)),
            for (final p in cards)
              Card(
                margin: const EdgeInsets.only(top: 6),
                elevation: 0,
                child: ListTile(
                  dense: true,
                  leading: p['image'] != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network('${p['image']}', width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)))
                      : const Icon(Icons.shopping_bag_outlined),
                  title: Text('${p['name']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text([p['price'], if (p['was'] != null) 'was ${p['was']}', if (p['stock'] != null) p['stock']].join(' · ')),
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
      ),
    );
  }
}
