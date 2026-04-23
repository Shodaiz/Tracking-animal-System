import 'package:nfc_manager/nfc_manager.dart';

class NfcService {
  static Future<bool> isNfcAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      return false;
    }
  }

  static Future<void> startScan({
    required Function(String tagId) onTagDetected,
    required Function(String error) onError,
  }) async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        onError('NFC non disponible sur cet appareil');
        return;
      }

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            String tagId = _extractTagId(tag);
            onTagDetected(tagId);
            await NfcManager.instance.stopSession();
          } catch (e) {
            onError('Erreur lecture tag: $e');
            await NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      onError('Erreur NFC: $e');
    }
  }

  static String _extractTagId(NfcTag tag) {
    final ndef = Ndef.from(tag);
    if (ndef != null && ndef.cachedMessage != null) {
      for (final record in ndef.cachedMessage!.records) {
        if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown) {
          final payload = record.payload;
          if (payload.isNotEmpty) {
            return String.fromCharCodes(payload.skip(1));
          }
        }
      }
    }

    final tagData = tag.data;
    if (tagData.containsKey('nfca')) {
      final identifier = tagData['nfca']['identifier'] as List<dynamic>;
      return identifier
          .map((e) => e.toRadixString(16).padLeft(2, '0'))
          .join(':')
          .toUpperCase();
    }

    return 'TAG-UNKNOWN';
  }

  static Future<void> stopScan() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      // ignore
    }
  }
}