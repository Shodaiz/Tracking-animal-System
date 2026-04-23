import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'local_db_service.dart';
import 'notification_service.dart';


class SyncService {
  static bool _isSyncing = false;

  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  static void listenConnectivity(Function onOnline) {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        onOnline();
      }
    });
  }

  static Future<int> syncPendingActions() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int synced = 0;

    try {
      final isConnected = await isOnline();
      if (!isConnected) return 0;

      final pending = await LocalDbService.getPendingActions();

      for (final action in pending) {
        try {
          final payload = jsonDecode(action['payload']);

          switch (action['action']) {
            case 'declare_constat':
              await ApiService.declareConstat(payload['farmId'], payload['description']);
              break;
            case 'add_health_record':
              await ApiService.addHealthRecord(
                  payload['rfidTag'], payload['recordType'], payload['diagnosis'], payload['treatment']);
              break;
            case 'confirm_check':
              await ApiService.confirmCheck(payload['farmId']);
              break;
            case 'create_animal':
              await ApiService.createAnimal(payload);
              break;
          }

          await LocalDbService.markActionSynced(action['id']);
          synced++;
        } catch (e) {
          // skip failed actions
        }
      }

      if (synced > 0) {
        await NotificationService.show(
          title: '✅ Synchronisation',
          body: '$synced action(s) synchronisée(s)',
        );
      }
    } finally {
      _isSyncing = false;
    }

    return synced;
  }

  static Future<void> syncAnimals() async {
    try {
      final isConnected = await isOnline();
      if (!isConnected) return;
      final animals = await ApiService.getMyAnimals();
      await LocalDbService.cacheAnimals(animals);
    } catch (e) {
      // ignore
    }
  }
}