import 'package:flutter/material.dart';

import '../../services/buyer_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import '../../widgets/net_image.dart';
import 'shop_screen.dart';

/// All Categories: every category on one screen as a grid of round photos with names. A tile opens the category,
/// whose page has its subcategories as pills.
class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.categories();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
      if (r.ok) _categories = [for (final c in (r.body['categories'] as List? ?? [])) Map<String, dynamic>.from(c)];
    });
  }

  void _open(Map<String, dynamic> c, [String? sub]) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopScreen(categorySlug: '${c['slug']}', categoryName: '${c['name']}', subcategory: sub)),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('All Categories')),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: _categories.isEmpty
            ? Center(child: Text('No categories yet.', style: TextStyle(color: c.muted)))
            : LayoutBuilder(builder: (context, box) {
                // Every category on one screen: 3 per row on phones (4–6 on tablets), the tile height
                // stretched to fill the screen, so nothing needs scrolling.
                const pad = 12.0, gap = 10.0;
                final cols = box.maxWidth >= 900 ? 6 : (box.maxWidth >= 600 ? 4 : 3);
                final rows = (_categories.length / cols).ceil();
                final w = (box.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
                final h = ((box.maxHeight - pad * 2 - gap * (rows - 1)) / rows).clamp(92.0, w * 1.35);
                return GridView.builder(
                  padding: const EdgeInsets.all(pad),
                  physics: const ClampingScrollPhysics(),   // only scrolls if it can't fit (very small screens)
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: w / h,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) => _tile(_categories[i]),
                );
              }),
      ),
    );
  }

  /// A category: its round photo and name on a white tile. Its subcategories are pills on the category page.
  Widget _tile(Map<String, dynamic> cat) {
    final c = context.bc;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 1,
      shadowColor: const Color(0x262A1A10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(cat),
        child: LayoutBuilder(builder: (context, box) {
          final size = (box.maxHeight * .5).clamp(40.0, 68.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: c.subtle, shape: BoxShape.circle),
                child: ClipOval(
                  child: cat['image_url'] != null
                      ? NetImage(cat['image_url'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.category_outlined, color: c.muted))
                      : Icon(Icons.category_outlined, color: c.muted),
                ),
              ),
              const SizedBox(height: 6),
              Text('${cat['name']}', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w600, color: c.text)),
            ]),
          );
        }),
      ),
    );
  }
}
