import 'package:flutter/material.dart';

import '../../services/buyer_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import '../../widgets/net_image.dart';
import 'shop_screen.dart';

/// The website's All Categories (categories): every category with its subcategories.
/// A category opens its page; a subcategory opens that part of it.
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
        child: RefreshIndicator(
          color: kOrange,
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            for (final cat in _categories)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: cat['image_url'] != null
                            ? NetImage(cat['image_url'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF4F7FA)))
                            : Container(color: const Color(0xFFF4F7FA)),
                      ),
                    ),
                    title: Text('${cat['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${(cat['subcategories'] as List? ?? []).length} subcategories', style: TextStyle(fontSize: 12, color: c.muted)),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: [
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        ActionChip(
                          label: const Text('All items'),
                          avatar: const Icon(Icons.grid_view, size: 16),
                          onPressed: () => _open(cat),
                        ),
                        for (final s in (cat['subcategories'] as List? ?? []))
                          ActionChip(label: Text('$s'), onPressed: () => _open(cat, '$s')),
                      ]),
                    ],
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
