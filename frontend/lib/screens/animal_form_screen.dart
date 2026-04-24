import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import 'dart:convert';

class AnimalFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existingAnimal;
  final VoidCallback? onSaved;

  const AnimalFormScreen({super.key, this.existingAnimal, this.onSaved});

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rfidController = TextEditingController();
  final _breedController = TextEditingController();
  String _species = 'Ovin';
  String _gender = 'Mâle';
  String _status = 'Active';
  bool _isLoading = false;
  bool get isEditing => widget.existingAnimal != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _rfidController.text = widget.existingAnimal!['rfidTag'] ?? '';
      _breedController.text = widget.existingAnimal!['breed'] ?? '';
      _species = widget.existingAnimal!['species'] ?? 'Ovin';
      _gender = widget.existingAnimal!['gender'] ?? 'Mâle';
      _status = widget.existingAnimal!['status'] ?? 'Active';
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final online = await SyncService.isOnline();
      final payload = {
        'rfidTag': _rfidController.text.trim(),
        'breed': _breedController.text.trim(),
        'species': _species,
        'gender': _gender,
        'status': _status,
      };

      if (online) {
        if (isEditing) {
          await ApiService.updateAnimal(
              widget.existingAnimal!['id'], payload);
        } else {
          await ApiService.createAnimal(payload);
        }
      } else {
        await LocalDbService.savePendingAction(
          isEditing ? 'update_animal' : 'create_animal',
          jsonEncode(payload),
        );
      }

      await LocalDbService.addAuditLog(
        isEditing ? 'MODIFIER_ANIMAL' : 'AJOUTER_ANIMAL',
        'Animal ${_rfidController.text}',
        '',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing
              ? '✅ Animal modifié avec succès'
              : '✅ Animal ajouté avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSaved?.call();
      Navigator.pop(context);
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
        title: Text(isEditing ? 'Modifier Animal' : 'Ajouter Animal'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _rfidController,
                enabled: !isEditing,
                decoration: InputDecoration(
                  labelText: 'Tag RFID *',
                  prefixIcon: const Icon(Icons.nfc),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _species,
                decoration: InputDecoration(
                  labelText: 'Espèce',
                  prefixIcon: const Icon(Icons.pets),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Ovin', child: Text('Ovin')),
                  DropdownMenuItem(value: 'Bovin', child: Text('Bovin')),
                  DropdownMenuItem(value: 'Caprin', child: Text('Caprin')),
                ],
                onChanged: (v) => setState(() => _species = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _breedController,
                decoration: InputDecoration(
                  labelText: 'Race *',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: InputDecoration(
                  labelText: 'Sexe',
                  prefixIcon: const Icon(Icons.transgender),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Mâle', child: Text('Mâle')),
                  DropdownMenuItem(
                      value: 'Femelle', child: Text('Femelle')),
                ],
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: 'Statut',
                  prefixIcon: const Icon(Icons.info),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Actif')),
                  DropdownMenuItem(value: 'Sold', child: Text('Vendu')),
                  DropdownMenuItem(
                      value: 'Quarantined', child: Text('En quarantaine')),
                  DropdownMenuItem(value: 'Lost', child: Text('Perdu')),
                ],
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _save,
                icon: Icon(isEditing ? Icons.save : Icons.add),
                label: Text(isEditing ? 'Enregistrer' : 'Ajouter l\'animal'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: const Color(0xFF1B5E20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}