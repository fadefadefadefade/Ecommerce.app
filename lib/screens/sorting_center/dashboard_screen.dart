import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SortingCenterDashboardScreen extends StatelessWidget {
  const SortingCenterDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE6EDF2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sorting Center Dashboard',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B90AA),
                        ),
                      ),
                      Text(
                        user?.name ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF002B4D),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => context.read<AuthProvider>().logout(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFfa4e1c),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Sorting Center Dashboard - Coming Soon',
                  style: TextStyle(fontSize: 18, color: Color(0xFF6B90AA)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
