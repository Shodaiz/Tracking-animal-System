import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.100.59/api';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── LOGIN ──────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('role', data['role']);
      await prefs.setString('username', data['username']);
      await prefs.setString('fullName', data['fullName'] ?? data['username']);
      if (data['farmId'] != null) {
        await prefs.setInt('farmId', data['farmId']);
        await prefs.setString('farmName', data['farmName'] ?? '');
      }
      return data;
    } else {
      throw Exception('Identifiant ou mot de passe incorrect');
    }
  }

  // ─── INSCRIPTION ────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String role,
    String phone = '',
  }) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'fullName': fullName,
        'email': email,
        'role': role,
        'phone': phone,
      }),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Erreur inscription');
    }
  }

  // ─── MOT DE PASSE OUBLIÉ ────────────────────────
  static Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier}),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Utilisateur non trouvé');
    }
  }

  // ─── RÉINITIALISATION MOT DE PASSE ──────────────
  static Future<void> resetPassword(
      String identifier, String newPassword) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier,
        'newPassword': newPassword,
      }),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Erreur réinitialisation');
    }
  }

  // ─── FARMER ──────────────────────────────────────
  static Future<Map<String, dynamic>> scanAnimal(String rfidTag) async {
    final headers = await getHeaders();
    final response = await http
        .get(
      Uri.parse('$baseUrl/farmer/scan/$rfidTag'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Animal non trouvé');
    }
  }

  static Future<List<dynamic>> getMyAnimals() async {
    final headers = await getHeaders();
    final response = await http
        .get(
      Uri.parse('$baseUrl/farmer/animals'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur chargement animaux');
    }
  }

  static Future<void> createAnimal(Map<String, dynamic> payload) async {
    final headers = await getHeaders();
    final response = await http
        .post(
      Uri.parse('$baseUrl/farmer/animals'),
      headers: headers,
      body: jsonEncode(payload),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur création animal');
    }
  }

  static Future<void> updateAnimal(int id, Map<String, dynamic> payload) async {
    final headers = await getHeaders();
    final response = await http
        .put(
      Uri.parse('$baseUrl/farmer/animals/$id'),
      headers: headers,
      body: jsonEncode(payload),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Erreur modification animal');
    }
  }

  static Future<void> deleteAnimal(int id) async {
    final headers = await getHeaders();
    final response = await http
        .delete(
      Uri.parse('$baseUrl/farmer/animals/$id'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Erreur suppression animal');
    }
  }

  // ─── VET ─────────────────────────────────────────
  static Future<List<dynamic>> getAllFarms() async {
    final headers = await getHeaders();
    final response = await http
        .get(
      Uri.parse('$baseUrl/vet/farms'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur chargement fermes');
    }
  }

  static Future<List<dynamic>> getAnimalsByFarm(int farmId) async {
    final headers = await getHeaders();
    final response = await http
        .get(
      Uri.parse('$baseUrl/vet/farm/$farmId/animals'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur chargement animaux');
    }
  }

  static Future<Map<String, dynamic>> getAnimalHealth(String rfidTag) async {
    final headers = await getHeaders();
    final response = await http
        .get(
      Uri.parse('$baseUrl/vet/scan/$rfidTag'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Animal non trouvé');
    }
  }

  static Future<void> addHealthRecord(
      String rfidTag,
      String recordType,
      String diagnosis,
      String treatment,
      ) async {
    final headers = await getHeaders();
    final response = await http
        .post(
      Uri.parse('$baseUrl/vet/health-record'),
      headers: headers,
      body: jsonEncode({
        'rfidTag': rfidTag,
        'recordType': recordType,
        'diagnosis': diagnosis,
        'treatment': treatment,
      }),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Erreur ajout dossier médical');
    }
  }

  // ─── Inspector ──────────────────────────────────
  static Future<Map<String, dynamic>> verifyScan(
      int farmId, List<String> scannedTags) async {
    final headers = await getHeaders();
    final response = await http
        .post(
      Uri.parse('$baseUrl/inspection/verify-scan'),
      headers: headers,
      body: jsonEncode({
        'farmId': farmId,
        'scannedTags': scannedTags,
      }),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur vérification UHF');
    }
  }

  static Future<Map<String, dynamic>> confirmCheck(int farmId) async {
    final headers = await getHeaders();
    final response = await http
        .post(
      Uri.parse('$baseUrl/Inspection/check'),
      headers: headers,
      body: jsonEncode({'farmId': farmId}),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur confirmation inventaire');
    }
  }

  static Future<Map<String, dynamic>> declareConstat(
      int farmId, String description) async {
    final headers = await getHeaders();
    final response = await http
        .post(
      Uri.parse('$baseUrl/inspection/declare'),
      headers: headers,
      body: jsonEncode({
        'farmId': farmId,
        'description': description,
      }),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur déclaration constat');
    }
  }
}