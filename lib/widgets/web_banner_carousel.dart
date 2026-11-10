import 'dart:async';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import 'buyer_kit.dart' show kOrange;

/// One slide of the home banner. [img] is a full photo URL.
typedef WebSlide = ({String img, Alignment focus, String eyebrow, String title, String mark, String sub, String button, String? categorySlug, String? categoryName});

/// The home page's big banner: photo slides with the label, the headline (last words underlined in orange), a line
/// of text and the button; it moves on by itself every few seconds, and the dots show where it is. The slides come
/// from the server (the admin's event banners first, then ALVY's own); until they load, ALVY's own show.
class WebBannerCarousel extends StatefulWidget {
  final void Function(WebSlide slide) onShop;
  final List<dynamic> banners;   // /home "banners"
  const WebBannerCarousel({super.key, required this.onShop, this.banners = const []});

  static String _img(String name) => '${ApiConfig.webUrl}/images/banners/$name.jpg';

  static final List<WebSlide> builtIn = [
    (img: _img('shop'), focus: const Alignment(0, -0.4), eyebrow: 'Shop local', title: 'Bringing more to your', mark: 'cart',
        sub: 'Everyday finds from local sellers, delivered to your barangay.', button: 'Shop now', categorySlug: null, categoryName: null),
    (img: _img('fashion'), focus: Alignment.center, eyebrow: 'Apparel', title: 'Refresh your', mark: 'wardrobe',
        sub: 'Tops, dresses and outerwear from shops near you.', button: 'Shop now', categorySlug: 'womens-apparel', categoryName: "Women's Apparel"),
    (img: _img('tech'), focus: const Alignment(0, 0.2), eyebrow: 'Electronics', title: 'Gadgets for', mark: 'every day',
        sub: 'Laptops, phones, audio and the accessories that go with them.', button: 'Shop now', categorySlug: 'electronics-and-gadgets', categoryName: 'Electronics & Gadgets'),
    (img: _img('home'), focus: const Alignment(0, 0.2), eyebrow: 'Home & Garden', title: 'Make home a little', mark: 'cozier',
        sub: 'Furniture, decor and plants to make a space your own.', button: 'Shop now', categorySlug: 'home-and-garden', categoryName: 'Home & Garden'),
  ];

  /// The website's "center 30%" as an alignment (0% top, 50% middle, 100% bottom).
  static Alignment _focus(dynamic css) {
    final m = RegExp(r'(\d+(?:\.\d+)?)%').firstMatch('${css ?? ''}');
    if (m == null) return Alignment.center;
    return Alignment(0, (double.parse(m[1]!) / 50 - 1).clamp(-1.0, 1.0));
  }

  List<WebSlide> get slides {
    final fromServer = [
      for (final b in banners)
        if (b is Map && (b['image_url'] ?? '').toString().isNotEmpty)
          (
            img: '${b['image_url']}',
            focus: _focus(b['focus']),
            eyebrow: '${b['eyebrow'] ?? ''}',
            title: '${b['title'] ?? ''}',
            mark: '${b['highlight'] ?? ''}',
            sub: '${b['subtitle'] ?? ''}',
            button: '${b['button'] ?? 'Shop now'}',
            categorySlug: b['category_slug'] as String?,
            categoryName: b['category_name'] as String?,
          ),
    ];
    return fromServer.isEmpty ? builtIn : fromServer;
  }

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
      final n = widget.slides.length;
      if (n < 2) return;
      _pages.animateToPage((_page + 1) % n, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
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
    final slides = widget.slides;
    if (_page >= slides.length) _page = 0;
    // Phones: a shorter card with the text at the bottom (the design's home hero); tablets: the tall banner.
    final phone = MediaQuery.sizeOf(context).width < 600;
    final pad = phone ? 20.0 : 32.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(phone ? 20 : 24),
      child: SizedBox(
        height: phone ? 270 : 340,
        child: Stack(children: [
          PageView.builder(
            controller: _pages,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final s = slides[i];
              return Stack(fit: StackFit.expand, children: [
                Image.network(s.img, fit: BoxFit.cover, alignment: s.focus,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1B17))),
                // A dark fade from the bottom (phones) or the left (tablets) so the white text reads on any photo.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: phone
                        ? const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                            colors: [Color(0xE61E1B17), Color(0x731E1B17), Color(0x001E1B17)], stops: [0, .5, 1])
                        : const LinearGradient(colors: [Color(0xD91E1B17), Color(0x731E1B17), Color(0x001E1B17)], stops: [0, .45, .8]),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 20, pad, phone ? 22 : 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: phone ? MainAxisAlignment.end : MainAxisAlignment.center,
                    children: [
                      // Eyebrow: a frosted pill.
                      if (s.eyebrow.isNotEmpty) Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(20)),
                        child: Text(s.eyebrow.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                      ),
                      if (s.eyebrow.isNotEmpty) const SizedBox(height: 8),
                      // The headline, with an orange bar under the last words.
                      Wrap(crossAxisAlignment: WrapCrossAlignment.end, children: [
                        Text('${s.title} ', style: Alvy.display(size: phone ? 26 : 36, color: Colors.white, weight: FontWeight.w800)),
                        if (s.mark.isNotEmpty) IntrinsicWidth(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                            Text(s.mark, style: Alvy.display(size: phone ? 26 : 36, color: Colors.white, weight: FontWeight.w800)),
                            Container(height: 3, decoration: BoxDecoration(color: Alvy.orangeLight, borderRadius: BorderRadius.circular(2))),
                          ]),
                        ),
                      ]),
                      if (s.sub.isNotEmpty) const SizedBox(height: 8),
                      if (s.sub.isNotEmpty) ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Text(s.sub, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: phone ? 13.5 : 15, height: 1.4)),
                      ),
                      SizedBox(height: phone ? 14 : 18),
                      FilledButton.icon(
                        onPressed: () => widget.onShop(s),
                        style: FilledButton.styleFrom(
                            backgroundColor: kOrange, minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                        icon: Text(s.button, style: const TextStyle(fontWeight: FontWeight.w700)),
                        label: const Icon(Icons.arrow_forward, size: 18),
                      ),
                    ],
                  ),
                ),
              ]);
            },
          ),
          // Dots: the current slide is a long pill.
          Positioned(
            right: phone ? 20 : null,
            left: phone ? null : 32,
            bottom: phone ? 34 : 16,
            child: Row(children: [
              for (var i = 0; i < slides.length; i++)
                GestureDetector(
                  onTap: () => _pages.animateToPage(i, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(left: 6),
                    width: i == _page ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: i == _page ? 1 : .45), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
            ]),
          ),
          // Arrows, as in the design.
          if (!phone)
            for (final (dir, align) in [(-1, Alignment.centerLeft), (1, Alignment.centerRight)])
              Align(
                alignment: align,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Material(
                    color: Colors.white.withValues(alpha: .28),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _pages.animateToPage((_page + dir) % slides.length, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                      child: SizedBox(width: 36, height: 36, child: Icon(dir < 0 ? Icons.chevron_left : Icons.chevron_right, color: Colors.white)),
                    ),
                  ),
                ),
              ),
          if (phone)
            Positioned(
              right: 14,
              top: 14,
              child: Material(
                color: Colors.white.withValues(alpha: .28),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _pages.animateToPage((_page + 1) % slides.length, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                  child: const SizedBox(width: 32, height: 32, child: Icon(Icons.chevron_right, color: Colors.white, size: 20)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
