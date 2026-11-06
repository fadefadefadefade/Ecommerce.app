import 'package:flutter/material.dart';
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

  String _getEmoji(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return '🏠';
      case 'work':
        return '🏢';
      default:
        return '📍';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar(
        title: const Text('My Addresses'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Addresses',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: context.bc.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your saved delivery addresses.',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.bc.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddAddressScreen(),
                            ),
                          );
                          if (result == true) {
                            _loadAddresses();
                          }
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFA4E1C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _addresses.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _addresses.length,
                          itemBuilder: (context, index) {
                            final address = _addresses[index];
                            return _buildAddressCard(address);
                          },
                        ),
                ),
              ],
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
              child: const Center(
                child: Text(
                  '📍',
                  style: TextStyle(fontSize: 50),
                ),
              ),
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
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddAddressScreen(),
                  ),
                );
                if (result == true) {
                  _loadAddresses();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFA4E1C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Add Your First Address'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressNote(String text) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
      );

  Widget _buildAddressCard(Map<String, dynamic> address) {
    final isDefault = address['is_default'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.bc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? const Color(0xFFFA4E1C) : context.bc.border,
          width: isDefault ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _getEmoji(address['label'] ?? ''),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address['label'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: context.bc.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '· ${address['full_name'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.bc.muted,
                            ),
                          ),
                        ],
                      ),
                      if (address['phone'] != null && address['phone'] != '')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '📞 ${address['phone']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.bc.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFA4E1C).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '✓ DEFAULT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFA4E1C),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            if (address['complete'] == false || address['service_area'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Builder(builder: (_) {
                  final complete = address['complete'] != false;
                  final ok = address['deliverable'] != false;
                  final (label, color, bg) = !complete
                      ? ('Needs update', const Color(0xFFB45309), const Color(0xFFFFFBEB))
                      : ok
                          ? ('Delivers here', const Color(0xFF047857), const Color(0xFFECFDF5))
                          : ('Outside delivery area', const Color(0xFFB45309), const Color(0xFFFFFBEB));
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                    ),
                  );
                }),
              ),
            const SizedBox(height: 12),
            Text(
              address['full_address'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: context.bc.textSecondary,
              ),
            ),
            if (address['complete'] == false)
              _addressNote('Edit this address and choose the region, city and barangay from the lists so it can be used at checkout.')
            else if (address['deliverable'] == false)
              _addressNote("We only deliver within ${address['service_area']} for now, so this address can't be used at checkout."),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isDefault)
                  OutlinedButton(
                    onPressed: () => _setDefault(address['id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFA4E1C),
                      side: const BorderSide(color: Color(0xFFFA4E1C)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Set as Default',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddAddressScreen(address: address),
                      ),
                    );
                    if (result == true) {
                      _loadAddresses();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.bc.textSecondary,
                    side: BorderSide(color: context.bc.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _deleteAddress(address['id'], address['label']),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Remove',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
