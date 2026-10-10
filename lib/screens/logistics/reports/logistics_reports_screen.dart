import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/logistics.dart';
import '../../../services/logistics_service.dart';
import '../widgets/logistics_ui.dart';

class LogisticsReportsScreen extends StatefulWidget {
  const LogisticsReportsScreen({super.key});

  @override
  State<LogisticsReportsScreen> createState() => _LogisticsReportsScreenState();
}

class _LogisticsReportsScreenState extends State<LogisticsReportsScreen> {
  static final _apiDate = DateFormat('yyyy-MM-dd');

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  Map<String, int> _summary = {};
  int _reloadToken = 0;

  Future<PagedResult<ParcelDelivery>> _fetch(int page) async {
    final data = await LogisticsService.getReport(
      page: page,
      from: _apiDate.format(_range.start),
      to: _apiDate.format(_range.end),
    );
    if (mounted && page == 1) {
      setState(() {
        _summary = (data['summary'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      });
    }
    return PagedResult.fromJson(Map<String, dynamic>.from(data['deliveries']), ParcelDelivery.fromJson);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: LogisticsColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _reloadToken++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LogisticsColors.background,
      appBar: logisticsAppBar('Reports'),
      body: PagedList<ParcelDelivery>(
        key: ValueKey('${_range.start}|${_range.end}|$_reloadToken'),
        fetch: _fetch,
        emptyMessage: 'No deliveries in this period.',
        header: _buildHeader(),
        itemBuilder: (context, d, reload) => ListCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: TrackingText(d.trackingNumber ?? '—')),
                  StatusBadge(status: d.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${d.riderName ?? '—'} · ${d.areaName ?? '—'}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                'Assigned ${formatDate(d.createdAt)} · Delivered ${formatDate(d.deliveredAt)}',
                style: const TextStyle(fontSize: 12, color: LogisticsColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.date_range),
          label: Text('${formatDate(_range.start)} – ${formatDate(_range.end)}'),
          style: OutlinedButton.styleFrom(
            foregroundColor: LogisticsColors.text,
            backgroundColor: Colors.white,
            side: const BorderSide(color: LogisticsColors.line),
            minimumSize: const Size.fromHeight(46),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: [
            StatCard(label: 'Total Parcels', value: _summary['total_parcels'] ?? 0, icon: Icons.inventory_2),
            StatCard(
              label: 'Delivered',
              value: _summary['delivered'] ?? 0,
              icon: Icons.check_circle,
              color: LogisticsColors.success,
            ),
            StatCard(
              label: 'Failed',
              value: _summary['failed'] ?? 0,
              icon: Icons.cancel,
              color: LogisticsColors.danger,
            ),
            StatCard(
              label: 'New Rider Signups',
              value: _summary['new_rider_signups'] ?? 0,
              icon: Icons.person_add_alt,
              color: LogisticsColors.info,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Deliveries in Period',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: LogisticsColors.text),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
