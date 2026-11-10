import '../../widgets/responsive.dart';
import 'package:flutter/material.dart';

import '../../services/buyer_api.dart';
import '../../theme/app_theme.dart';
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
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(store?['name'] ?? 'Store')),
      body: LoadState(
        loading: loading && d == null,
        error: d == null ? error : null,
        onRetry: _load,
        child: d == null
            ? const SizedBox()
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                  // The design's store hero: the banner photo with the store card overlapping it.
                  Stack(clipBehavior: Clip.none, children: [
                    SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: store['banner_url'] != null
                          ? NetImage(store['banner_url'], fit: BoxFit.cover)
                          : DecoratedBox(
                              decoration: BoxDecoration(gradient: LinearGradient(colors: [Alvy.orange, Alvy.slate], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                            ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Alvy.surface, borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.circle, size: 8, color: store['on_vacation'] == true ? const Color(0xFFB45309) : const Color(0xFF16A34A)),
                          const SizedBox(width: 6),
                          Text(store['on_vacation'] == true ? 'On vacation' : 'Open now',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Alvy.navy)),
                        ]),
                      ),
                    ),
                  ]),
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: cardBox(context, radius: 20),
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Alvy.orange, width: 2)),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: c.subtle,
                                child: store['logo_url'] != null
                                    ? ClipOval(child: NetImage(store['logo_url'], width: 56, height: 56, fit: BoxFit.cover))
                                    : Text((store['name'] as String).substring(0, 1), style: Alvy.display(size: 20, color: Alvy.orange, weight: FontWeight.w800)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(store['name'], maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: Alvy.display(size: 20, color: c.text, weight: FontWeight.w700)),
                                if (store['location'] != null)
                                  Row(children: [
                                    Icon(Icons.place_outlined, size: 14, color: c.textSecondary),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text('${store['location']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                                    ),
                                  ]),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              _stat('${store['product_count'] ?? products.length}', 'Products'),
                              _divider(),
                              _stat('${store['followers'] ?? 0}', 'Followers'),
                              _divider(),
                              _stat('${(d!['vouchers'] as List).length}', 'Vouchers'),
                            ]),
                          ),
                          if (store['on_vacation'] == true)
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text('On vacation — not taking orders right now', style: TextStyle(fontSize: 12.5, color: Color(0xFFB45309))),
                            ),
                          if ((store['description'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(store['description'], style: TextStyle(color: c.textSecondary, height: 1.4)),
                            ),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _follow,
                                style: FilledButton.styleFrom(
                                  backgroundColor: store['following'] == true ? c.subtle : Alvy.orange,
                                  foregroundColor: store['following'] == true ? c.text : Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                icon: Icon(store['following'] == true ? Icons.check : Icons.favorite_border, size: 18),
                                label: Text(store['following'] == true ? 'Following' : 'Follow'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _chat,
                                style: FilledButton.styleFrom(backgroundColor: Alvy.slateSoft, foregroundColor: Alvy.slate, minimumSize: const Size.fromHeight(46)),
                                icon: const Icon(Icons.chat_outlined, size: 18),
                                label: const Text('Chat'),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                  if ((d!['vouchers'] as List).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Row(children: [
                        const Icon(Icons.confirmation_number_outlined, color: Alvy.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Store Vouchers', style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w700))),
                        Text('${(d!['vouchers'] as List).length} active', style: const TextStyle(fontSize: 12, color: Alvy.orange, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    SizedBox(
                      height: 92,
                      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                        for (final v in d!['vouchers']) _voucher(v),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    height: 42,
                    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: _categoryChips()),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Text('All Products', style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700)),
                  ),
                  if (products.isEmpty)
                    Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No products here yet.', style: TextStyle(color: c.muted))))
                  else
                    GridView.extent(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      maxCrossAxisExtent: Responsive.productTileMaxFor(context),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 0.6,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [for (final p in products) BuyerProductCard(product: Map<String, dynamic>.from(p))],
                    ),
                  if (page < last) Center(child: TextButton(onPressed: () => _load(more: true), child: const Text('Load more'))),
                  // The design's guarantee strip at the end of the store.
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(16)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(radius: 18, backgroundColor: Alvy.orangeSoft, child: const Icon(Icons.verified_user_outlined, color: Alvy.orange, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('ALVY Guarantee', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                          const SizedBox(height: 2),
                          Text('Your payment is checked by ALVY, and you can ask for a return if the item is not as described.',
                              style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(children: [
          Text(value, style: Alvy.display(size: 18, color: Alvy.orange, weight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 11.5, color: context.bc.textSecondary)),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 30, color: context.bc.border);

  /// A store voucher as the design's ticket: orange edge, amount, minimum spend, Claim.
  Widget _voucher(Map v) {
    final c = context.bc;
    final claimed = v['claimed'] == true;
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 10),
      decoration: cardBox(context, radius: 14),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        Container(width: 5, color: Alvy.orange),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${v['label']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Alvy.display(size: 16, color: Alvy.orange, weight: FontWeight.w800)),
            Text('Min. spend ${peso(v['min_spend'])}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            Text('${v['code']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.muted, letterSpacing: 0.4)),
          ]),
        ),
        const SizedBox(width: 8),
        claimed
            ? const Text('Claimed', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700))
            : FilledButton(
                onPressed: () => _claim(v),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 14)),
                child: const Text('Claim'),
              ),
        const SizedBox(width: 10),
      ]),
    );
  }

  List<Widget> _categoryChips() {
    final storeCats = List.from(d!['store_categories']);
    final platformCats = List.from(d!['categories']);
    Widget pill(String label, bool selected, VoidCallback onTap) =>
        Padding(padding: const EdgeInsets.only(right: 8), child: FilterPill(label, selected: selected, onTap: onTap));
    final chips = <Widget>[
      pill('All Products', scat == null && category == null, () {
        setState(() => scat = category = null);
        _load();
      }),
    ];
    for (final c in storeCats) {
      chips.add(pill('${c['name']} (${c['count']})', scat == '${c['id']}', () {
        setState(() {
          scat = '${c['id']}';
          category = null;
        });
        _load();
      }));
      for (final s in c['children']) {
        chips.add(pill('› ${s['name']}', scat == '${s['id']}', () {
          setState(() => scat = '${s['id']}');
          _load();
        }));
      }
    }
    if (storeCats.isNotEmpty && asNum(d!['uncategorized']) > 0) {
      chips.add(pill('Uncategorized (${d!['uncategorized']})', scat == 'none', () {
        setState(() => scat = 'none');
        _load();
      }));
    }
    for (final c in platformCats) {
      chips.add(pill('${c['name']} (${c['count']})', category == c['name'], () {
        setState(() {
          category = c['name'];
          scat = null;
        });
        _load();
      }));
    }
    return chips;
  }
}
