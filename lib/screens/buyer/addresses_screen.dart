import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/buyer_colors.dart';
import '../../services/buyer_api.dart';
import '../../widgets/buyer_kit.dart';
import 'add_address_screen.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<dynamic> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final r = await BuyerApi.addresses();
    if (!mounted) return;
    setState(() {
      _addresses = r.ok ? (r.body['addresses'] ?? []) : [];
      _isLoading = false;
    });
    if (!r.ok) showResult(context, r);
  }

  Future<void> _setDefault(int addressId) async {
    final r = await BuyerApi.defaultAddress(addressId);
    if (!mounted) return;
    showResult(context, r);
    _loadAddresses();
  }

  Future<void> _deleteAddress(int addressId, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Address'),
        content: Text('Remove "$label" address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final r = await BuyerApi.deleteAddress(addressId);
      if (!mounted) return;
      showResult(context, r);
      _loadAddresses();
    }
  }

  IconData _labelIcon(String label) => switch (label.toLowerCase()) {
        'home' => Icons.home_outlined,
        'work' || 'office' => Icons.work_outline,
        _ => Icons.place_outlined,
      };

  Future<void> _add() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddAddressScreen()));
    if (result == true) _loadAddresses();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final n = _addresses.length;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Saved Address Book')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAddresses,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                    // The design's header: "DELIVERY HUB / 3 Saved Locations" with Add New on the right.
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('DELIVERY HUB', style: TextStyle(fontSize: 11.5, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: c.textSecondary)),
                          Text('$n Saved Location${n == 1 ? '' : 's'}', style: Alvy.display(size: 21, color: c.text, weight: FontWeight.w700)),
                        ]),
                      ),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                        label: const Text('Add New'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    for (final a in _addresses) _buildAddressCard(a),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        Icon(Icons.info_outline, color: Alvy.slate, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Your default address is picked first at checkout. You can still change it there.',
                              style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4)),
                        ),
                      ]),
                    ),
                  ]),
                ),
      bottomNavigationBar: _isLoading || _addresses.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Add New Delivery Address', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: context.bc.subtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_outlined, size: 48, color: Alvy.orange),
            ),
            const SizedBox(height: 24),
            Text(
              'No addresses saved yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.bc.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an address to speed up checkout.',
              style: TextStyle(
                fontSize: 14,
                color: context.bc.muted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Add Your First Address'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressNote(String text) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Alvy.warnSoft, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.35))),
        ]),
      );

  Widget _tag(String text, {IconData? icon, required Color bg, required Color fg}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: fg)),
        ]),
      );

  /// The design's address card: label tags, the person, the address in a beige box, then Edit / delete and the default action.
  Widget _buildAddressCard(Map<String, dynamic> address) {
    final c = context.bc;
    final isDefault = address['is_default'] == true;
    final label = '${address['label'] ?? 'Address'}';
    final complete = address['complete'] != false;
    final ok = address['deliverable'] != false;
    final small = OutlinedButton.styleFrom(
      backgroundColor: c.subtle,
      side: BorderSide.none,
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: cardBox(context, radius: 20).copyWith(
        border: isDefault ? Border.all(color: Alvy.orange.withValues(alpha: 0.5), width: 1.5) : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _tag(label.toUpperCase(), icon: _labelIcon(label), bg: isDefault ? Alvy.orange : Alvy.slate, fg: Colors.white),
          if (isDefault) ...[
            const SizedBox(width: 6),
            _tag('DEFAULT', bg: Alvy.orangeSoft, fg: Alvy.orangeDark),
          ],
          const Spacer(),
          if (address['complete'] == false || address['service_area'] != null)
            Text(!complete ? 'Needs update' : ok ? 'Delivers here' : 'Outside area',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: !complete || !ok ? const Color(0xFFB45309) : Alvy.successText)),
          if (isDefault) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle_outline, color: Alvy.orange, size: 22),
          ],
        ]),
        const SizedBox(height: 12),
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: c.subtle, child: Icon(Icons.person_outline, color: c.textSecondary, size: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${address['full_name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w700)),
              if ((address['phone'] ?? '').toString().isNotEmpty)
                Text('${address['phone']}', style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(_labelIcon(label), size: 18, color: Alvy.orange),
            const SizedBox(width: 10),
            Expanded(child: Text('${address['full_address'] ?? ''}', style: TextStyle(color: c.text, height: 1.4))),
          ]),
        ),
        if (address['complete'] == false)
          _addressNote('Edit this address and choose the region, city and barangay from the lists so it can be used at checkout.')
        else if (address['deliverable'] == false)
          _addressNote("We only deliver within ${address['service_area']} for now, so this address can't be used at checkout."),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton.icon(
            style: small,
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddAddressScreen(address: address)));
              if (result == true) _loadAddresses();
            },
            icon: Icon(Icons.edit_outlined, size: 16, color: c.text),
            label: Text('Edit', style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Remove',
            style: IconButton.styleFrom(backgroundColor: c.subtle, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => _deleteAddress(address['id'], label),
            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
          ),
          const Spacer(),
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: Alvy.orange, borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text('Default address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            )
          else
            OutlinedButton.icon(
              style: small,
              onPressed: () => _setDefault(address['id']),
              icon: Icon(Icons.bookmark_border, size: 16, color: c.text),
              label: Text('Make Default', style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
            ),
        ]),
      ]),
    );
  }
}
