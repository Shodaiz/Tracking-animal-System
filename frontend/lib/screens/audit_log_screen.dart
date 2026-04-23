import 'package:flutter/material.dart';
import '../services/local_db_service.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<Map<String, dynamic>> logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final data = await LocalDbService.getAuditLog();
    setState(() => logs = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal d\'activité'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: logs.isEmpty
          ? const Center(child: Text('Aucune activité'))
          : ListView.builder(
        itemCount: logs.length,
        itemBuilder: (_, i) {
          final log = logs[i];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF1B5E20),
              radius: 18,
              child: Icon(Icons.history, color: Colors.white, size: 16),
            ),
            title: Text(log['action'] ?? ''),
            subtitle: Text(log['details'] ?? ''),
            trailing: Text(
              log['timestamp']?.substring(0, 16) ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}