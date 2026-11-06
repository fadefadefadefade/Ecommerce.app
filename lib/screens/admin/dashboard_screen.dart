import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEEE7E0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8A716A),
                        ),
                      ),
                      Text(
                        user?.name ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1B17),
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
            const Expanded(
              child: Center(
                child: Text(
                  'Admin Dashboard - Coming Soon',
                  style: TextStyle(fontSize: 18, color: Color(0xFF8A716A)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
