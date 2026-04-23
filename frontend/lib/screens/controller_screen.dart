import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'constat_screen.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  final _tagsController = TextEditingController(text: "DZ-0007, DZ-0008");
  Map<String, dynamic>? _verificationResult;
  bool _isLoading = false;
  int _farmId = 1;

  void _verifyScan() async {
    setState(() => _isLoading = true);
    try {
      List<String> tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final result = await ApiService.verifyScan(_farmId, tags);
      setState(() => _verificationResult = result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmCheck() async {
    try {
      final result = await ApiService.confirmCheck(_farmId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Inventaire confirmé avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _goToConstat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConstatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contrôleur - Vérification UHF'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.radar, size: 60, color: Colors.indigo),
                    const Text('Scan à distance (5-6 mètres)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _farmId,
                      decoration: const InputDecoration(labelText: 'Ferme à contrôler'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Ferme El Baraka')),
                        DropdownMenuItem(value: 2, child: Text('Ferme Ouled Djellal')),
                      ],
                      onChanged: (val) => setState(() => _farmId = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tagsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Tags scannés (séparés par virgule)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _verifyScan,
                            icon: const Icon(Icons.search),
                            label: const Text('VÉRIFIER'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _confirmCheck,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('CHECK'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _goToConstat,
                      icon: const Icon(Icons.warning),
                      label: const Text('DÉCLARER UN CONSTAT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_verificationResult != null)
              Card(
                color: _verificationResult!['isConsistent'] == true
                    ? Colors.green[50]
                    : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _verificationResult!['isConsistent'] == true
                            ? '✅ Effectif Conforme'
                            : '⚠️ Écart détecté',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      Text('Scannés : ${_verificationResult!['scannedCount']}'),
                      Text('Enregistrés : ${_verificationResult!['registeredCount']}'),
                      Text('Différence : ${_verificationResult!['difference']}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}