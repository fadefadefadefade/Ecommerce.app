import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'buyer_kit.dart' show kOrange;
import 'responsive.dart';

/// The website's buyer header for tablets: navy, the logo, the white search bar with the orange button, and
/// messages / notifications / cart / account on the right. The page links are the bottom tabs, like on phones.
class BuyerWebHeader extends StatefulWidget implements PreferredSizeWidget {
  final int currentTab;
  final int cartCount;
  final ValueChanged<int> onTab;          // the main tabs: 0 Home, 1 Shop, 2 Cart, 3 Account
  final VoidCallback onMessages;
  final VoidCallback onNotifications;
  final ValueChanged<String> onSearch;
  final String? accountName;   // shown in the account pill, like the website

  const BuyerWebHeader({
    super.key,
    required this.currentTab,
    required this.cartCount,
    required this.onTab,
    required this.onMessages,
    required this.onNotifications,
    required this.onSearch,
    this.accountName,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  State<BuyerWebHeader> createState() => _BuyerWebHeaderState();
}

class _BuyerWebHeaderState extends State<BuyerWebHeader> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _search.text.trim();
    if (q.isNotEmpty) widget.onSearch(q);
  }

  /// Narrower tablets (portrait): the logo without the word, tighter spacing.
  bool get _compact => MediaQuery.sizeOf(context).width < 900;

  Widget _icon(IconData icon, String tip, VoidCallback onTap, {int badge = 0, bool active = false}) => IconButton(
        tooltip: tip,
        onPressed: onTap,
        style: IconButton.styleFrom(backgroundColor: active ? Colors.white.withValues(alpha: .15) : null),
        icon: Badge(
          isLabelVisible: badge > 0,
          label: Text(badge > 99 ? '99+' : '$badge'),
          backgroundColor: Colors.white,
          textColor: kOrange,
          child: Icon(icon, color: Colors.white),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.currentTab;
    return Material(
      color: Alvy.navy,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // The website's thin orange line along the top of the header.
          Container(height: 3, color: kOrange),
          SizedBox(
          height: widget.preferredSize.height - 3,
          child: WebWidth(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                InkWell(
                  onTap: () => widget.onTab(0),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Image.asset('assets/images/logo-mark.png', fit: BoxFit.contain),
                    ),
                    if (!_compact) ...[
                      const SizedBox(width: 10),
                      Text('ALVY', style: Alvy.display(size: 22, color: Colors.white)),
                    ],
                  ]),
                ),
                SizedBox(width: _compact ? 12 : 24),
                Expanded(
                  child: Container(
                    height: 42,
                    constraints: const BoxConstraints(maxWidth: 640),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.search, color: Alvy.textMuted, size: 20),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _submit(),
                          style: const TextStyle(color: Alvy.navy, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Search products, brands, categories…',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Material(
                          color: kOrange,
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: _submit,
                            child: const SizedBox(width: 44, height: 34, child: Icon(Icons.search, color: Colors.white, size: 20)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                SizedBox(width: _compact ? 2 : 8),
                _icon(Icons.chat_bubble_outline, 'Messages', widget.onMessages),
                _icon(Icons.notifications_none, 'Notifications', widget.onNotifications),
                _icon(Icons.shopping_cart_outlined, 'Cart', () => widget.onTab(2), badge: widget.cartCount, active: t == 2),
                const SizedBox(width: 6),
                _accountPill(t == 3),
              ]),
            ),
          ),
        ),
        ]),
      ),
    );
  }

  /// The website's account button: a white pill with the orange avatar and the first name.
  Widget _accountPill(bool active) {
    final name = (widget.accountName ?? '').trim();
    final first = name.isEmpty ? 'Account' : name.split(' ').first;
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: active ? kOrange : Colors.white, width: 2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => widget.onTab(3),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: kOrange,
              child: Text(first.isEmpty ? '?' : first[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            if (!_compact) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(first, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kOrange, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
            const Icon(Icons.keyboard_arrow_down, color: kOrange, size: 18),
          ]),
        ),
      ),
    );
  }
}
