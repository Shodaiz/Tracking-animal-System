import 'local_db_service.dart';
import 'notification_service.dart';

class AlarmService {
  /// Vérifie les alertes et crée des notifications
  static Future<void> checkAlarms(List<dynamic> animals) async {
    // Alerte : animaux inactifs
    for (final a in animals) {
      if (a['status'] == 'Quarantined') {
        await NotificationService.show(
          title: '⚠️ Animal en quarantaine',
          body: 'L\'animal ${a['rfidTag']} (${a['breed']}) est en quarantaine',
          id: a['id'] ?? 0,
        );
      }

      if (a['status'] == 'Lost') {
        await NotificationService.show(
          title: '🚨 Animal perdu',
          body: 'L\'animal ${a['rfidTag']} (${a['breed']}) est déclaré perdu',
          id: (a['id'] ?? 0) + 1000,
        );
      }
    }

    // Log
    await LocalDbService.addAuditLog('ALARM_CHECK', 'Vérification des alertes effectuée', 'system');
  }

  /// Vérifie le nombre d'actions hors ligne non synchronisées
  static Future<void> checkPendingSync() async {
    final pending = await LocalDbService.getPendingActions();
    if (pending.length >= 5) {
      await NotificationService.show(
        title: '📡 Synchronisation requise',
        body: '${pending.length} action(s) en attente de synchronisation',
        id: 9999,
      );
    }
  }
}