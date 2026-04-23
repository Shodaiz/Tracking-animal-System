import 'package:flutter/material.dart';
import '../services/local_db_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> notifs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final data = await LocalDbService.getNotifications();
    await LocalDbService.markAllRead();
    setState(() => notifs = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: notifs.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aucune notification',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      )
          : ListView.builder(
        itemCount: notifs.length,
        itemBuilder: (_, i) {
          final n = notifs[i];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF1B5E20),
              child: Icon(Icons.notifications,
                  color: Colors.white, size: 18),
            ),
            title: Text(n['title'] ?? ''),
            subtitle: Text(n['body'] ?? ''),
            trailing: Text(
              n['timestamp']?.substring(0, 16) ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}