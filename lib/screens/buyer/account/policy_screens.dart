import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../services/buyer_api.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/buyer_kit.dart';

/// The website footer's policies (policies/{key}).
const kPolicies = [
  ('terms_of_service', 'Terms of Service', Icons.gavel_outlined),
  ('privacy_policy', 'Privacy Policy', Icons.privacy_tip_outlined),
  ('return_refund_policy', 'Return & Refund Policy', Icons.assignment_return_outlined),
  ('prohibited_items', 'Prohibited Items Policy', Icons.block_outlined),
  ('seller_policy', 'Seller Policy', Icons.storefront_outlined),
  ('about_us', 'About Us', Icons.info_outline),
];

/// Every policy, like the website's footer links.
class PoliciesScreen extends StatelessWidget {
  const PoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Policies')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Container(
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
          child: Column(children: [
            for (final (i, p) in kPolicies.indexed) ...[
              if (i > 0) Divider(height: 1, color: c.border),
              ListTile(
                leading: Icon(p.$3, color: kOrange),
                title: Text(p.$2),
                trailing: Icon(Icons.chevron_right, color: c.muted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PolicyScreen(policyKey: p.$1, title: p.$2))),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// One policy page (policies/show): the published text, or the website's default, or "not yet published".
class PolicyScreen extends StatefulWidget {
  final String policyKey;
  final String title;
  const PolicyScreen({super.key, required this.policyKey, required this.title});
  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  Map<String, dynamic>? _p;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.policy(widget.policyKey);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
      if (r.ok) _p = r.body;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final p = _p;
    final html = p?['content'] as String?;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text('${p?['title'] ?? widget.title}')),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: p == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.all(14), children: [
                Text('${p['title']}', style: Alvy.display(size: 24, color: c.text)),
                if (p['updated_at'] != null)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('Last updated ${formatDate(p['updated_at'], 'MMMM d, y')}', style: TextStyle(fontSize: 12, color: c.muted))),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
                  child: html == null
                      ? Column(children: [
                          const SizedBox(height: 12),
                          const Text('📄', style: TextStyle(fontSize: 36)),
                          const SizedBox(height: 8),
                          Text('Policy not yet published', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                          const SizedBox(height: 4),
                          Text('This policy is being prepared. Check back soon.', style: TextStyle(color: c.muted)),
                          const SizedBox(height: 12),
                        ])
                      : HtmlWidget(
                          html,
                          textStyle: TextStyle(fontSize: 14, height: 1.55, color: c.textSecondary),
                          customStylesBuilder: (e) => switch (e.localName) {
                            'h2' => {'color': '#002B4D', 'font-weight': '800', 'font-size': '17px', 'margin-top': '18px'},
                            'h3' => {'color': '#002B4D', 'font-weight': '700', 'font-size': '15px'},
                            'a' => {'color': '#FA4E1C', 'font-weight': '600'},
                            'th' || 'td' => {'border': '1px solid #E6EDF2', 'padding': '6px'},
                            _ => e.classes.contains('pp-note') ? {'background-color': '#FFF7F3', 'padding': '10px'} : null,
                          },
                        ),
                ),
                if ((p['others'] as List? ?? []).isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('OTHER POLICIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: c.muted)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final o in (p['others'] as List))
                      ActionChip(
                        label: Text('${o['title']}'),
                        onPressed: () => Navigator.pushReplacement(context,
                            MaterialPageRoute(builder: (_) => PolicyScreen(policyKey: '${o['key']}', title: '${o['title']}'))),
                      ),
                  ]),
                ],
              ]),
      ),
    );
  }
}
