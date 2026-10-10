import 'package:flutter/material.dart';
import '../../../models/logistics.dart';
import '../../../services/logistics_service.dart';
import '../widgets/logistics_ui.dart';

class ParcelDetailScreen extends StatefulWidget {
  final int parcelId;

  const ParcelDetailScreen({super.key, required this.parcelId});

  @override
  State<ParcelDetailScreen> createState() => _ParcelDetailScreenState();
}

class _ParcelDetailScreenState extends State<ParcelDetailScreen> {
  Parcel? _parcel;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final parcel = await LogisticsService.getParcel(widget.parcelId);
      setState(() => _parcel = parcel);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LogisticsColors.background,
      appBar: logisticsAppBar('Parcel Details'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _parcel == null) {
      return const Center(child: CircularProgressIndicator(color: LogisticsColors.primary));
    }
    if (_error != null && _parcel == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final parcel = _parcel!;

    return RefreshIndicator(
      color: LogisticsColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: TrackingText(parcel.trackingNumber)),
                    StatusBadge(status: parcel.status, label: parcel.statusLabel),
                  ],
                ),
                const Divider(height: 24),
                InfoRow(label: 'Seller', value: parcel.sellerName),
                InfoRow(label: 'Receiver', value: parcel.receiverName),
                InfoRow(label: 'Receiver Phone', value: parcel.receiverPhone),
                InfoRow(label: 'Area', value: parcel.areaName),
                InfoRow(label: 'Pickup Address', value: parcel.pickupAddress),
                InfoRow(label: 'Dropoff Address', value: parcel.dropoffAddress),
                InfoRow(label: 'Weight', value: parcel.weightKg != null ? '${parcel.weightKg} kg' : null),
                InfoRow(label: 'Size', value: parcel.size),
                InfoRow(label: 'Created', value: formatDateTime(parcel.createdAt)),
                if (parcel.notes != null && parcel.notes!.trim().isNotEmpty)
                  InfoRow(label: 'Notes', value: parcel.notes!.trim()),
              ],
            ),
          ),
          if (parcel.delivery != null) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Assigned Rider',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler, color: LogisticsColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          parcel.delivery!.riderName ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      StatusBadge(status: parcel.delivery!.status),
                    ],
                  ),
                  if (parcel.delivery!.deliveredAt != null)
                    InfoRow(label: 'Delivered At', value: formatDateTime(parcel.delivery!.deliveredAt)),
                  if (parcel.delivery!.remarks != null && parcel.delivery!.remarks!.isNotEmpty)
                    InfoRow(label: 'Remarks', value: parcel.delivery!.remarks),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
