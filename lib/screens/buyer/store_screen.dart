import 'package:flutter/material.dart';

import '../../services/buyer_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import '../../widgets/buyer_product_card.dart';
import '../../widgets/net_image.dart';
import 'chat_screen.dart';

/// The website's store page (stores/show): banner, follow, chat, store vouchers, the seller's own
/// categories (or platform categories), and the store's products.
class StoreScreen extends StatefulWidget {
  final int sellerId;
  const StoreScreen({super.key, required this.sellerId});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  Map<String, dynamic>? d;
  bool loading = true;
  String? error;
  String? scat; // store category id or "none"
  String? category;
  List<dynamic> products = [];
  int page = 1;
  int last = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (!more) setState(() => loading = true);
    final r = await BuyerApi.store(widget.sellerId, {
      'scat': scat,
      'category': category,
      'page': more ? page + 1 : 1,
    });
    if (!mounted) return;
    setState(() {
      loading = false;
      if (!r.ok) {
        error = r.message;
        return;
      }
      error = null;
      d = r.body;
      page = r.body['meta']['current_page'];
      last = r.body['meta']['last_page'];
      products = more ? [...products, ...r.body['data']] : List.of(r.body['data']);
    });
  }

  Future<void> _follow() async {
    final r = await BuyerApi.toggleFollow(widget.sellerId);
    if (!mounted) return;
    showResult(context, r);
    if (r.ok) {
      setState(() {
        d!['store']['following'] = r.body['following'];
        d!['store']['followers'] = asNum(d!['store']['followers']).toInt() + (r.body['following'] == true ? 1 : -1);
      });
    }
  }

  Future<void> _chat() async {
    final r = await BuyerApi.startChat(widget.sellerId);
    if (!mounted) return;
    if (!r.ok) return showResult(context, r);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(type: r.body['type'], id: r.body['id'], title: d!['store']['name'])));
  }

  Future<void> _claim(Map v) async {
    final r = await BuyerApi.claimVoucher(v['id']);
    if (!mounted) return;
    showResult(context, r);
    if (r.ok) setState(() => v['claimed'] = true);
  }

  @override
  Widget build(BuildContext context) {
    final store = d?['store'];
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar( title: Text(store?['name'] ?? 'Store')),
      body: LoadState(
        loading: loading && d == null,
        error: d == null ? error : null,
        onRetry: _load,
        child: d == null
            ? const SizedBox()
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(12), children: [
                  SectionCard(
                    padding: EdgeInsets.zero,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (store['banner_url'] != null) SizedBox(height: 110, child: NetImage(store['banner_url'], fit: BoxFit.cover)),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFFF4F7FA),
                            child: store['logo_url'] != null
                                ? ClipOval(child: NetImage(store['logo_url'], width: 52, height: 52, fit: BoxFit.cover))
                                : Text((store['name'] as String).substring(0, 1)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(store['name'], style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.bc.text)),
                              Text(
                                [if (store['location'] != null) store['location'], '${store['followers']} followers'].join(' · '),
                                style: TextStyle(fontSize: 12, color: context.bc.muted),
                              ),
                              if (store['on_vacation'] == true)
                                const Text('On vacation — not taking orders right now', style: TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                            ]),
                          ),
                        ]),
                      ),
                      if ((store['description'] ?? '').toString().isNotEmpty)
                        Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: Text(store['description'])),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Row(children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _follow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: store['following'] == true ? context.bc.subtle : kOrange,
                                foregroundColor: store['following'] == true ? context.bc.text : Colors.white,
                              ),
                              child: Text(store['following'] == true ? 'Following' : 'Follow'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: OutlinedButton(onPressed: _chat, child: const Text('Chat'))),
                        ]),
                      ),
                    ]),
                  ),
                  if ((d!['vouchers'] as List).isNotEmpty)
                    SectionCard(
                      title: 'Store vouchers',
                      child: Column(children: [
                        for (final v in d!['vouchers'])
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.confirmation_number_outlined, color: kOrange),
                            title: Text('${v['code']} · ${v['label']}'),
                            subtitle: Text('Min. spend ${peso(v['min_spend'])}'),
                            trailing: v['claimed'] == true
                                ? const Text('Claimed', style: TextStyle(color: Color(0xFF15803D)))
                                : TextButton(onPressed: () => _claim(v), child: const Text('Claim')),
                          ),
                      ]),
                    ),
                  _categoryChips(),
                  const SizedBox(height: 8),
                  if (products.isEmpty)
                    Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No products here yet.', style: TextStyle(color: context.bc.muted))))
                  else
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 0.56,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [for (final p in products) BuyerProductCard(product: Map<String, dynamic>.from(p))],
                    ),
                  if (page < last) TextButton(onPressed: () => _load(more: true), child: const Text('Load more')),
                ]),
              ),
      ),
    );
  }

  Widget _categoryChips() {
    final storeCats = List.from(d!['store_categories']);
    final platformCats = List.from(d!['categories']);
    final chips = <Widget>[
      ChoiceChip(label: const Text('All'), selected: scat == null && category == null, onSelected: (_) {
        setState(() => scat = category = null);
        _load();
      }),
    ];
    for (final c in storeCats) {
      chips.add(ChoiceChip(label: Text('${c['name']} (${c['count']})'), selected: scat == '${c['id']}', onSelected: (_) {
        setState(() {
          scat = '${c['id']}';
          category = null;
        });
        _load();
      }));
      for (final s in c['children']) {
        chips.add(ChoiceChip(label: Text('› ${s['name']}'), selected: scat == '${s['id']}', onSelected: (_) {
          setState(() => scat = '${s['id']}');
          _load();
        }));
      }
    }
    if (storeCats.isNotEmpty && asNum(d!['uncategorized']) > 0) {
      chips.add(ChoiceChip(label: Text('Uncategorized (${d!['uncategorized']})'), selected: scat == 'none', onSelected: (_) {
        setState(() => scat = 'none');
        _load();
      }));
    }
    for (final c in platformCats) {
      chips.add(ChoiceChip(label: Text('${c['name']} (${c['count']})'), selected: category == c['name'], onSelected: (_) {
        setState(() {
          category = c['name'];
          scat = null;
        });
        _load();
      }));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}
