import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/buyer_colors.dart';

// Shared profile layout (header card, info card, action grid) used by the
// buyer, seller and logistics profile screens so they all look the same.

const _primary = Color(0xFFFA4E1C);

List<BoxShadow> _softShadow() => [
      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
    ];

class ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String roleLabel;
  final IconData? roleIcon;
  final Color avatarColor;

  const ProfileHeaderCard({
    super.key,
    required this.name,
    required this.email,
    required this.roleLabel,
    this.roleIcon,
    this.avatarColor = const Color(0xFF002B4D),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _softShadow(),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'User' : name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (roleIcon != null) ...[
                        Icon(roleIcon, size: 12, color: _primary),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        roleLabel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: c.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  final String title;
  final List<(String label, String value)> items;
  final VoidCallback? onEdit;

  const ProfileInfoCard({super.key, required this.title, required this.items, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.text)),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          for (final (label, value) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
                  const SizedBox(height: 4),
                  Text(
                    value.isEmpty ? '—' : value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ProfileAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ProfileAction({required this.icon, required this.label, required this.color, required this.onTap});

  /// Standard red-orange Logout tile with a confirmation dialog.
  factory ProfileAction.logout(BuildContext context) => ProfileAction(
        icon: Icons.logout,
        label: 'Logout',
        color: _primary,
        onTap: () => confirmLogout(context),
      );
}

class ProfileActionGrid extends StatelessWidget {
  final List<ProfileAction> actions;

  const ProfileActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _softShadow(),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: action.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(action.icon, color: action.color, size: 28),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      action.label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Scaffold + scrolling column used by every profile screen.
class ProfileScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const ProfileScaffold({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }
}

Future<void> confirmLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    // Each role's main screen sends the user back to the login screen.
    await context.read<AuthProvider>().logout();
  }
}

String memberSince(DateTime? date) {
  if (date == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
