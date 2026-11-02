import 'dart:async';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import 'buyer_kit.dart' show kOrange;

/// One slide of the website's home banner (resources/views/home/index.blade.php, public/images/banners).
typedef WebSlide = ({String img, Alignment focus, String eyebrow, String title, String mark, String sub, String? categorySlug, String? categoryName});

/// The website's home banner for tablets: photo slides with the eyebrow, the headline (last word in orange),
/// a line of text and "Shop now"; it moves on by itself every few seconds, and the dots show where it is.
class WebBannerCarousel extends StatefulWidget {
  final void Function(WebSlide slide) onShop;
  const WebBannerCarousel({super.key, required this.onShop});

  static const List<WebSlide> slides = [
    (img: 'shop', focus: Alignment(0, -0.4), eyebrow: 'Shop local', title: 'Bringing more to your', mark: 'cart',
        sub: 'Everyday finds from local sellers, delivered to your barangay.', categorySlug: null, categoryName: null),
    (img: 'fashion', focus: Alignment.center, eyebrow: 'Apparel', title: 'Refresh your', mark: 'wardrobe',
        sub: 'Tops, dresses and outerwear from shops near you.', categorySlug: 'womens-apparel', categoryName: "Women's Apparel"),
    (img: 'tech', focus: Alignment(0, 0.2), eyebrow: 'Electronics', title: 'Gadgets for', mark: 'every day',
        sub: 'Laptops, phones, audio and the accessories that go with them.', categorySlug: 'electronics-and-gadgets', categoryName: 'Electronics & Gadgets'),
    (img: 'home', focus: Alignment(0, 0.2), eyebrow: 'Home & Garden', title: 'Make home a little', mark: 'cozier',
        sub: 'Furniture, decor and plants to make a space your own.', categorySlug: 'home-and-garden', categoryName: 'Home & Garden'),
  ];

  @override
  State<WebBannerCarousel> createState() => _WebBannerCarouselState();
}

class _WebBannerCarouselState extends State<WebBannerCarousel> {
  final _pages = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_pages.hasClients) return;
      _pages.animateToPage((_page + 1) % WebBannerCarousel.slides.length, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const slides = WebBannerCarousel.slides;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 320,
        child: Stack(children: [
          PageView.builder(
            controller: _pages,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final s = slides[i];
              return Stack(fit: StackFit.expand, children: [
                Image.network('${ApiConfig.webUrl}/images/banners/${s.img}.jpg', fit: BoxFit.cover, alignment: s.focus,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF002B4D))),
                // The website's dark fade on the left, so the white text reads on any photo.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xCC000000), Color(0x66000000), Color(0x00000000)], stops: [0, .45, .8]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(s.eyebrow.toUpperCase(),
                        style: const TextStyle(color: Color(0xFFFFD7C7), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${s.title} '),
                        TextSpan(text: s.mark, style: const TextStyle(color: Color(0xFFFF8A5B))),
                      ]),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.15),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Text(s.sub, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => widget.onShop(s),
                      style: FilledButton.styleFrom(backgroundColor: kOrange, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                      icon: const Text('Shop now', style: TextStyle(fontWeight: FontWeight.w800)),
                      label: const Icon(Icons.arrow_forward, size: 18),
                    ),
                  ]),
                ),
              ]);
            },
          ),
          // Dots: the current slide is a long bar, like the website.
          Positioned(
            left: 32,
            bottom: 16,
            child: Row(children: [
              for (var i = 0; i < slides.length; i++)
                GestureDetector(
                  onTap: () => _pages.animateToPage(i, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == _page ? 44 : 20,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: i == _page ? 1 : .5), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
