import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import 'account/my_orders_screen.dart';
import 'account/order_detail_screen.dart';
import 'buyer_main_screen.dart';

/// The website's order confirmation (checkout/confirmation): one order per store from this checkout.
class OrderConfirmationScreen extends StatelessWidget {
  final List orders;
  final String? message;

  const OrderConfirmationScreen({super.key, required this.orders, this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final total = orders.fold<double>(0, (s, o) => s + asNum(o['total']));
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Order placed')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        // The design's success card: a big check, "Order Confirmed!", thank-you line and the order numbers.
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: cardBox(context, radius: 20),
          child: Column(children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: Alvy.successSoft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 36, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(99)),
              child: Text('Order Confirmed!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary)),
            ),
            const SizedBox(height: 10),
            Text('Thank you!', textAlign: TextAlign.center, style: Alvy.display(size: 26, color: c.text, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              orders.isEmpty
                  ? (message ?? 'Your order was placed.')
                  : '${orders.length == 1 ? 'Your order ${orders.first['number']} has' : '${orders.length} orders have'} been placed and sent to the store${orders.length == 1 ? '' : 's'}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, height: 1.4),
            ),
          ]),
        ),
        for (final o in orders)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: cardBox(context, radius: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(Icons.inventory_2_outlined, color: Alvy.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${o['store']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w700)),
                    Text('${o['number']}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(99)),
                  child: Text(o['status_label'] ?? '', style: const TextStyle(color: Alvy.orangeDark, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  for (final i in o['items'])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(
                          child: Text('${i['title']}${i['variation'] != null ? ' (${i['variation']})' : ''}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text)),
                        ),
                        Text('× ${i['quantity']}', style: TextStyle(color: c.textSecondary)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    Text(peso(o['total']), style: Alvy.display(size: 20, color: Alvy.orange, weight: FontWeight.w800)),
                  ]),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o['id']))),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: c.subtle,
                    side: BorderSide.none,
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('View order', style: TextStyle(color: c.text, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        if (orders.length > 1)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Expanded(child: Text('Total Paid', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700))),
              Text(peso(total), style: Alvy.display(size: 22, color: Alvy.orange, weight: FontWeight.w800)),
            ]),
          ),
        FilledButton.icon(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen())),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.receipt_long_outlined, size: 20),
          label: const Text('Go to My Purchases', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const BuyerMainScreen()), (r) => false),
          icon: const Text('Continue Shopping', style: TextStyle(fontWeight: FontWeight.w700)),
          label: const Icon(Icons.arrow_forward, size: 18),
        ),
      ]),
    );
  }
}
