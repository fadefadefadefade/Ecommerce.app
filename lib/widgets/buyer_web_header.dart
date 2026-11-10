import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'buyer_kit.dart' show kOrange;
import 'responsive.dart';

/// The buyer header for tablets (the design's header shell): white, the logo, the white search bar with the orange button, and
/// messages / notifications / cart / account on the right. The page links are the bottom tabs, like on phones.
class BuyerWebHeader extends StatefulWidget implements PreferredSizeWidget {
  final int currentTab;
  final int cartCount;
  final ValueChanged<int> onTab;          // the main tabs: 0 Home, 1 Shop, 2 Cart, 3 Account
  final VoidCallback onMessages;
  final VoidCallback onNotifications;
  final VoidCallback? onWishlist;
  final ValueChanged<String> onSearch;
  final String? accountName;   // shown in the account pill, like the website

  const BuyerWebHeader({
    super.key,
    required this.currentTab,
    required this.cartCount,
    required this.onTab,
    required this.onMessages,
    required this.onNotifications,
    this.onWishlist,
    required this.onSearch,
    this.accountName,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

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
        style: IconButton.styleFrom(backgroundColor: active ? Alvy.orangeSoft : null),
        icon: Badge(
          isLabelVisible: badge > 0,
          label: Text(badge > 99 ? '99+' : '$badge'),
          backgroundColor: kOrange,
          textColor: Colors.white,
          child: Icon(icon, color: active ? kOrange : Alvy.slate),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.currentTab;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1.5,
      shadowColor: const Color(0x332A1A10),
      child: SafeArea(
        bottom: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
          height: widget.preferredSize.height,
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
                      decoration: BoxDecoration(color: Alvy.isDark ? const Color(0xFFFFE4DC) : Alvy.subtle, borderRadius: BorderRadius.circular(12)),
                      child: Image.asset('assets/images/logo-mark.png', fit: BoxFit.contain),
                    ),
                    if (!_compact) ...[
                      const SizedBox(width: 10),
                      Text('ALVY', style: Alvy.display(size: 22, color: Theme.of(context).colorScheme.onSurface)),
                    ],
                  ]),
                ),
                SizedBox(width: _compact ? 12 : 24),
                Expanded(
                  child: Container(
                    height: 46,
                    constraints: const BoxConstraints(maxWidth: 640),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search, color: Alvy.textMuted, size: 20),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _submit(),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
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
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
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
                if (widget.onWishlist != null) _icon(Icons.favorite_border_rounded, 'Wishlist', widget.onWishlist!, active: t == 2),
                _icon(Icons.notifications_none, 'Notifications', widget.onNotifications),
                _icon(Icons.shopping_cart_outlined, 'Cart', () => widget.onTab(3), badge: widget.cartCount, active: t == 3),
                const SizedBox(width: 6),
                _accountPill(t == 4),
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
      color: active ? Alvy.orangeSoft : Theme.of(context).colorScheme.surfaceContainer,
      shape: StadiumBorder(side: BorderSide(color: active ? kOrange : Colors.transparent, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => widget.onTab(4),
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
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
            Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
          ]),
        ),
      ),
    );
  }
}
