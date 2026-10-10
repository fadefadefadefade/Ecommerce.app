import 'package:flutter/material.dart';
import '../../../models/logistics.dart';
import '../../../services/logistics_service.dart';
import '../widgets/logistics_ui.dart';
import 'chat_conversation_screen.dart';

class ChatContactsScreen extends StatefulWidget {
  const ChatContactsScreen({super.key});

  @override
  State<ChatContactsScreen> createState() => _ChatContactsScreenState();
}

class _ChatContactsScreenState extends State<ChatContactsScreen> {
  final _searchController = TextEditingController();
  List<ChatContact> _contacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contacts = await LogisticsService.getContacts(search: _searchController.text.trim());
      setState(() => _contacts = contacts);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(ChatContact contact) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatConversationScreen(contact: contact)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LogisticsColors.background,
      appBar: logisticsAppBar('Chat / Messaging'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LogisticsSearchField(
              controller: _searchController,
              hint: 'Search users…',
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _contacts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: LogisticsColors.primary));
    }
    if (_error != null && _contacts.isEmpty) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      color: LogisticsColors.primary,
      onRefresh: _load,
      child: _contacts.isEmpty
          ? ListView(children: const [EmptyState(message: 'No users found.')])
          : ListView.separated(
              itemCount: _contacts.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final c = _contacts[i];
                return ListTile(
                  tileColor: Colors.white,
                  leading: CircleAvatar(
                    backgroundColor: LogisticsColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: LogisticsColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(c.roleLabel, style: const TextStyle(fontSize: 12)),
                  trailing: c.unread > 0
                      ? CircleAvatar(
                          radius: 11,
                          backgroundColor: LogisticsColors.primary,
                          child: Text(
                            '${c.unread}',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        )
                      : null,
                  onTap: () => _open(c),
                );
              },
            ),
    );
  }
}
