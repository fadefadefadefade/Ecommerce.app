import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SortingCenterDashboardScreen extends StatelessWidget {
  const SortingCenterDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: Alvy.page,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Alvy.surface,
                border: Border(
                  bottom: BorderSide(color: Alvy.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sorting Center Dashboard',
                        style: TextStyle(
                          fontSize: 14,
                          color: Alvy.textMuted,
                        ),
                      ),
                      Text(
                        user?.name ?? '',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Alvy.navy,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => context.read<AuthProvider>().logout(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA4E1C),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Sorting Center Dashboard - Coming Soon',
                  style: TextStyle(fontSize: 18, color: Alvy.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
