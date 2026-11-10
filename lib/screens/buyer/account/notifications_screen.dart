import 'package:flutter/material.dart';
import '../../../services/buyer_api.dart';
import '../../../widgets/web_links.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/buyer_kit.dart' show cardBox;
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
      // Every role reads its notifications from the web API (/api/v1/notifications).
      final r = await BuyerApi.notifications(page: _page + 1);
      if (!mounted) return;
      if (!r.ok) throw Exception(r.message);
      setState(() {
        _items.addAll((r.body['data'] as List).map((e) {
          final n = Map<String, dynamic>.from(e);
          n['read_at'] = n['read'] == true ? n['created_at'] : null;
          return n;
        }));
        _page = toNum(r.body['meta']['current_page']).toInt();
        _lastPage = toNum(r.body['meta']['last_page']).toInt();
        _unread = toNum(r.body['unread']).toInt();
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    // Like the website: opening marks it read and goes to what it is about.
    if (n['read_at'] == null) {
      setState(() {
        n['read_at'] = DateTime.now().toIso8601String();
        _unread = (_unread - 1).clamp(0, 1 << 30);
      });
    }
    final r = await BuyerApi.openNotification(n['id']);
    if (mounted && r.ok) await openWebPath(context, r.body['redirect'] ?? n['link']);
  }

  Future<void> _markAllRead() async {
    try {
      final r = await BuyerApi.readAllNotifications();
      if (!r.ok) throw Exception(r.message);
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
        return Icons.receipt_long_outlined;
      case 'delivery':
      case 'shipping':
        return Icons.local_shipping_outlined;
      case 'promo':
        return Icons.local_offer_outlined;
      case 'success':
        return Icons.check_circle_outline;
      case 'warning':
      case 'error':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  /// Orange for orders and promos, navy for deliveries, red for problems (the logo's two colors first).
  (Color, Color) _tone(String? type) => switch (type) {
        'delivery' || 'shipping' => (Alvy.slate, Alvy.slateSoft),
        'warning' || 'error' => (const Color(0xFFDC2626), Alvy.dangerSoft),
        'success' => (const Color(0xFF15803D), Alvy.successSoft),
        _ => (Alvy.orange, Alvy.orangeSoft),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: accountAppBar('Notifications'),
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
                    action: FilledButton(onPressed: _refresh, child: const Text('Retry')),
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

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _items.length + 1 + (_loading ? 1 : 0),
      itemBuilder: (context, i) {
        // The design's header: how many are unread, and "Mark all read".
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('INBOX', style: TextStyle(fontSize: 11.5, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: c.textSecondary)),
                  Text(_unread > 0 ? '$_unread unread' : 'All caught up', style: Alvy.display(size: 20, color: c.text, weight: FontWeight.w700)),
                ]),
              ),
              if (_unread > 0)
                TextButton.icon(
                  onPressed: _markAllRead,
                  style: TextButton.styleFrom(backgroundColor: c.subtle, padding: const EdgeInsets.symmetric(horizontal: 14)),
                  icon: const Icon(Icons.done_all, size: 18, color: Alvy.orange),
                  label: const Text('Mark all read', style: TextStyle(color: Alvy.orange, fontWeight: FontWeight.w700)),
                ),
            ]),
          );
        }
        final k = i - 1;
        if (k >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: BuyerPalette.primary)),
          );
        }
        final n = _items[k];
        final unread = n['read_at'] == null;
        final (fg, bg) = _tone(n['type']);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: cardBox(context, radius: 16, color: unread ? Alvy.orangeSoft : null).copyWith(
            border: unread ? Border.all(color: Alvy.orange.withValues(alpha: 0.25)) : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _markRead(n),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(_icon(n['type']), color: fg, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Text(n['title'] ?? '',
                              style: TextStyle(color: c.text, fontWeight: unread ? FontWeight.w700 : FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Text(timeAgo(n['created_at']), style: TextStyle(fontSize: 11.5, color: c.muted)),
                      ]),
                      if ((n['body'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(n['body'], style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.35)),
                      ],
                    ]),
                  ),
                  if (unread)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 6, left: 8),
                      decoration: const BoxDecoration(color: Alvy.orange, shape: BoxShape.circle),
                    ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
