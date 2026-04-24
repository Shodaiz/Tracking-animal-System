import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ConstatScreen extends StatefulWidget {
  const ConstatScreen({super.key});

  @override
  State<ConstatScreen> createState() => _ConstatScreenState();
}

class _ConstatScreenState extends State<ConstatScreen> {
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  int _farmId = 1;

  void _declareConstat() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez décrire le constat')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.declareConstat(_farmId, _descriptionController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Constat déclaré avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      _descriptionController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Déclaration de Constat'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.report_problem, size: 80, color: Colors.orange),
            const Text(
              'Déclaration de Constat',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            DropdownButtonFormField<int>(
              initialValue: _farmId,
              decoration: const InputDecoration(labelText: 'Ferme concernée'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Ferme El Baraka')),
                DropdownMenuItem(value: 2, child: Text('Ferme Ouled Djellal')),
              ],
              onChanged: (val) => setState(() => _farmId = val!),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description du constat',
                hintText: 'Ex: Écart de 2 animaux détecté. TAG DZ-9912 manquant...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _declareConstat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('DÉCLARER LE CONSTAT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}