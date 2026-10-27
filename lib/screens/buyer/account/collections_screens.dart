import 'package:flutter/material.dart';
import '../../../widgets/voucher_ticket.dart';

import '../../../services/buyer_api.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/buyer_kit.dart';
import '../../../widgets/buyer_product_card.dart';
import '../../../widgets/net_image.dart';
import '../store_screen.dart';

/// The website's Wishlist (wishlist/index).
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<dynamic> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.wishlist();
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (r.ok) items = r.body['items'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar( title: const Text('My Wishlist')),
      body: LoadState(
        loading: loading,
        error: error,
        onRetry: _load,
        child: RefreshIndicator(
          color: kOrange,
          onRefresh: _load,
          child: items.isEmpty
              ? ListView(children: [
                  Padding(padding: const EdgeInsets.all(48), child: Center(child: Text('Your wishlist is empty.', style: TextStyle(color: context.bc.muted)))),
                ])
              : GridView.count(
                  padding: const EdgeInsets.all(12),
                  crossAxisCount: 2,
                  childAspectRatio: 0.56,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [for (final p in items) BuyerProductCard(product: Map<String, dynamic>.from(p))],
                ),
        ),
      ),
    );
  }
}

/// The website's My Vouchers (vouchers/wallet): claimed vouchers with their state, and ALVY
/// vouchers that can still be claimed.
class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  List<dynamic> claimed = [];
  List<dynamic> claimable = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.vouchers();
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (r.ok) {
        claimed = r.body['claimed'];
        claimable = r.body['claimable'];
      }
    });
  }

  Future<void> _claim(Map v) async {
    final r = await BuyerApi.claimVoucher(v['id']);
    if (!mounted) return;
    showResult(context, r);
    if (r.ok) _load();
  }

  Widget _voucher(Map v, {Widget? trailing, bool muted = false}) => VoucherTicket(v, trailing: trailing, muted: muted);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar( title: const Text('My Vouchers'), actions: [
        TextButton.icon(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherCenterScreen()));
            _load();
          },
          icon: const Icon(Icons.local_activity_outlined, color: kOrange),
          label: const Text('Voucher Center', style: TextStyle(color: kOrange)),
        ),
      ]),
      body: LoadState(
        loading: loading,
        error: error,
        onRetry: _load,
        child: RefreshIndicator(
          color: kOrange,
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            if (claimable.isNotEmpty) ...[
              Text('ALVY vouchers you can claim', style: TextStyle(fontWeight: FontWeight.w700, color: context.bc.text)),
              const SizedBox(height: 8),
              for (final v in claimable) _voucher(v, trailing: TextButton(onPressed: () => _claim(v), child: const Text('Claim'))),
              const SizedBox(height: 12),
            ],
            Text('Claimed', style: TextStyle(fontWeight: FontWeight.w700, color: context.bc.text)),
            const SizedBox(height: 8),
            if (claimed.isEmpty) Text('No vouchers yet. Claim them from store pages and product pages.', style: TextStyle(color: context.bc.muted)),
            for (final v in claimed)
              _voucher(v,
                  muted: v['state'] != null && v['state'] != 'Available',
                  trailing: Text(v['state'] ?? '',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: v['state'] == 'Available' ? const Color(0xFF15803D) : context.bc.muted))),
          ]),
        ),
      ),
    );
  }
}

/// The website's Voucher Center: every claimable voucher running now, by type (all, free shipping, ALVY discounts, store).
class VoucherCenterScreen extends StatefulWidget {
  const VoucherCenterScreen({super.key});
  @override
  State<VoucherCenterScreen> createState() => _VoucherCenterScreenState();
}

class _VoucherCenterScreenState extends State<VoucherCenterScreen> {
  static const _tabs = [('all', 'All'), ('shipping', 'Free shipping'), ('discount', 'ALVY discounts'), ('store', 'Store vouchers')];
  String tab = 'all';
  Map<String, dynamic> counts = {};
  List<dynamic> vouchers = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.voucherCenter(tab: tab);
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (r.ok) {
        counts = Map<String, dynamic>.from(r.body['counts'] ?? {});
        vouchers = r.body['vouchers'] ?? [];
      }
    });
  }

  Future<void> _claim(Map v) async {
    final r = await BuyerApi.claimVoucher(v['id']);
    if (!mounted) return;
    showResult(context, r);
    if (r.ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar( title: const Text('Voucher Center')),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
            for (final (key, label) in _tabs)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('$label (${counts[key] ?? 0})'),
                  selected: tab == key,
                  selectedColor: kOrange.withValues(alpha: .15),
                  onSelected: (_) {
                    setState(() {
                      tab = key;
                      loading = true;
                    });
                    _load();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: LoadState(
            loading: loading,
            error: error,
            onRetry: _load,
            child: RefreshIndicator(
              color: kOrange,
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(12), children: [
                if (vouchers.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('No vouchers to claim right now.', textAlign: TextAlign.center, style: TextStyle(color: c.muted))),
                for (final v in vouchers)
                  VoucherTicket(
                    v,
                    muted: v['used_up'] == true,
                    trailing: v['used_up'] == true
                        ? Text('Used', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted))
                        : v['claimed'] == true
                            ? const Text('✓ Claimed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)))
                            : TextButton(onPressed: () => _claim(v), child: const Text('Claim')),
                  ),
                if (vouchers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('One store voucher per store, plus one ALVY discount and one free-shipping voucher per checkout. Each voucher\'s limits are shown on it.',
                        style: TextStyle(fontSize: 12, color: c.muted)),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The website's Following (stores/following).
class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  List<dynamic> stores = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.following();
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (r.ok) stores = r.body['stores'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar( title: const Text('Following')),
      body: LoadState(
        loading: loading,
        error: error,
        onRetry: _load,
        child: stores.isEmpty
            ? Center(child: Text('You are not following any store yet.', style: TextStyle(color: context.bc.muted)))
            : ListView(padding: const EdgeInsets.all(12), children: [
                for (final s in stores)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF4F7FA),
                        child: s['logo_url'] != null ? ClipOval(child: NetImage(s['logo_url'], width: 40, height: 40, fit: BoxFit.cover)) : Text('${s['name']}'.substring(0, 1)),
                      ),
                      title: Text(s['name']),
                      subtitle: Text(s['location'] ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(sellerId: s['id'])));
                        _load();
                      },
                    ),
                  ),
              ]),
      ),
    );
  }
}
