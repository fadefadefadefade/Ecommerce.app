import 'package:flutter/material.dart';
import '../../../models/logistics.dart';
import '../../../services/logistics_service.dart';
import '../widgets/logistics_ui.dart';
import 'rider_detail_screen.dart';

class RidersScreen extends StatefulWidget {
  final String initialStatus;

  const RidersScreen({super.key, this.initialStatus = ''});

  @override
  State<RidersScreen> createState() => _RidersScreenState();
}

class _RidersScreenState extends State<RidersScreen> {
  final _searchController = TextEditingController();
  late String _status = widget.initialStatus;
  String _search = '';
  int _reloadToken = 0;

  static const _statuses = {
    '': 'All',
    'pending': 'Pending',
    'approved': 'Approved',
    'rejected': 'Rejected',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openRider(Rider rider) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RiderDetailScreen(riderId: rider.id)),
    );
    if (changed == true) setState(() => _reloadToken++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LogisticsColors.background,
      appBar: logisticsAppBar('Rider Management'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LogisticsSearchField(
              controller: _searchController,
              hint: 'Rider name…',
              onSubmitted: (v) => setState(() => _search = v.trim()),
            ),
          ),
          FilterChips(
            options: _statuses,
            selected: _status,
            onSelected: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PagedList<Rider>(
              key: ValueKey('$_status|$_search|$_reloadToken'),
              fetch: (page) => LogisticsService.getRiders(page: page, status: _status, search: _search),
              emptyMessage: 'No riders found.',
              itemBuilder: (context, rider, reload) => ListCard(
                onTap: () => _openRider(rider),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: LogisticsColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.two_wheeler, color: LogisticsColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rider.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [rider.phone, rider.vehicleType, rider.areaName]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' · '),
                            style: const TextStyle(fontSize: 12, color: LogisticsColors.muted),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              StatusBadge(status: rider.applicationStatus),
                              StatusBadge(
                                status: rider.isActive ? 'active' : 'inactive',
                                label: rider.isActive ? 'Active' : 'Inactive',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: LogisticsColors.muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
