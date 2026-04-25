import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/translated_widget.dart';
import 'login_screen.dart';
import 'rfid_scanner_screen.dart';

class HomeVet extends StatefulWidget {
  const HomeVet({super.key});

  @override
  State<HomeVet> createState() => _HomeVetState();
}

class _HomeVetState extends State<HomeVet> with TranslatedWidget {
  List<dynamic> farms = [];
  bool loadingFarms = true;
  int? selectedFarmId;
  String selectedFarmName = '';
  Map<String, dynamic>? animal;
  bool loading = false;
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  String _recordType = 'Vaccination';
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

  Future<void> _loadFarms() async {
    setState(() => loadingFarms = true);
    try {
      final data = await ApiService.getAllFarms();
      if (mounted) setState(() { farms = data; loadingFarms = false; });
    } catch (e) {
      if (mounted) setState(() => loadingFarms = false);
    }
  }

  void _openCameraScanner() async {
    if (selectedFarmId == null) {
      _snack(tr('select_farm'), color: Colors.orange);
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RfidScannerScreen(
          title: '${tr('scan_rfid')} - ${tr('vet_title')}',
          subtitle: tr('scan_description'),
          color: Colors.teal[800]!,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      _scanAnimal(result);
    }
  }

  void _scanAnimal(String rfid) async {
    setState(() => loading = true);
    try {
      final data = await ApiService.getAnimalHealth(rfid);

      if (selectedFarmId != null) {
        final farm = farms.firstWhere(
                (f) => f['id'] == selectedFarmId, orElse: () => null);
        if (farm != null && data['farmName'] != farm['name']) {
          throw Exception(
              "Cet animal n'appartient pas à la ferme ${farm['name']}");
        }
      }

      setState(() => animal = data);
      _snack('✅ $rfid', color: Colors.green);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
      setState(() => animal = null);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _addRecord() async {
    if (animal == null) {
      _snack(tr('scan_first'), color: Colors.orange);
      return;
    }
    if (_diagnosisController.text.trim().isEmpty &&
        _treatmentController.text.trim().isEmpty) {
      _snack(tr('field_required'), color: Colors.orange);
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
      _snack(tr('record_added'), color: Colors.green);
      _scanAnimal(animal!['rfidTag']);
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final records = (animal?['healthRecords'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: Colors.teal[800],
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DZcheptel',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text(
              selectedFarmName.isNotEmpty ? selectedFarmName : tr('vet_title'),
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
          _buildScanPage(records),
          _buildAddRecordPage(),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
        onPressed: _openCameraScanner,
        backgroundColor: Colors.teal[800],
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: Text(tr('scan_rfid'),
            style: const TextStyle(color: Colors.white)),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        selectedItemColor: Colors.teal[800],
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.qr_code_scanner), label: tr('scan_btn')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.medical_services),
              label: tr('new_care_btn')),
        ],
      ),
    );
  }

  Widget _buildScanPage(List records) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          // Sélection de ferme
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: loadingFarms
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<int>(
              initialValue: selectedFarmId,
              decoration: InputDecoration(
                labelText: tr('select_farm'),
                prefixIcon: const Icon(Icons.home),
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
                        (f) => f['id'] == val, orElse: () => {'name': ''});
                setState(() {
                  selectedFarmId = val;
                  selectedFarmName = farm['name'] ?? '';
                  animal = null;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Header Scan
          Container(
            decoration: BoxDecoration(
              gradient:
              LinearGradient(colors: [Colors.teal[800]!, Colors.teal[600]!]),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('health_sheet'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _openCameraScanner,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner, color: Colors.teal[800]),
                        const SizedBox(width: 8),
                        Text(
                          tr('scan_chip'),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.teal[800]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (loading) const CircularProgressIndicator(),

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
                    Text(animal!['breed'] ?? '',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(
                      '${animal!['species']} • ${animal!['gender']}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const Divider(height: 24),
                    Text(tr('medical_history'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    records.isEmpty
                        ? Text(tr('no_records'),
                        style: const TextStyle(color: Colors.grey))
                        : Column(
                      children: records
                          .map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.teal[100]!),
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal[100],
                                borderRadius:
                                BorderRadius.circular(10),
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
                                  Text(r['recordType'] ?? '',
                                      style: TextStyle(
                                          fontWeight:
                                          FontWeight.bold,
                                          color:
                                          Colors.teal[800])),
                                  if (r['diagnosis'] != null &&
                                      r['diagnosis']
                                          .toString()
                                          .isNotEmpty)
                                    Text(
                                        '${tr('diagnosis_label')}: ${r['diagnosis']}',
                                        style: const TextStyle(
                                            fontSize: 13)),
                                  if (r['treatment'] != null &&
                                      r['treatment']
                                          .toString()
                                          .isNotEmpty)
                                    Text(
                                        '${tr('treatment_label')}: ${r['treatment']}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey)),
                                  if (r['visitDate'] != null)
                                    Text(r['visitDate'],
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _tabIndex = 1),
                      icon: const Icon(Icons.add),
                      label: Text(tr('add_record')),
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

          if (animal == null && !loading)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.medical_services, size: 100, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    selectedFarmId == null
                        ? tr('select_farm')
                        : tr('scan_first'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddRecordPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      Text('Animal: ${animal!['rfidTag']}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[800],
                              fontSize: 16)),
                      Text('${animal!['species']} / ${animal!['breed']}',
                          style: const TextStyle(color: Colors.grey)),
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
                  Expanded(child: Text(tr('scan_first'))),
                ],
              ),
            ),
          Text(tr('add_record'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _recordType,
            decoration: InputDecoration(
              labelText: tr('record_type'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              DropdownMenuItem(value: 'Vaccination', child: Text('💉 ${tr('vaccination_type')}')),
              DropdownMenuItem(value: 'Maladie', child: Text('🦠 ${tr('disease_type')}')),
              DropdownMenuItem(value: 'Traitement', child: Text('💊 ${tr('treatment_type')}')),
              DropdownMenuItem(value: 'Checkup', child: Text('🩺 ${tr('checkup_type')}')),
              DropdownMenuItem(value: 'Surgery', child: Text('🔪 ${tr('surgery_type')}')),
              DropdownMenuItem(value: 'LabTest', child: Text('🧪 ${tr('lab_test_type')}')),
              DropdownMenuItem(value: 'Injury', child: Text('🩹 ${tr('injury_type')}')),
            ],
            onChanged: (v) => setState(() => _recordType = v ?? 'Vaccination'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _diagnosisController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: tr('diagnosis_label'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _treatmentController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: tr('treatment_label'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addRecord,
            icon: const Icon(Icons.add_circle),
            label: Text(tr('add_record_btn'), style: const TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[800],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _tabIndex = 0),
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(tr('back_to_scan')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              foregroundColor: Colors.teal[800],
              side: BorderSide(color: Colors.teal[800]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRecordIcon(String? type) {
    switch (type) {
      case 'Vaccination': return Icons.vaccines;
      case 'Maladie': return Icons.coronavirus;
      case 'Traitement': return Icons.local_pharmacy;
      case 'Checkup': return Icons.health_and_safety;
      case 'Surgery': return Icons.local_hospital;
      case 'LabTest': return Icons.science;
      case 'Injury': return Icons.healing;
      default: return Icons.medical_services;
    }
  }
}