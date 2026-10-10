import 'package:flutter/material.dart';
import '../widgets/logistics_ui.dart';
import 'delivery_assign_tab.dart';
import 'delivery_monitor_tab.dart';

class DeliveriesScreen extends StatelessWidget {
  const DeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: LogisticsColors.background,
        appBar: logisticsAppBar(
          'Deliveries',
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Assignment'),
              Tab(text: 'Monitoring'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DeliveryAssignTab(),
            DeliveryMonitorTab(),
          ],
        ),
      ),
    );
  }
}
