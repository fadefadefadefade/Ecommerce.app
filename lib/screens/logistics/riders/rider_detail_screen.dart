import 'package:flutter/material.dart';
import '../../../models/logistics.dart';
import '../../../services/logistics_service.dart';
import '../widgets/logistics_ui.dart';

class RiderDetailScreen extends StatefulWidget {
  final int riderId;

  const RiderDetailScreen({super.key, required this.riderId});

  @override
  State<RiderDetailScreen> createState() => _RiderDetailScreenState();
}

class _RiderDetailScreenState extends State<RiderDetailScreen> {
  Rider? _rider;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
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
      final rider = await LogisticsService.getRider(widget.riderId);
      setState(() => _rider = rider);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      _changed = true;
      if (!mounted) return;
      showSnack(context, message);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final ok = await confirmAction(
      context,
      title: 'Approve rider',
      message: 'Approve ${_rider!.fullName}\'s application?',
      confirmLabel: 'Approve',
    );
    if (ok) _run(() => LogisticsService.approveRider(_rider!.id));
  }

  Future<void> _disapprove() async {
    final reason = await askReason(
      context,
      title: 'Disapprove rider',
      hint: 'Rejection reason (optional)',
      confirmLabel: 'Disapprove',
    );
    if (reason != null) {
      _run(() => LogisticsService.disapproveRider(_rider!.id, reason.isEmpty ? null : reason));
    }
  }

  Future<void> _toggleActive() async {
    final rider = _rider!;
    final ok = await confirmAction(
      context,
      title: rider.isActive ? 'Deactivate rider' : 'Activate rider',
      message: rider.isActive
          ? '${rider.fullName} will no longer receive delivery assignments.'
          : '${rider.fullName} will be available for delivery assignments.',
      confirmLabel: rider.isActive ? 'Deactivate' : 'Activate',
      destructive: rider.isActive,
    );
    if (ok) _run(() => LogisticsService.toggleRiderActive(rider.id));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: LogisticsColors.background,
        appBar: logisticsAppBar(_rider?.fullName ?? 'Rider'),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _rider == null) {
      return const Center(child: CircularProgressIndicator(color: LogisticsColors.primary));
    }
    if (_error != null && _rider == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final rider = _rider!;

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
                    Expanded(
                      child: Text(
                        rider.fullName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    StatusBadge(status: rider.applicationStatus),
                  ],
                ),
                const Divider(height: 24),
                InfoRow(label: 'Phone', value: rider.phone),
                InfoRow(label: 'Email', value: rider.email),
                InfoRow(label: 'Vehicle', value: rider.vehicleType),
                InfoRow(label: 'License', value: rider.licenseNumber),
                InfoRow(label: 'Area', value: rider.areaName),
                InfoRow(label: 'Active', value: rider.isActive ? 'Yes' : 'No'),
                InfoRow(label: 'Applied', value: formatDate(rider.createdAt)),
                if (rider.rejectionReason != null && rider.rejectionReason!.isNotEmpty)
                  InfoRow(label: 'Rejection Reason', value: rider.rejectionReason),
              ],
            ),
          ),
          if (rider.idDocumentUrl != null) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'ID Document',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  rider.idDocumentUrl!,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'Document preview unavailable on mobile. Open it from the web panel.',
                    style: TextStyle(color: LogisticsColors.muted),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildActions(rider),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Delivery History',
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: rider.deliveries.isEmpty
                ? const EmptyState(message: 'No deliveries yet.')
                : Column(
                    children: rider.deliveries.map((d) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TrackingText(d.trackingNumber ?? '—'),
                                  Text(
                                    'Assigned ${formatDate(d.createdAt)}',
                                    style: const TextStyle(fontSize: 12, color: LogisticsColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: d.status),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Rider rider) {
    if (_busy) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(color: LogisticsColors.primary),
        ),
      );
    }

    if (rider.isPending) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _approve,
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LogisticsColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _disapprove,
              icon: const Icon(Icons.close),
              label: const Text('Disapprove'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LogisticsColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    if (rider.isApproved) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _toggleActive,
          icon: Icon(rider.isActive ? Icons.block : Icons.play_arrow),
          label: Text(rider.isActive ? 'Deactivate' : 'Activate'),
          style: ElevatedButton.styleFrom(
            backgroundColor: rider.isActive ? LogisticsColors.danger : LogisticsColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
