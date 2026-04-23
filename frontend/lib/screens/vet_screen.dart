import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/app_localizations.dart';
import 'login_screen.dart';
import 'rfid_scanner_screen.dart';

class HomeVet extends StatefulWidget {
  const HomeVet({super.key});

  @override
  State<HomeVet> createState() => _HomeVetState();
}

class _HomeVetState extends State<HomeVet> {
  // Fermes
  List<dynamic> farms = [];
  bool loadingFarms = true;
  int? selectedFarmId;
  String selectedFarmName = '';

  // Animal scanné
  Map<String, dynamic>? animal;
  bool loading = false;

  // Formulaire ajout dossier
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  String _recordType = 'Vaccination';

  // Navigation
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _treatmentController.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── CHARGER LES FERMES ─────────────────────────
  Future<void> _loadFarms() async {
    setState(() => loadingFarms = true);
    try {
      final data = await ApiService.getAllFarms();
      if (mounted) {
        setState(() {
          farms = data;
          loadingFarms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loadingFarms = false);
        _snack('Erreur chargement fermes');
      }
    }
  }

  // ─── OUVRIR LE SCANNER CAMÉRA (RFID/QR) ─────────
  void _openCameraScanner() async {
    if (selectedFarmId == null) {
      _snack('Veuillez sélectionner une ferme d\'abord', color: Colors.orange);
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RfidScannerScreen(
          title: 'Scanner RFID - Vétérinaire',
          subtitle: 'Scannez le tag auriculaire de l\'animal',
          color: Colors.teal[800]!,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      _scanAnimal(result);
    }
  }

  // ─── SCANNER UN ANIMAL PAR TAG ──────────────────
  void _scanAnimal(String rfid) async {
    setState(() => loading = true);
    try {
      final data = await ApiService.getAnimalHealth(rfid);

      // Vérifier que l'animal appartient à la ferme sélectionnée
      if (selectedFarmId != null) {
        final farm = farms.firstWhere(
              (f) => f['id'] == selectedFarmId,
          orElse: () => null,
        );
        if (farm != null && data['farmName'] != farm['name']) {
          throw Exception("Cet animal n'appartient pas à la ferme ${farm['name']}");
        }
      }

      setState(() => animal = data);
      _snack('✅ Fiche chargée : $rfid', color: Colors.green);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
      setState(() => animal = null);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ─── AJOUTER UN DOSSIER MÉDICAL ─────────────────
  void _addRecord() async {
    if (animal == null) {
      _snack('Scannez d\'abord un animal', color: Colors.orange);
      return;
    }

    if (_diagnosisController.text.trim().isEmpty && _treatmentController.text.trim().isEmpty) {
      _snack('Veuillez remplir le diagnostic ou le traitement', color: Colors.orange);
      return;
    }

    try {
      await ApiService.addHealthRecord(
        animal!['rfidTag'],
        _recordType,
        _diagnosisController.text.trim(),
        _treatmentController.text.trim(),
      );

      _diagnosisController.clear();
      _treatmentController.clear();

      _snack('✅ Dossier médical ajouté avec succès', color: Colors.green);

      // Recharger la fiche pour voir le nouveau dossier
      _scanAnimal(animal!['rfidTag']);
    } catch (e) {
      _snack(e.toString());
    }
  }

  // ─── DÉCONNEXION ────────────────────────────────
  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ─── BUILD ──────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: Colors.teal[800],
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DZcheptel',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              selectedFarmName.isNotEmpty ? selectedFarmName : 'Vétérinaire',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildScanPage(),
          _buildAddRecordPage(),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
        onPressed: _openCameraScanner,
        backgroundColor: Colors.teal[800],
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Scanner RFID',
            style: TextStyle(color: Colors.white)),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        selectedItemColor: Colors.teal[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'SCAN',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'SANTÉ',
          ),
        ],
      ),
    );
  }

  // ─── PAGE 1 : SCAN + FICHE TECHNIQUE ────────────
  Widget _buildScanPage() {
    final records = (animal?['healthRecords'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          // ─── Sélection de ferme ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: loadingFarms
                ? const Center(child: LinearProgressIndicator())
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.home, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Sélectionner une ferme',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedFarmId,
                  decoration: InputDecoration(
                    labelText: 'Ferme',
                    prefixIcon: const Icon(Icons.agriculture),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: farms.map<DropdownMenuItem<int>>((f) {
                    return DropdownMenuItem<int>(
                      value: f['id'],
                      child: Text('${f['name']} - ${f['location']}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    final farm = farms.firstWhere(
                          (f) => f['id'] == val,
                      orElse: () => {'name': ''},
                    );
                    setState(() {
                      selectedFarmId = val;
                      selectedFarmName = farm['name'] ?? '';
                      animal = null; // Reset animal quand on change de ferme
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Header Scan ───
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.teal[800]!, Colors.teal[600]!]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.medical_services, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text('Fiche Technique Vétérinaire',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scannez le tag RFID pour consulter la fiche sanitaire complète',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _openCameraScanner,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner,
                            color: Colors.teal[800], size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Scanner via Caméra (RFID/QR)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.teal[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── Loading ───
          if (loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.teal),
            ),

          // ─── Résultat : Fiche Animal ───
          if (animal != null)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header animal
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.teal[200]!),
                          ),
                          child: Text(
                            'TAG #${animal!['rfidTag']}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[800],
                                fontSize: 13),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            animal!['status'] ?? 'Active',
                            style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Infos animal
                    Text(
                      animal!['breed'] ?? 'Animal',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${animal!['species']} • ${animal!['gender']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    Text(
                      '${animal!['farmName']} • ${animal!['farmLocation'] ?? ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const Divider(height: 24),

                    // Historique médical
                    Row(
                      children: [
                        Icon(Icons.history, color: Colors.teal[800], size: 20),
                        const SizedBox(width: 8),
                        const Text('Historique Médical',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${records.length} dossier(s)',
                            style: TextStyle(
                                color: Colors.teal[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (records.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey),
                            SizedBox(width: 8),
                            Text('Aucun dossier médical',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    else
                      ...records.map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal[100]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getRecordIcon(r['recordType']),
                                color: Colors.teal[800],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['recordType'] ?? '',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal[800]),
                                  ),
                                  if (r['diagnosis'] != null &&
                                      r['diagnosis'].toString().isNotEmpty)
                                    Text('Diagnostic: ${r['diagnosis']}',
                                        style: const TextStyle(
                                            fontSize: 13)),
                                  if (r['treatment'] != null &&
                                      r['treatment'].toString().isNotEmpty)
                                    Text('Traitement: ${r['treatment']}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey)),
                                  if (r['visitDate'] != null)
                                    Text('Date: ${r['visitDate']}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),

                    const SizedBox(height: 16),

                    // Bouton ajouter rapide
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _tabIndex = 1),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un dossier médical'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[800],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Placeholder ───
          if (animal == null && !loading)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.medical_services,
                      size: 100, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    selectedFarmId == null
                        ? 'Sélectionnez une ferme puis scannez'
                        : 'Scannez un animal pour voir sa fiche',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── PAGE 2 : AJOUTER DOSSIER MÉDICAL ──────────
  Widget _buildAddRecordPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info animal sélectionné
          if (animal != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.pets, color: Colors.teal[800]),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Animal: ${animal!['rfidTag']}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[800],
                            fontSize: 16),
                      ),
                      Text(
                        '${animal!['species']} / ${animal!['breed']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[800]),
                  const SizedBox(width: 12),
                  const Text('Scannez d\'abord un animal dans l\'onglet SCAN'),
                ],
              ),
            ),

          const Text('Ajouter un Dossier Médical',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Type de dossier
          DropdownButtonFormField<String>(
            value: _recordType,
            decoration: InputDecoration(
              labelText: 'Type de dossier',
              prefixIcon: const Icon(Icons.category),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'Vaccination', child: Text('💉 Vaccination')),
              DropdownMenuItem(value: 'Maladie', child: Text('🦠 Maladie')),
              DropdownMenuItem(value: 'Traitement', child: Text('💊 Traitement')),
              DropdownMenuItem(value: 'Checkup', child: Text('🩺 Checkup')),
              DropdownMenuItem(value: 'Surgery', child: Text('🔪 Chirurgie')),
              DropdownMenuItem(value: 'LabTest', child: Text('🧪 Analyse Labo')),
              DropdownMenuItem(value: 'Injury', child: Text('🩹 Blessure')),
            ],
            onChanged: (v) => setState(() => _recordType = v ?? 'Vaccination'),
          ),
          const SizedBox(height: 16),

          // Diagnostic
          TextField(
            controller: _diagnosisController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Diagnostic',
              hintText: 'Ex: Fièvre Aphteuse, Parasites pulmonaires...',
              prefixIcon: const Icon(Icons.edit_note),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // Traitement
          TextField(
            controller: _treatmentController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Traitement prescrit',
              hintText: 'Ex: Vaccin RVF - Dose 5ml, Ivermectine...',
              prefixIcon: const Icon(Icons.local_pharmacy),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),

          // Bouton ajouter
          ElevatedButton.icon(
            onPressed: _addRecord,
            icon: const Icon(Icons.add_circle),
            label: const Text('AJOUTER LE DOSSIER',
                style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[800],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          // Bouton retour au scan
          OutlinedButton.icon(
            onPressed: () => setState(() => _tabIndex = 0),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Retour au scan'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              foregroundColor: Colors.teal[800],
              side: BorderSide(color: Colors.teal[800]!),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── UTILITAIRE : ICÔNE PAR TYPE DE DOSSIER ─────
  IconData _getRecordIcon(String? type) {
    switch (type) {
      case 'Vaccination':
        return Icons.vaccines;
      case 'Maladie':
        return Icons.coronavirus;
      case 'Traitement':
        return Icons.local_pharmacy;
      case 'Checkup':
        return Icons.health_and_safety;
      case 'Surgery':
        return Icons.local_hospital;
      case 'LabTest':
        return Icons.science;
      case 'Injury':
        return Icons.healing;
      default:
        return Icons.medical_services;
    }
  }
}