import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/buyer_colors.dart';
import 'motion.dart';
import 'responsive.dart';

/// One tab of a staff portal (seller, logistics, rider): its icon, label and page.
typedef StaffTab = (IconData, String, Widget);

/// The staff portals' frame. Phones keep the bottom navigation; tablets get the design's
/// operations console layout: a left sidebar (brand, place chip, numbered menu with the active
/// item in an orange pill, the signed-in person at the bottom) and the page beside it.
class StaffShell extends StatelessWidget {
  /// The part after "ALVY." in the sidebar brand (SELLER, OPS, RIDER…).
  final String brand;
  /// The small chip under the brand (store / company / hub name) and its status word.
  final String place;
  final String status;
  final String userName;
  final String userRole;
  final List<StaffTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;
  /// The pages (an IndexedStack built by the portal, so its tab state stays as it was).
  final Widget body;
  /// Optional count badges, by tab index.
  final Map<int, int> badges;

  const StaffShell({
    super.key,
    required this.brand,
    required this.place,
    this.status = 'ONLINE',
    required this.userName,
    required this.userRole,
    required this.tabs,
    required this.index,
    required this.onSelect,
    required this.body,
    this.badges = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isWide(context)) {
      return Scaffold(
        body: TabFade(value: index, child: body),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          indicatorColor: Alvy.orange.withValues(alpha: 0.12),
          onDestinationSelected: onSelect,
          destinations: [
            for (final t in tabs) NavigationDestination(icon: Icon(t.$1), selectedIcon: Icon(t.$1, color: Alvy.orange), label: t.$2),
          ],
        ),
      );
    }
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          width: 248,
          decoration: BoxDecoration(
            color: c.surface,
            boxShadow: const [BoxShadow(color: Color(0x142A1A10), blurRadius: 18, offset: Offset(3, 0))],
          ),
          child: SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Brand: the orange dot, ALVY in navy and the portal name.
                Row(children: [
                  Container(width: 9, height: 9, decoration: const BoxDecoration(color: Alvy.orange, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'ALVY', style: TextStyle(color: Alvy.slate)),
                        const TextSpan(text: '.', style: TextStyle(color: Alvy.orange)),
                        TextSpan(text: brand, style: TextStyle(color: Alvy.slate)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Alvy.display(size: 19, weight: FontWeight.w800),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                // Place chip: where this console is signed in.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.storefront_outlined, size: 16, color: Alvy.slate),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(place,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.text)),
                    ),
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Alvy.orange, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(status, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Alvy.orange)),
                  ]),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < tabs.length; i++) _item(context, i),
                const Spacer(),
                // The signed-in person.
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: Alvy.orange,
                      child: Text(userName.trim().isEmpty ? '?' : userName.trim()[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: c.text)),
                        Text(userRole, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        Expanded(child: TabFade(value: index, child: body)),
      ]),
    );
  }

  Widget _item(BuildContext context, int i) {
    final c = context.bc;
    final on = i == index;
    final badge = badges[i] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: on ? Alvy.orange : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        elevation: on ? 3 : 0,
        shadowColor: const Color(0x55FA4E1C),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelect(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Icon(tabs[i].$1, size: 20, color: on ? Colors.white : c.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tabs[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: on ? 15 : 14.5, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? Colors.white : c.text)),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: 0.25) : Alvy.orangeDark, borderRadius: BorderRadius.circular(99)),
                  child: Text(badge > 99 ? '99+' : '$badge', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                )
              else
                Text((i + 1).toString().padLeft(2, '0'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white70 : c.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Pages opened on top of a staff portal stay a readable column in the middle of a wide tablet
/// (the portal itself has the sidebar). Used as the app's page transition on Android and iOS.
class StaffPageFrame extends PageTransitionsBuilder {
  const StaffPageFrame();

  /// Set from main.dart: true while a seller, rider or logistics account is signed in.
  static bool enabled = false;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    var page = child;
    final size = MediaQuery.sizeOf(context);
    if (enabled && !route.isFirst && size.shortestSide >= 600 && size.width > 900) {
      page = ColoredBox(
        color: Alvy.isDark ? const Color(0xFF0F0C0A) : const Color(0xFFF1E7DF),
        child: Center(
          child: SizedBox(
            width: 860,
            child: DecoratedBox(
              decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 24)]),
              child: MediaQuery(data: MediaQuery.of(context).copyWith(size: Size(860, size.height)), child: child),
            ),
          ),
        ),
      );
    }
    // Flutter's own transition for the platform (unchanged), around the framed page.
    return const PageTransitionsTheme().buildTransitions<T>(route, context, animation, secondaryAnimation, page);
  }
}
