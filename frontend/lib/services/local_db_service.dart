import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'dzcheptel.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table animaux en cache
        await db.execute('''
          CREATE TABLE animals (
            id INTEGER PRIMARY KEY,
            rfidTag TEXT UNIQUE,
            species TEXT,
            breed TEXT,
            gender TEXT,
            status TEXT,
            farmName TEXT,
            farmLocation TEXT,
            synced INTEGER DEFAULT 1
          )
        ''');

        // Table actions offline (à synchroniser)
        await db.execute('''
          CREATE TABLE pending_actions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT,
            payload TEXT,
            createdAt TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');

        // Table audit log local
        await db.execute('''
          CREATE TABLE audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT,
            details TEXT,
            username TEXT,
            timestamp TEXT
          )
        ''');

        // Table notifications
        await db.execute('''
          CREATE TABLE notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            body TEXT,
            isRead INTEGER DEFAULT 0,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  // ─── ANIMALS ───────────────────────────────────
  static Future<void> cacheAnimals(List<dynamic> animals) async {
    final database = await db;
    final batch = database.batch();
    for (final a in animals) {
      batch.insert(
        'animals',
        {
          'id': a['id'],
          'rfidTag': a['rfidTag'],
          'species': a['species'],
          'breed': a['breed'],
          'gender': a['gender'],
          'status': a['status'],
          'farmName': a['farm']?['name'] ?? a['farmName'] ?? '',
          'farmLocation': a['farm']?['location'] ?? a['farmLocation'] ?? '',
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  static Future<List<Map<String, dynamic>>> getCachedAnimals() async {
    final database = await db;
    return database.query('animals');
  }

  static Future<Map<String, dynamic>?> getAnimalByRfid(String rfid) async {
    final database = await db;
    final results = await database.query(
      'animals',
      where: 'rfidTag = ?',
      whereArgs: [rfid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ─── PENDING ACTIONS ───────────────────────────
  static Future<void> savePendingAction(
      String action, String payload) async {
    final database = await db;
    await database.insert('pending_actions', {
      'action': action,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingActions() async {
    final database = await db;
    return database.query('pending_actions', where: 'synced = 0');
  }

  static Future<void> markActionSynced(int id) async {
    final database = await db;
    await database.update(
      'pending_actions',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── AUDIT LOG ─────────────────────────────────
  static Future<void> addAuditLog(
      String action, String details, String username) async {
    final database = await db;
    await database.insert('audit_log', {
      'action': action,
      'details': details,
      'username': username,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getAuditLog() async {
    final database = await db;
    return database.query('audit_log', orderBy: 'timestamp DESC', limit: 50);
  }

  // ─── NOTIFICATIONS ─────────────────────────────
  static Future<void> addNotification(String title, String body) async {
    final database = await db;
    await database.insert('notifications', {
      'title': title,
      'body': body,
      'isRead': 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final database = await db;
    return database.query('notifications',
        orderBy: 'timestamp DESC', limit: 20);
  }

  static Future<int> getUnreadCount() async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM notifications WHERE isRead = 0');
    return result.first['count'] as int;
  }

  static Future<void> markAllRead() async {
    final database = await db;
    await database.update('notifications', {'isRead': 1});
  }
}