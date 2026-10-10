import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../theme/buyer_colors.dart';
import 'account_ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _lastPage = 1;
  int _unread = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) _loadMore();
    });
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 0;
      _lastPage = 1;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _lastPage) return;
    setState(() => _loading = true);
    try {
      final data = ApiService.unwrap(await ApiService.get('/notifications?page=${_page + 1}'));
      if (!mounted) return;
      final pagination = Map<String, dynamic>.from(data['pagination'] ?? {});
      setState(() {
        _items.addAll((data['notifications'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)));
        _page = toNum(pagination['current_page']).toInt();
        _lastPage = toNum(pagination['last_page']).toInt();
        _unread = toNum(data['unread_count']).toInt();
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['read_at'] != null) return;
    setState(() {
      n['read_at'] = DateTime.now().toIso8601String();
      _unread = (_unread - 1).clamp(0, 1 << 30);
    });
    try {
      ApiService.unwrap(await ApiService.post('/notifications/${n['id']}/read'));
    } catch (_) {
      // Not critical; it will show as unread again on the next refresh.
    }
  }

  Future<void> _markAllRead() async {
    try {
      ApiService.unwrap(await ApiService.post('/notifications/read-all'));
      if (!mounted) return;
      final now = DateTime.now().toIso8601String();
      setState(() {
        for (final n in _items) {
          n['read_at'] ??= now;
        }
        _unread = 0;
      });
    } catch (e) {
      if (mounted) showAccountSnack(context, errorText(e), error: true);
    }
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'order':
        return Icons.receipt_long;
      case 'delivery':
      case 'shipping':
        return Icons.local_shipping;
      case 'promo':
        return Icons.local_offer;
      case 'success':
        return Icons.check_circle;
      case 'warning':
      case 'error':
        return Icons.warning_amber;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: accountAppBar(
        _unread > 0 ? 'Notifications ($_unread)' : 'Notifications',
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: BuyerPalette.primary,
        onRefresh: _refresh,
        child: _buildBody(c),
      ),
    );
  }

  Widget _buildBody(BuyerPalette c) {
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator(color: BuyerPalette.primary));
      return ListView(
        children: [
          SizedBox(
            height: 450,
            child: _error != null
                ? AccountEmptyState(
                    icon: Icons.wifi_off,
                    title: 'Could not load notifications',
                    message: _error!,
                    action: ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
                  )
                : const AccountEmptyState(
                    icon: Icons.notifications_none,
                    title: 'No notifications',
                    message: 'Updates about your orders and account will appear here.',
                  ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      itemCount: _items.length + (_loading ? 1 : 0),
      separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: BuyerPalette.primary)),
          );
        }
        final n = _items[i];
        final unread = n['read_at'] == null;
        return Material(
          color: unread ? BuyerPalette.primary.withValues(alpha: 0.06) : c.surface,
          child: InkWell(
            onTap: () => _markRead(n),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: BuyerPalette.primary.withValues(alpha: 0.12),
                    child: Icon(_icon(n['type']), color: BuyerPalette.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n['title'] ?? '',
                          style: TextStyle(
                            color: c.text,
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if ((n['body'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(n['body'], style: TextStyle(fontSize: 13, color: c.textSecondary)),
                        ],
                        const SizedBox(height: 4),
                        Text(timeAgo(n['created_at']), style: TextStyle(fontSize: 11, color: c.muted)),
                      ],
                    ),
                  ),
                  if (unread)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, left: 6),
                      decoration: const BoxDecoration(color: BuyerPalette.primary, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
