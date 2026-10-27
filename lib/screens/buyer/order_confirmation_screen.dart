import 'package:flutter/material.dart';

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
    final total = orders.fold<double>(0, (s, o) => s + asNum(o['total']));
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar( title: const Text('Order placed')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Icon(Icons.check_circle, size: 72, color: Color(0xFF15803D)),
        const SizedBox(height: 8),
        Text(
          orders.isEmpty ? (message ?? 'Your order was placed.') : 'Thank you! ${orders.length == 1 ? 'Your order was' : '${orders.length} orders were'} placed.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.bc.text),
        ),
        const SizedBox(height: 16),
        for (final o in orders)
          SectionCard(
            title: '${o['number']} · ${o['store']}',
            trailing: Text(o['status_label'] ?? '', style: const TextStyle(color: kOrange, fontSize: 12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final i in o['items'])
                Text('${i['title']}${i['variation'] != null ? ' (${i['variation']})' : ''} × ${i['quantity']}', style: TextStyle(color: context.bc.textSecondary)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text('Total ${peso(o['total'])}', style: const TextStyle(fontWeight: FontWeight.w700))),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o['id']))),
                  child: const Text('View order'),
                ),
              ]),
            ]),
          ),
        if (orders.length > 1) Text('Grand total ${peso(total)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, color: kOrange)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen())),
          style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46)),
          child: const Text('Go to My Purchases'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const BuyerMainScreen()), (r) => false),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          child: const Text('Continue Shopping'),
        ),
      ]),
    );
  }
}
